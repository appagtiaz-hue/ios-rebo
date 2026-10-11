import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContentCache {
  static final changes = ValueNotifier<int>(0);
  @visibleForTesting
  static http.Client client = http.Client();
  @visibleForTesting
  static Directory? directoryForTesting;
  static final _pending = <String, Future<http.Response>>{};
  static final _versionChecks = <String, Future<bool>>{};
  static final _lastCheck = <String, DateTime>{};
  static final _supportsVersions = <String, bool>{};
  static Future<void> _versionUpdate = Future.value();
  static final _generations = <String, int>{};
  static int _privateGeneration = 0;

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  static String _origin(Uri uri) => '${uri.scheme}://${uri.authority}';

  static String _scope(Map<String, String>? headers) {
    final authorization = headers?['Authorization'];
    if (authorization == null) return 'public';
    try {
      final token = authorization.split(' ').last.split('.');
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token[1]))),
      );
      return 'user_${payload['id'] ?? payload['sub']}';
    } catch (_) {
      return 'authenticated_${_hash(authorization)}';
    }
  }

  static Future<Directory> _directory(Uri uri) async {
    final root = directoryForTesting ?? await getApplicationSupportDirectory();
    final directory = Directory(
      '${root.path}/content_cache/${_hash(_origin(uri))}',
    );
    await directory.create(recursive: true);
    return directory;
  }

  static Future<Map<String, dynamic>?> _read(File file) async {
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static http.Response _response(Map<String, dynamic> stored) => http.Response(
    stored['body'] as String,
    200,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      if (stored['version'] != null)
        'x-content-version': stored['version'] as String,
      if (stored['etag'] != null) 'etag': stored['etag'] as String,
    },
  );

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    bool cacheFirst = false,
    bool userData = false,
    bool forceFresh = false,
  }) async {
    final directory = await _directory(uri);
    final file = File(
      '${directory.path}/${_hash('${_scope(headers)}:${uri.toString()}')}.json',
    );
    final cached = await _read(file);
    if (cached != null && cacheFirst && !forceFresh) {
      final age =
          DateTime.now().millisecondsSinceEpoch -
          (cached['savedAt'] as int? ?? 0);
      if (userData || _supportsVersions[_origin(uri)] != true) {
        if (age >= 60000) {
          unawaited(
            _fetch(
              uri,
              headers,
              file,
              cached,
              userData,
            ).catchError((_) => _response(cached)),
          );
        }
      }
      if (!userData) unawaited(checkForChanges(uri));
      return _response(cached);
    }
    return _fetch(uri, headers, file, cached, userData);
  }

  static Future<http.Response> _fetch(
    Uri uri,
    Map<String, String>? headers,
    File file,
    Map<String, dynamic>? cached,
    bool userData,
  ) {
    final generation = _generations[_origin(uri)] ?? 0;
    final private = _scope(headers) != 'public';
    final privateGeneration = _privateGeneration;
    final pendingKey =
        '${file.path}:$generation:${private ? privateGeneration : 0}';
    return _pending.putIfAbsent(pendingKey, () async {
      try {
        final response = await client
            .get(
              uri,
              headers: {
                ...?headers,
                if (cached?['etag'] != null)
                  'If-None-Match': cached!['etag'] as String,
              },
            )
            .timeout(const Duration(seconds: 30));
        final version = response.headers['x-content-version'];
        final versionChanged =
            version != null && await _adoptVersion(uri, version);
        final prefs = await SharedPreferences.getInstance();
        final currentVersion = prefs.getString(
          'content_version_${_hash(_origin(uri))}',
        );
        final stale = version != null
            ? currentVersion != version
            : generation != (_generations[_origin(uri)] ?? 0);
        if (stale || (private && privateGeneration != _privateGeneration))
          return response;
        if (response.statusCode == 304 && cached != null) {
          cached['savedAt'] = DateTime.now().millisecondsSinceEpoch;
          await file.parent.create(recursive: true);
          await file.writeAsString(jsonEncode(cached));
          return _response(cached);
        }
        if ([401, 403, 404, 410].contains(response.statusCode)) {
          if (await file.exists()) await file.delete();
          return response;
        }
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body is Map && body['success'] == true) {
            await file.parent.create(recursive: true);
            await file.writeAsString(
              jsonEncode({
                'body': response.body,
                'etag': response.headers['etag'],
                'version': version,
                'savedAt': DateTime.now().millisecondsSinceEpoch,
                'userData': userData,
                'private': _scope(headers) != 'public',
              }),
            );
            if (!versionChanged &&
                cached != null &&
                cached['body'] != response.body)
              changes.value++;
          }
        }
        return response;
      } finally {
        _pending.remove(pendingKey);
      }
    });
  }

  static Future<bool> checkForChanges(Uri uri, {bool force = false}) {
    final origin = _origin(uri);
    final pending = _versionChecks[origin];
    if (pending != null) return pending;
    final now = DateTime.now();
    final lastCheck = _lastCheck[origin];
    if (!force &&
        lastCheck != null &&
        now.difference(lastCheck) < const Duration(minutes: 1)) {
      return Future.value(false);
    }
    _lastCheck[origin] = now;
    return _versionChecks.putIfAbsent(origin, () async {
      try {
        final response = await client
            .get(Uri.parse('$origin/api/content-version'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 404) {
          _supportsVersions[origin] = false;
          return false;
        }
        if (response.statusCode != 200) return false;
        final body = jsonDecode(response.body);
        if (body['success'] != true || body['version'] is! num) return false;
        _supportsVersions[origin] = true;
        return await _adoptVersion(uri, body['version'].toString());
      } catch (_) {
        return false;
      } finally {
        _versionChecks.remove(origin);
      }
    });
  }

  static Future<bool> _adoptVersion(Uri uri, String version) {
    final result = Completer<bool>();
    _versionUpdate = _versionUpdate.then((_) async {
      try {
        result.complete(await _setVersion(uri, version));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  static Future<bool> _setVersion(Uri uri, String version) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'content_version_${_hash(_origin(uri))}';
    final previous = prefs.getString(key);
    if (previous == version) return false;
    // Never let a slower response from an older revision restore stale data.
    if (previous != null &&
        int.tryParse(version) != null &&
        int.tryParse(previous) != null &&
        int.parse(version) < int.parse(previous))
      return false;
    final directory = await _directory(uri);
    var hadCache = false;
    await for (final file in directory.list()) {
      if (file is File) {
        hadCache = true;
        if (await file.exists()) await file.delete();
      }
    }
    for (final key in prefs.getKeys().toList()) {
      if (key == 'payment_plans' ||
          key.startsWith('plan_questions_') ||
          key.startsWith('fixed_plan_question_ids_') ||
          key == ' _planQuestionsKeyPrefix {userId}_ planId' ||
          key.startsWith('offline_plan_content_'))
        await prefs.remove(key);
    }
    await prefs.setString(key, version);
    _generations[_origin(uri)] = (_generations[_origin(uri)] ?? 0) + 1;
    if (previous != null || hadCache) changes.value++;
    return previous != null || hadCache;
  }

  static Future<void> clearPrivate(Uri uri) async {
    _privateGeneration++;
    final directory = await _directory(uri);
    await for (final file in directory.list()) {
      if (file is! File) continue;
      final cached = await _read(file);
      if (cached?['private'] == true && await file.exists())
        await file.delete();
    }
  }

  static Future<void> invalidateUserData(Uri uri) async {
    final directory = await _directory(uri);
    await for (final file in directory.list()) {
      if (file is! File) continue;
      final cached = await _read(file);
      if (cached?['userData'] == true) await file.delete();
    }
  }
}
