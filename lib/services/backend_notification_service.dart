import 'dart:convert';
import 'package:http/http.dart' as http;

/// Backend notification service - most secure approach
class BackendNotificationService {
  
  // Your backend server URL
  static const String _backendUrl = 'https://your-backend-server.com/api';
  
  /// Send notification via your secure backend
  static Future<bool> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/notifications/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_APP_TOKEN', // Your app's auth token
        },
        body: json.encode({
          'fcm_token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data ?? {},
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ Notification sent via secure backend');
        return true;
      } else {
        print('❌ Backend notification failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Backend notification error: $e');
      return false;
    }
  }
  
  /// Register FCM token with backend
  static Future<bool> registerToken(String fcmToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/tokens/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_APP_TOKEN',
        },
        body: json.encode({
          'fcm_token': fcmToken,
          'device_info': {
            'platform': 'android',
            'app_version': '1.0.0',
          },
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Token registration failed: $e');
      return false;
    }
  }
}
