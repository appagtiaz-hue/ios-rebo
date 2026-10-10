Future<String?> getApplePushToken({
  required Future<bool> Function() hasPermission,
  required Future<String?> Function() getAPNSToken,
  required Future<String?> Function() getFCMToken,
  Future<void> Function(Duration)? delay,
  int attempts = 10,
}) async {
  if (!await hasPermission()) return null;
  final wait = delay ?? Future<void>.delayed;
  // FCM on iOS cannot register until APNs has registered the device.
  for (var attempt = 0; attempt < attempts; attempt++) {
    final token = await getAPNSToken();
    if (token != null && token.isNotEmpty) return getFCMToken();
    if (attempt + 1 < attempts) {
      await wait(const Duration(milliseconds: 500));
    }
  }
  return null;
}
