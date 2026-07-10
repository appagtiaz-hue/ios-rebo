import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_queue_item.dart';
import 'network_service.dart';
import 'auth_service.dart';

/// Service for managing offline sync queue
class SyncQueueService {
  static const String _queueKey = 'sync_queue';
  static const int maxRetries = 5;
  static const int baseBackoffMs = 1000; // 1 second

  // In-memory cache for better performance
  static List<SyncQueueItem> _queueCache = [];
  static bool _isSyncing = false;
  static final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  /// Stream of pending operations count
  static Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Get current pending count
  static int get pendingCount => _queueCache.length;

  /// Initialize the service
  static Future<void> initialize() async {
    print('🔄 SyncQueueService: Initializing...');
    await _loadQueue();
    print(
      '✅ SyncQueueService: Initialized with ${_queueCache.length} pending items',
    );
  }

  /// Load queue from persistent storage
  static Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);

      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _queueCache = decoded
            .map((item) => SyncQueueItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _notifyPendingCount();
      }
    } catch (e) {
      print('❌ Error loading sync queue: $e');
      _queueCache = [];
    }
  }

  /// Save queue to persistent storage
  static Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(
        _queueCache.map((item) => item.toJson()).toList(),
      );
      await prefs.setString(_queueKey, queueJson);
      _notifyPendingCount();
    } catch (e) {
      print('❌ Error saving sync queue: $e');
    }
  }

  /// Notify listeners about pending count change
  static void _notifyPendingCount() {
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(_queueCache.length);
    }
  }

  /// Add an operation to the queue
  static Future<void> addToQueue({
    required SyncOperation operation,
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${operation.toString()}';

    final item = SyncQueueItem(
      id: id,
      operation: operation,
      endpoint: endpoint,
      payload: payload,
      createdAt: DateTime.now(),
    );

    print('📝 Adding to sync queue: ${item.operation} → ${item.endpoint}');
    _queueCache.add(item);
    await _saveQueue();

    // Try to sync immediately if online
    final isOnline = await NetworkService.isConnected();
    if (isOnline && !_isSyncing) {
      processPendingSync();
    }
  }

  /// Process all pending sync operations
  static Future<void> processPendingSync() async {
    if (_isSyncing) {
      print('⚠️ Sync already in progress, skipping...');
      return;
    }

    if (_queueCache.isEmpty) {
      print('✅ Sync queue is empty');
      return;
    }

    // Check connectivity
    final isOnline = await NetworkService.isConnected();
    if (!isOnline) {
      print('⚠️ Device is offline, sync postponed');
      return;
    }

    _isSyncing = true;
    print('🔄 Starting sync process for ${_queueCache.length} items...');

    final itemsToProcess = List<SyncQueueItem>.from(_queueCache);
    final itemsToRemove = <SyncQueueItem>[];

    for (final item in itemsToProcess) {
      try {
        final success = await _syncItem(item);

        if (success) {
          itemsToRemove.add(item);
          print('✅ Synced: ${item.operation} → ${item.endpoint}');
        } else {
          // Update retry count
          final index = _queueCache.indexWhere((i) => i.id == item.id);
          if (index != -1) {
            _queueCache[index] = item.copyWith(
              retryCount: item.retryCount + 1,
              lastAttemptAt: DateTime.now(),
            );

            // Remove if max retries reached
            if (item.retryCount >= maxRetries) {
              print(
                '❌ Max retries reached for ${item.endpoint}, removing from queue',
              );
              itemsToRemove.add(item);
            }
          }
        }
      } catch (e) {
        print('❌ Error syncing item ${item.id}: $e');

        // Update error
        final index = _queueCache.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          _queueCache[index] = item.copyWith(
            retryCount: item.retryCount + 1,
            lastAttemptAt: DateTime.now(),
            lastError: e.toString(),
          );
        }
      }

      // Small delay between items to avoid overwhelming server
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Remove successfully synced items
    for (final item in itemsToRemove) {
      _queueCache.removeWhere((i) => i.id == item.id);
    }

    await _saveQueue();
    _isSyncing = false;

    print(
      '✅ Sync process completed. ${itemsToRemove.length} synced, ${_queueCache.length} remaining',
    );
  }

  /// Sync a single item
  static Future<bool> _syncItem(SyncQueueItem item) async {
    try {
      // Apply exponential backoff
      if (item.retryCount > 0) {
        final backoffMs =
            baseBackoffMs * (1 << item.retryCount); // 2^retryCount
        await Future.delayed(Duration(milliseconds: backoffMs));
      }

      http.Response response;
      final headers = await AuthService.authHeaders();

      switch (item.operation) {
        case SyncOperation.create:
          response = await http.post(
            Uri.parse(item.endpoint),
            headers: headers,
            body: jsonEncode(item.payload),
          );
          break;

        case SyncOperation.update:
          response = await http.put(
            Uri.parse(item.endpoint),
            headers: headers,
            body: jsonEncode(item.payload),
          );
          break;

        case SyncOperation.delete:
          response = await http.delete(
            Uri.parse(item.endpoint),
            headers: headers,
          );
          break;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        print('⚠️ Sync failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Sync error for ${item.endpoint}: $e');
      return false;
    }
  }

  /// Get all pending items (for debugging/UI)
  static List<SyncQueueItem> getPendingItems() {
    return List.unmodifiable(_queueCache);
  }

  /// Clear all pending items (use with caution!)
  static Future<void> clearQueue() async {
    print('🗑️ Clearing sync queue');
    _queueCache.clear();
    await _saveQueue();
  }

  /// Dispose the service
  static void dispose() {
    _pendingCountController.close();
  }
}
