import 'package:flutter/material.dart';
import '../services/sync_queue_service.dart';

/// Widget to show sync status in AppBar
class SyncIndicatorWidget extends StatelessWidget {
  const SyncIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: SyncQueueService.pendingCountStream,
      initialData: SyncQueueService.pendingCount,
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;

        if (pendingCount == 0) {
          // All synced - show green checkmark
          return Tooltip(
            message: 'تم المزامنة',
            child: Icon(Icons.cloud_done, color: Colors.green, size: 20),
          );
        }

        // Has pending items - show warning with count
        return InkWell(
          onTap: () => _showSyncDetails(context, pendingCount),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_upload, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$pendingCount',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSyncDetails(BuildContext context, int pendingCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sync, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('حالة المزامنة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'لديك $pendingCount عملية في انتظار المزامنة',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'سيتم مزامنة البيانات تلقائياً عند اتصالك بالإنترنت',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              // Try to sync
              await SyncQueueService.processPendingSync();

              // Close loading
              Navigator.pop(context);

              // Show result
              final remaining = SyncQueueService.pendingCount;
              if (remaining == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت المزامنة بنجاح! ✅'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تمت مزامنة بعض البيانات. $remaining متبقي'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            icon: const Icon(Icons.sync),
            label: const Text('محاولة المزامنة الآن'),
          ),
        ],
      ),
    );
  }
}
