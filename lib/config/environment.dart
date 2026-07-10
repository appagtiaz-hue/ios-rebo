/// Environment Configuration for different deployment environments
/// This file manages API endpoints and configuration for Development, Staging, and Production

enum Environment { development, staging, production }

class EnvironmentConfig {
  static Environment _currentEnvironment = Environment.production;

  // ⚠️ IMPORTANT: Change this to your computer's IP address on the local network
  // Run 'ipconfig' (Windows) or 'ifconfig' (Mac/Linux) to find your IP
  // Example: '192.168.1.100'
  static const String _localServerIP =
      '192.168.1.4'; // Updated to match current system IP (from ipconfig)

  // AWS EC2 Production Server IP
  static const String _productionServerIP = 'agtiaz.online';

  /// Get current environment
  static Environment get currentEnvironment => _currentEnvironment;

  /// Set environment (call this in main.dart before runApp)
  static void setEnvironment(Environment env) {
    _currentEnvironment = env;
  }

  /// Get API Base URL based on current environment
  static String get baseUrl {
    switch (_currentEnvironment) {
      case Environment.development:
        // Use local IP which works for both emulator and physical devices
        return 'http://$_localServerIP:5000';
        
      case Environment.staging:
        // Replace with your staging server URL
        return 'https://staging-api.yourdomain.com';

      case Environment.production:
        // AWS EC2 Server
        return 'https://$_productionServerIP';
    }
  }

  /// Check if running in production
  static bool get isProduction => _currentEnvironment == Environment.production;

  /// Check if running in development
  static bool get isDevelopment =>
      _currentEnvironment == Environment.development;

  /// Request timeout in seconds
  static int get requestTimeout {
    return isDevelopment ? 60 : 30;
  }

  /// Enable debug logs
  static bool get enableDebugLogs {
    return !isProduction;
  }

  /// Get environment name as string
  static String get environmentName {
    switch (_currentEnvironment) {
      case Environment.development:
        return 'Development';
      case Environment.staging:
        return 'Staging';
      case Environment.production:
        return 'Production';
    }
  }
}
