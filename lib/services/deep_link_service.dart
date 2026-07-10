// Deep Link Service Disabled
// User opted for manual verification flow.
// This file is kept as a placeholder to avoid file system errors if referenced.

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  Future<void> initialize(dynamic navigatorKey) async {
    // No-op
  }
}
