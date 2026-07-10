/// Enum for sync operation types
enum SyncOperation { create, update, delete }

/// Model for queue items that need to be synced with server
class SyncQueueItem {
  final String id;
  final SyncOperation operation;
  final String endpoint;
  final Map<String, dynamic> payload;
  int retryCount;
  final DateTime createdAt;
  DateTime? lastAttemptAt;
  String? lastError;

  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.endpoint,
    required this.payload,
    this.retryCount = 0,
    required this.createdAt,
    this.lastAttemptAt,
    this.lastError,
  });

  /// Create from JSON
  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      operation: SyncOperation.values.firstWhere(
        (e) => e.toString() == json['operation'],
      ),
      endpoint: json['endpoint'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      retryCount: json['retryCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operation': operation.toString(),
      'endpoint': endpoint,
      'payload': payload,
      'retryCount': retryCount,
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'lastError': lastError,
    };
  }

  /// Copy with modifications
  SyncQueueItem copyWith({
    String? id,
    SyncOperation? operation,
    String? endpoint,
    Map<String, dynamic>? payload,
    int? retryCount,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    String? lastError,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      endpoint: endpoint ?? this.endpoint,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  String toString() {
    return 'SyncQueueItem(id: $id, operation: $operation, endpoint: $endpoint, retryCount: $retryCount)';
  }
}
