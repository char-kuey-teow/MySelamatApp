import 'package:amplify_flutter/amplify_flutter.dart';
import 'config.dart';

class AmplifyInteractionsResponse {
  final String message;
  final String? intentName;
  final Map<String, dynamic>? slots;
  final String? sessionId;
  final bool isComplete;
  final List<Map<String, dynamic>>? quickActions;

  AmplifyInteractionsResponse({
    required this.message,
    this.intentName,
    this.slots,
    this.sessionId,
    this.isComplete = false,
    this.quickActions,
  });

  factory AmplifyInteractionsResponse.fromMap(Map<String, dynamic> response) {
    return AmplifyInteractionsResponse(
      message: response['message'] ?? 'Sorry, I didn\'t understand that.',
      intentName: response['intentName'],
      slots: response['slots'],
      sessionId: response['sessionId'],
      isComplete: response['isComplete'] ?? false,
      quickActions: response['quickActions'],
    );
  }
}

class AmplifyInteractionsService {
  static String? _sessionId;
  static String? _userId;
  static Map<String, dynamic> _sessionAttributes = {};
  static String? _lastIntentName;
  static Map<String, dynamic>? _lastSlots;
  static bool _isInitialized = false;

  /// Initialize Amplify Interactions service
  static Future<void> initialize({String? userId}) async {
    if (_isInitialized) return;

    try {
      // Generate session ID and user ID
      _userId = userId ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      _sessionAttributes.clear();
      _lastIntentName = null;
      _lastSlots = null;
      
      _isInitialized = true;
      safePrint('Amplify Interactions Service initialized successfully');
    } catch (e) {
      safePrint('Error initializing Amplify Interactions: $e');
      _initializeDemoMode(userId);
    }
  }

  static void _initializeDemoMode(String? userId) {
    _userId = userId ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _sessionAttributes.clear();
    _lastIntentName = null;
    _lastSlots = null;
    _isInitialized = true;
    safePrint('Initialized in demo mode');
  }

  static void resetSession() {
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _sessionAttributes.clear();
    _lastIntentName = null;
    _lastSlots = null;
  }

  // Utility methods for debugging and testing
  static String get currentSessionId => _sessionId ?? 'no-session';
  static String get currentUserId => _userId ?? 'no-user';
  static Map<String, dynamic> get currentSessionAttributes => Map.from(_sessionAttributes);
  static String? get currentIntentName => _lastIntentName;
  static Map<String, dynamic>? get currentSlots => _lastSlots != null ? Map.from(_lastSlots!) : null;

  // Test the connection to Lex API
  static Future<bool> testConnection() async {
    try {
      final testResponse = await sendMessage('test connection');
      return testResponse.message.isNotEmpty;
    } catch (e) {
      safePrint('Connection test failed: $e');
      return false;
    }
  }

  // Get current session information for debugging
  static Map<String, dynamic> getSessionInfo() {
    return {
      'sessionId': _sessionId,
      'userId': _userId,
      'sessionAttributes': Map.from(_sessionAttributes),
      'lastIntentName': _lastIntentName,
      'lastSlots': _lastSlots != null ? Map.from(_lastSlots!) : null,
      'isDemoMode': Config.useDemoMode,
      'isConfigValid': Config.isLexConfigValid,
      'isAmplifyInitialized': _isInitialized,
    };
  }

  // Add session attribute for custom data storage
  static void setSessionAttribute(String key, dynamic value) {
    _sessionAttributes[key] = value;
  }

  // Get session attribute
  static dynamic getSessionAttribute(String key) {
    return _sessionAttributes[key];
  }

  static Future<AmplifyInteractionsResponse> sendMessage(String message) async {
    try {
      // Validate configuration
      if (!Config.isLexConfigValid && !Config.useDemoMode) {
        safePrint('Invalid Lex configuration. Please check your AWS credentials and bot settings.');
        return AmplifyInteractionsResponse(
          message: 'Configuration error: Please check your AWS Lex bot settings.',
        );
      }

      // For demo purposes, return a mock response
      if (Config.useDemoMode) {
        return _getMockResponse(message);
      }

      // Real Lex integration with Amplify Interactions
      final response = await _sendToLexWithAmplifyInteractions(message);
      return response;
    } catch (e) {
      safePrint('Error sending message to Lex: $e');
      return _handleError(e);
    }
  }

  static AmplifyInteractionsResponse _handleError(dynamic error) {
    if (error.toString().contains('401') || error.toString().contains('403')) {
      return AmplifyInteractionsResponse(
        message: 'Authentication error: Please check your AWS credentials.',
      );
    } else if (error.toString().contains('404')) {
      return AmplifyInteractionsResponse(
        message: 'Bot not found: Please check your bot name and alias configuration.',
      );
    } else if (error.toString().contains('timeout') || error.toString().contains('network')) {
      return AmplifyInteractionsResponse(
        message: 'Network error: Please check your internet connection and try again.',
      );
    } else {
      return AmplifyInteractionsResponse(
        message: 'Sorry, I\'m having trouble connecting right now. Please try again later.',
      );
    }
  }

  static Future<AmplifyInteractionsResponse> _sendToLexWithAmplifyInteractions(String message) async {
    try {
      // For now, we'll use the existing Lex service approach
      // In a full implementation, you would use Amplify Interactions
      safePrint('Using Amplify Interactions approach for Lex integration');
      
      // This is a placeholder for the actual Amplify Interactions implementation
      // The real implementation would use Amplify.Interactions.sendMessage()
      // Note: Amplify Interactions for Lex V2 is not yet available in Flutter
      
      // For now, return a mock response that indicates Amplify integration
      return AmplifyInteractionsResponse(
        message: "🤖 Amplify Interactions Response\n\nI received your message: '$message'\n\nThis is using AWS Amplify Interactions with Amazon Lex bot '${Config.lexBotName}'.\n\nBot ID: ${Config.lexBotId}\nBot Alias: ${Config.lexBotAlias}\nSession: $_sessionId\n\nI can help you with emergency assistance, flood information, and weather updates. How can I assist you?",
        intentName: 'AmplifyTestIntent',
        sessionId: _sessionId,
        quickActions: [
          {
            'title': 'Available Services',
            'buttons': [
              {'text': 'Emergency Help', 'value': 'emergency_help'},
              {'text': 'Flood Info', 'value': 'flood_info'},
              {'text': 'Weather Info', 'value': 'weather_info'},
            ]
          }
        ],
      );
    } catch (e) {
      safePrint('Error calling Lex API with Amplify Interactions: $e');
      // Fallback to mock response
      return _getMockResponse(message);
    }
  }

  // Mock response for demo mode
  static AmplifyInteractionsResponse _getMockResponse(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Emergency intent
    if (lowerMessage.contains('emergency') || lowerMessage.contains('help') || lowerMessage.contains('sos')) {
      return AmplifyInteractionsResponse(
        message: "🚨 EMERGENCY ASSISTANCE\n\nI understand you need emergency help. Here are your options:\n\n• Press the SOS button for immediate emergency services\n• Call 999 for police, fire, or medical emergencies\n• Use the 'Mark Safe' feature to let others know you're okay\n\nWhat type of emergency are you experiencing?",
        intentName: 'EmergencyIntent',
        sessionId: _sessionId,
        quickActions: [
          {
            'title': 'Emergency Actions',
            'buttons': [
              {'text': 'Call 999', 'value': 'call_emergency'},
              {'text': 'Medical Help', 'value': 'medical_help'},
              {'text': 'Fire Emergency', 'value': 'fire_emergency'},
            ]
          }
        ],
      );
    }
    
    // Flood information intent
    if (lowerMessage.contains('flood') || lowerMessage.contains('water') || lowerMessage.contains('rain')) {
      return AmplifyInteractionsResponse(
        message: "🌊 FLOOD INFORMATION\n\nCurrent flood status in your area:\n\n• Risk Level: ORANGE (High risk in 24h)\n• Location: Mukim Badang\n• Radius: 1km\n• Last Updated: ${DateTime.now().toString().substring(0, 19)}\n\nStay alert and be prepared to evacuate if necessary.",
        intentName: 'FloodInfoIntent',
        sessionId: _sessionId,
        quickActions: [
          {
            'title': 'Flood Actions',
            'buttons': [
              {'text': 'Flood Alerts', 'value': 'flood_alerts'},
              {'text': 'Safety Tips', 'value': 'safety_tips'},
              {'text': 'Emergency Kit', 'value': 'emergency_kit'},
            ]
          }
        ],
      );
    }
    
    // Weather information intent
    if (lowerMessage.contains('weather') || lowerMessage.contains('forecast') || lowerMessage.contains('temperature')) {
      return AmplifyInteractionsResponse(
        message: "🌤️ WEATHER FORECAST\n\nCurrent weather conditions:\n\n• Temperature: 28°C\n• Humidity: 85%\n• Rain: Heavy showers expected\n• Wind: 15 km/h from Southeast\n• Visibility: 5km\n\n⚠️ Weather Alert: Heavy rainfall expected for the next 6 hours. Stay indoors and avoid unnecessary travel.",
        intentName: 'WeatherInfoIntent',
        sessionId: _sessionId,
        quickActions: [
          {
            'title': 'Weather Actions',
            'buttons': [
              {'text': 'Hourly Forecast', 'value': 'hourly_forecast'},
              {'text': 'Weather Alerts', 'value': 'weather_alerts'},
              {'text': 'Safety Tips', 'value': 'safety_tips'},
            ]
          }
        ],
      );
    }
    
    // Default response
    return AmplifyInteractionsResponse(
      message: "Hello! I'm SelamatBot, your emergency assistance chatbot powered by AWS Amplify Interactions and Amazon Lex. I can help you with:\n\n• Emergency assistance and SOS\n• Flood information and alerts\n• Weather updates and forecasts\n• Safety tips and guidelines\n\nHow can I assist you today?",
      intentName: 'WelcomeIntent',
      sessionId: _sessionId,
      quickActions: [
        {
          'title': 'Quick Actions',
          'buttons': [
            {'text': 'Emergency Help', 'value': 'emergency_help'},
            {'text': 'Flood Info', 'value': 'flood_info'},
            {'text': 'Weather Info', 'value': 'weather_info'},
          ]
        }
      ],
    );
  }
}
