import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle push notifications via FCM and Amazon SNS
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _channel = MethodChannel('selamat_app/notifications');
  static const String _fcmTokenKey = 'fcm_token';
  static const String _snsEndpointArnKey = 'sns_endpoint_arn';
  
  FirebaseMessaging? _messaging;
  String? _fcmToken;
  String? _snsEndpointArn;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  
  // Callbacks for handling notifications
  Function(RemoteMessage)? onMessageReceived;
  Function(RemoteMessage)? onMessageOpenedApp;
  Function(String)? onTokenRefresh;

  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      
      // Load saved data
      await _loadSavedData();
      
      // Request permissions
      await _requestPermissions();
      
      // Get FCM token
      await _getFCMToken();
      
      // Set up message handlers
      _setupMessageHandlers();
      
      // Listen for token refresh
      _messaging!.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFCMToken(newToken);
        onTokenRefresh?.call(newToken);
        debugPrint('🔄 FCM Token refreshed: $newToken');
      });
      
      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize NotificationService: $e');
      rethrow;
    }
  }

  /// Load saved FCM token and SNS endpoint ARN
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    _fcmToken = prefs.getString(_fcmTokenKey);
    _snsEndpointArn = prefs.getString(_snsEndpointArnKey);
  }

  /// Save FCM token to local storage
  Future<void> _saveFCMToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);
    _fcmToken = token;
  }

  /// Save SNS endpoint ARN to local storage
  /// This method is used internally and may be called by other services
  Future<void> _saveSnsEndpointArn(String endpointArn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snsEndpointArnKey, endpointArn);
    _snsEndpointArn = endpointArn;
    print('💾 SNS Endpoint ARN saved: $endpointArn');
  }

  /// Public method to save SNS endpoint ARN (wrapper for _saveSnsEndpointArn)
  Future<void> saveSnsEndpointArn(String endpointArn) async {
    await _saveSnsEndpointArn(endpointArn);
  }

  /// Request notification permissions
  Future<NotificationSettings> _requestPermissions() async {
    final settings = await _messaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    debugPrint('🔔 Notification permission status: ${settings.authorizationStatus}');
    return settings;
  }

  /// Get FCM token
  Future<String?> _getFCMToken() async {
    try {
      final token = await _messaging!.getToken();
      if (token != null) {
        await _saveFCMToken(token);
        debugPrint('🎯 FCM Token: $token');
      }
      return token;
    } catch (e) {
      debugPrint('❌ Failed to get FCM token: $e');
      return null;
    }
  }

  /// Set up message handlers for different app states
  void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 Received foreground message: ${message.messageId}');
      onMessageReceived?.call(message);
      _handleForegroundMessage(message);
    });

    // Handle messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 App opened from background message: ${message.messageId}');
      onMessageOpenedApp?.call(message);
      _handleBackgroundMessage(message);
    });

    // Handle messages when app is terminated
    _checkForInitialMessage();
  }

  /// Check for initial message when app is opened from terminated state
  Future<void> _checkForInitialMessage() async {
    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📱 App opened from terminated state: ${initialMessage.messageId}');
      onMessageOpenedApp?.call(initialMessage);
      _handleBackgroundMessage(initialMessage);
    }
  }

  /// Handle foreground messages by showing local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 FOREGROUND MESSAGE HANDLER TRIGGERED');
    debugPrint('📱 Message ID: ${message.messageId}');
    debugPrint('📱 Message Data: ${message.data}');
    debugPrint('📱 Notification Title: ${message.notification?.title}');
    debugPrint('📱 Notification Body: ${message.notification?.body}');
    
    try {
      // Use a more reliable ID generation method
      final notificationId = DateTime.now().millisecondsSinceEpoch;
      debugPrint('🆔 Generated notification ID: $notificationId');
      
      await _channel.invokeMethod('showNotification', {
        'id': notificationId, // Use consistent Long value
        'title': message.notification?.title ?? 'MySelamat Foreground',
        'body': message.notification?.body ?? 'Foreground notification received',
        'payload': jsonEncode(message.data),
      });
      debugPrint('✅ Foreground notification displayed');
    } catch (e) {
      debugPrint('❌ Failed to show foreground notification: $e');
    }
  }

  /// Handle background messages (when app is opened)
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('📱 Handling background message: ${message.data}');
    // You can navigate to specific screens based on message data
    _navigateBasedOnMessage(message.data);
  }

  /// Navigate to specific screens based on message payload
  void _navigateBasedOnMessage(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'sos':
        debugPrint('🚨 Navigating to SOS screen');
        break;
      case 'flood_alert':
        debugPrint('🌊 Navigating to flood alert');
        break;
      case 'shelter':
        debugPrint('🏠 Navigating to shelter info');
        break;
      default:
        debugPrint('📱 Navigating to default screen');
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Get current SNS endpoint ARN
  String? get snsEndpointArn => _snsEndpointArn;


  /// Send test notification via FCM
  Future<bool> sendTestNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('🚀 Attempting to send test notification...');
      debugPrint('📋 Title: $title');
      debugPrint('📝 Body: $body');
      debugPrint('📊 Data: $data');
      
      // Method channel is always available (static const)
      
      final notificationId = DateTime.now().millisecondsSinceEpoch;
      debugPrint('🆔 Notification ID: $notificationId');
      
      await _channel.invokeMethod('showNotification', {
        'id': notificationId, // Long value, handled by Android plugin
        'title': title,
        'body': body,
        'payload': data != null ? jsonEncode(data) : null,
      });
      
      debugPrint('✅ Test notification sent successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to send test notification: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      return false;
    }
  }


  /// Get notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    return await _messaging!.getNotificationSettings();
  }

  /// Update notification settings
  Future<NotificationSettings> updateNotificationSettings({
    bool? alert,
    bool? announcement,
    bool? badge,
    bool? carPlay,
    bool? criticalAlert,
    bool? provisional,
    bool? sound,
  }) async {
    final settings = await _messaging!.requestPermission(
      alert: alert ?? true,
      announcement: announcement ?? false,
      badge: badge ?? true,
      carPlay: carPlay ?? false,
      criticalAlert: criticalAlert ?? false,
      provisional: provisional ?? false,
      sound: sound ?? true,
    );
    
    debugPrint('🔔 Updated notification settings: ${settings.authorizationStatus}');
    return settings;
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      await _channel.invokeMethod('cancelAllNotifications');
      debugPrint('✅ All notifications cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear notifications: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
  }
}

/// Top-level function to handle background messages
/// This must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 BACKGROUND MESSAGE HANDLER TRIGGERED');
  debugPrint('📱 Message ID: ${message.messageId}');
  debugPrint('📱 Message Data: ${message.data}');
  debugPrint('📱 Notification Title: ${message.notification?.title}');
  debugPrint('📱 Notification Body: ${message.notification?.body}');
  debugPrint('📱 From: ${message.from}');
  debugPrint('📱 Collapse Key: ${message.collapseKey}');
  debugPrint('📱 Content Available: ${message.contentAvailable}');
  debugPrint('📱 Message Type: ${message.messageType}');
  debugPrint('📱 Sent Time: ${message.sentTime}');
  debugPrint('📱 TTL: ${message.ttl}');
  
  // Show local notification for background messages
  try {
    final MethodChannel channel = const MethodChannel('selamat_app/notifications');
    final notificationId = DateTime.now().millisecondsSinceEpoch;
    debugPrint('🆔 Generated background notification ID: $notificationId');
    
    await channel.invokeMethod('showNotification', {
      'id': notificationId, // Use consistent Long value
      'title': message.notification?.title ?? 'MySelamat Background',
      'body': message.notification?.body ?? 'Background notification received',
      'payload': jsonEncode(message.data),
    });
    debugPrint('✅ Background notification displayed');
  } catch (e) {
    debugPrint('❌ Failed to show background notification: $e');
  }
}
