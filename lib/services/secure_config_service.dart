import 'package:flutter/foundation.dart';

/// Secure configuration service using environment variables
class SecureConfigService {
  
  /// Load Firebase config from environment variables
  static Map<String, dynamic> loadFirebaseConfig() {
    if (kDebugMode) {
      // In development, you might still use the JSON file
      print('⚠️ Development mode: Using local JSON file (not secure for production)');
      return _loadFromAssets();
    } else {
      // In production, use environment variables
      return _loadFromEnvironment();
    }
  }
  
  /// Load from environment variables (secure)
  static Map<String, dynamic> _loadFromEnvironment() {
    final config = {
      'type': 'service_account',
      'project_id': const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      'private_key_id': const String.fromEnvironment('FIREBASE_PRIVATE_KEY_ID'),
      'private_key': const String.fromEnvironment('FIREBASE_PRIVATE_KEY'),
      'client_email': const String.fromEnvironment('FIREBASE_CLIENT_EMAIL'),
      'client_id': const String.fromEnvironment('FIREBASE_CLIENT_ID'),
      'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
      'token_uri': 'https://oauth2.googleapis.com/token',
    };
    
    // Validate required fields
    if (config['project_id']?.isEmpty ?? true) {
      throw Exception('FIREBASE_PROJECT_ID environment variable not set');
    }
    
    print('✅ Firebase config loaded from environment variables (secure)');
    return config;
  }
  
  /// Load from assets (development only)
  static Map<String, dynamic> _loadFromAssets() {
    // This would use the FirebaseConfigService for development
    // In production, this should never be called
    throw Exception('Assets loading should only be used in development mode');
  }
  
  /// Check if running in secure mode
  static bool get isSecureMode => !kDebugMode;
}
