import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/environment.dart';

/// Service to check network connectivity status
class NetworkService {
  static final Connectivity _connectivity = Connectivity();

  // Base URL for API requests - now uses Environment Config
  static String get baseUrl => EnvironmentConfig.baseUrl;
  static int get requestTimeout => EnvironmentConfig.requestTimeout;

  /// Default headers for API requests
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Bypass-Tunnel-Reminder': 'true',
  };

  /// Check if device is connected to network
  static Future<bool> isConnected() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      // If connectivity check fails, assume offline
      return false;
    }
  }

  /// Stream of connectivity status changes
  static Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }

  /// Check connectivity with timeout
  static Future<bool> isConnectedWithTimeout({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      return await isConnected().timeout(timeout);
    } catch (e) {
      return false;
    }
  }

  /// Get current environment name for debugging
  static String get environmentName => EnvironmentConfig.environmentName;
}
