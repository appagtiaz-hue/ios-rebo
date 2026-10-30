import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_deletion_state.dart';
import 'content_cache.dart';
import 'sync_queue_service.dart';
import 'free_plan_usage_service.dart';

class AccountErasure {
  static Future<void> run({
    Future<List<Directory>> Function()? ownedRoots,
  }) async {
    AccountDeletionState.generation++;
    await SyncQueueService.clearQueue();
    FreePlanUsageService.instance.resetForAccountDeletion();
    final preferences = await SharedPreferences.getInstance();
    final photo = preferences.getString('profile_image_path');
    final roots = ownedRoots != null
        ? await ownedRoots()
        : [
            await getApplicationSupportDirectory(),
            await getApplicationDocumentsDirectory(),
            await getTemporaryDirectory(),
          ];
    if (photo != null) await removeOwnedPhoto(photo, roots);
    await ContentCache.eraseAccountData();
    final keep = <String, Object>{};
    for (final key in [
      'theme_mode',
      'language_code',
      'has_selected_language',
    ]) {
      final value = preferences.get(key);
      if (value != null) keep[key] = value;
    }
    if (!await preferences.clear())
      throw StateError('Local data cleanup incomplete');
    for (final entry in keep.entries) {
      if (entry.value is String)
        await preferences.setString(entry.key, entry.value as String);
      if (entry.value is bool)
        await preferences.setBool(entry.key, entry.value as bool);
    }
    final secure = await AccountDeletionState.storage.readAll();
    for (final key in secure.keys.toList()) {
      if (key != AccountDeletionState.pendingKey)
        await AccountDeletionState.storage.delete(key: key);
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  static Future<void> removeOwnedPhoto(
    String value,
    List<Directory> roots,
  ) async {
    final file = File(value);
    if (!await file.exists()) return;
    final resolved = await file.resolveSymbolicLinks();
    for (final root in roots) {
      if (!await root.exists()) continue;
      final parent = await root.resolveSymbolicLinks();
      final prefix = parent.endsWith(Platform.pathSeparator)
          ? parent
          : '$parent${Platform.pathSeparator}';
      final path = Platform.isWindows ? resolved.toLowerCase() : resolved;
      if (path.startsWith(Platform.isWindows ? prefix.toLowerCase() : prefix)) {
        await file.delete();
        return;
      }
    }
    // Never delete an arbitrary original photo outside this application's storage.
  }
}
