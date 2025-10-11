import 'firebase_config_service.dart';

/// Service to handle Firebase backend operations using JSON config file
class FirebaseBackendService {
  
  /// Send notification using Firebase Admin SDK (via backend)
  static Future<bool> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Load Firebase config from JSON file
      final firebaseConfig = await FirebaseConfigService.loadConfig();
      
      // Prepare notification payload (for demonstration)
      print('📋 Notification payload prepared for FCM token: $fcmToken');
      
      print('🚀 Sending notification via Firebase:');
      print('📱 FCM Token: $fcmToken');
      print('📋 Title: $title');
      print('📝 Body: $body');
      print('🔧 Firebase Project: ${firebaseConfig['project_id']}');
      
      // In a real implementation, you would:
      // 1. Send this to your backend server
      // 2. Your backend would use the Firebase Admin SDK
      // 3. Your backend would authenticate using the service account JSON
      
      // For demo purposes, we'll simulate success
      print('✅ MOCK: Notification sent successfully via Firebase');
      print('💡 In production, this would call your backend server');
      
      return true;
      
    } catch (e) {
      print('❌ Failed to send notification via Firebase: $e');
      return false;
    }
  }
  
  /// Get Firebase project information
  static Future<Map<String, String>> getProjectInfo() async {
    try {
      final config = await FirebaseConfigService.loadConfig();
      return {
        'project_id': config['project_id'] ?? 'Unknown',
        'client_email': config['client_email'] ?? 'Unknown',
        'type': config['type'] ?? 'Unknown',
      };
    } catch (e) {
      print('❌ Failed to get Firebase project info: $e');
      return {
        'project_id': 'Error loading config',
        'client_email': 'Error loading config',
        'type': 'Error loading config',
      };
    }
  }
  
  /// Validate Firebase configuration
  static Future<bool> validateConfig() async {
    try {
      final isValid = await FirebaseConfigService.isConfigValid();
      if (isValid) {
        final projectInfo = await getProjectInfo();
        print('✅ Firebase configuration is valid:');
        print('📋 Project ID: ${projectInfo['project_id']}');
        print('📧 Client Email: ${projectInfo['client_email']}');
        print('🔧 Type: ${projectInfo['type']}');
      } else {
        print('❌ Firebase configuration is invalid');
      }
      return isValid;
    } catch (e) {
      print('❌ Error validating Firebase configuration: $e');
      return false;
    }
  }
}
