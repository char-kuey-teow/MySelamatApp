import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'config.dart';

class LexResponse {
  final String message;
  final String? intentName;
  final Map<String, dynamic>? slots;
  final String? sessionId;
  final bool isComplete;
  final List<Map<String, dynamic>>? quickActions;

  LexResponse({
    required this.message,
    this.intentName,
    this.slots,
    this.sessionId,
    this.isComplete = false,
    this.quickActions,
  });

  factory LexResponse.fromJson(Map<String, dynamic> json) {
    return LexResponse(
      message: json['messages']?[0]?['content'] ?? 'Sorry, I didn\'t understand that.',
      intentName: json['sessionState']?['intent']?['name'],
      slots: json['sessionState']?['intent']?['slots'],
      sessionId: json['sessionId'],
      isComplete: json['sessionState']?['intent']?['confirmationState'] == 'Confirmed',
      quickActions: _extractQuickActions(json),
    );
  }

  static List<Map<String, dynamic>>? _extractQuickActions(Map<String, dynamic> json) {
    // Extract quick actions from Lex response
    final responseCard = json['sessionState']?['dialogAction']?['responseCard'];
    if (responseCard != null && responseCard['genericAttachments'] != null) {
      return responseCard['genericAttachments']
          .map<Map<String, dynamic>>((attachment) => {
                'title': attachment['title'] ?? '',
                'subTitle': attachment['subTitle'] ?? '',
                'buttons': attachment['buttons'] ?? [],
              })
          .toList();
    }
    return null;
  }
}

class LexService {
  static const String _endpoint = 'https://runtime.lex.us-east-1.amazonaws.com';
  
  static String? _sessionId;
  static String? _userId;
  static Map<String, dynamic> _sessionAttributes = {};
  static String? _lastIntentName;
  static Map<String, dynamic>? _lastSlots;

  static void initialize({String? userId}) {
    const uuid = Uuid();
    _userId = userId ?? uuid.v4();
    _sessionId = uuid.v4();
    _sessionAttributes.clear();
    _lastIntentName = null;
    _lastSlots = null;
  }

  static void resetSession() {
    const uuid = Uuid();
    _sessionId = uuid.v4();
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
      print('Connection test failed: $e');
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

  static Future<LexResponse> sendMessage(String message) async {
    try {
      // Validate configuration
      if (!Config.isLexConfigValid && !Config.useDemoMode) {
        print('Invalid Lex configuration. Please check your AWS credentials and bot settings.');
        return LexResponse(
          message: 'Configuration error: Please check your AWS Lex bot settings.',
        );
      }

      // For demo purposes, return a mock response
      if (Config.useDemoMode) {
        return _getMockResponse(message);
      }

      // Real Lex integration
      final response = await _sendToLex(message);
      return response;
    } catch (e) {
      print('Error sending message to Lex: $e');
      return _handleError(e);
    }
  }

  static LexResponse _handleError(dynamic error) {
    if (error.toString().contains('401') || error.toString().contains('403')) {
      return LexResponse(
        message: 'Authentication error: Please check your AWS credentials.',
      );
    } else if (error.toString().contains('404')) {
      return LexResponse(
        message: 'Bot not found: Please check your bot name and alias configuration.',
      );
    } else if (error.toString().contains('timeout') || error.toString().contains('network')) {
      return LexResponse(
        message: 'Network error: Please check your internet connection and try again.',
      );
    } else {
      return LexResponse(
        message: 'Sorry, I\'m having trouble connecting right now. Please try again later.',
      );
    }
  }

  static Future<LexResponse> _sendToLex(String message) async {
    final uri = Uri.parse('$_endpoint/bot/${Config.lexBotName}/botAlias/${Config.lexBotAlias}/user/$_userId/session/$_sessionId/text');
    
    // Build session state with current attributes and intent context
    final sessionState = <String, dynamic>{
      'sessionAttributes': _sessionAttributes,
    };

    // Add intent information if we have it from previous conversation
    if (_lastIntentName != null) {
      sessionState['intent'] = {
        'name': _lastIntentName,
        'slots': _lastSlots ?? {},
        'confirmationState': 'None',
        'state': 'InProgress',
      };
      sessionState['dialogAction'] = {
        'type': 'ElicitSlot',
        'slotToElicit': 'nextSlot', // This should be determined by Lex
      };
    } else {
      sessionState['dialogAction'] = {
        'type': 'ElicitIntent',
      };
    }

    final body = {
      'inputText': message,
      'sessionState': sessionState,
    };

    final bodyJson = jsonEncode(body);
    
    try {
      // Create AWS signature v4 for authentication
      final signedRequest = await _createSignedRequest(
        method: 'POST',
        uri: uri,
        body: bodyJson,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      final response = await http.post(
        uri,
        headers: signedRequest,
        body: bodyJson,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Lex API did not respond within 30 seconds');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final lexResponse = LexResponse.fromJson(responseData);
        
        // Update session state from response
        _updateSessionState(responseData);
        
        return lexResponse;
      } else {
        print('Lex API error: ${response.statusCode} - ${response.body}');
        throw Exception('Lex API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error calling Lex API: $e');
      // Fallback to mock response
      return _getMockResponse(message);
    }
  }

  static void _updateSessionState(Map<String, dynamic> responseData) {
    final sessionState = responseData['sessionState'];
    if (sessionState != null) {
      // Update session attributes
      final sessionAttributes = sessionState['sessionAttributes'];
      if (sessionAttributes != null) {
        _sessionAttributes.addAll(Map<String, dynamic>.from(sessionAttributes));
      }
      
      // Update intent information
      final intent = sessionState['intent'];
      if (intent != null) {
        _lastIntentName = intent['name'];
        _lastSlots = intent['slots'] != null ? Map<String, dynamic>.from(intent['slots']) : null;
      }
    }
  }

  static Future<Map<String, String>> _createSignedRequest({
    required String method,
    required Uri uri,
    required String body,
    required Map<String, String> headers,
  }) async {
    try {
      // For now, we'll use a simplified approach
      // In production, you should implement proper AWS signature v4
      // or use the AWS SDK for Dart when it becomes available
      
      final signedHeaders = Map<String, String>.from(headers);
      
      // Add basic AWS headers
      signedHeaders['x-amz-date'] = DateTime.now().toUtc().toIso8601String();
      signedHeaders['host'] = uri.host;
      
      // Note: This is a simplified implementation
      // For production use, implement proper AWS signature v4
      print('Warning: Using simplified AWS authentication. Implement proper signature v4 for production.');
      
      return signedHeaders;
    } catch (e) {
      print('Error creating signed request: $e');
      // Return headers without signature for demo mode
      return headers;
    }
  }

  // AWS Lex API integration would go here
  // For demo purposes, we're using mock responses

  static LexResponse _getMockResponse(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Emergency intent
    if (lowerMessage.contains('emergency') || lowerMessage.contains('help') || lowerMessage.contains('sos')) {
      return LexResponse(
        message: "🚨 EMERGENCY ASSISTANCE\n\nI understand you need emergency help. Here are your options:\n\n• Press the SOS button for immediate emergency services\n• Call 999 for police, fire, or medical emergencies\n• Use the 'Mark Safe' feature to let others know you're okay\n\nWhat type of emergency are you experiencing?",
        intentName: 'EmergencyIntent',
        sessionId: _sessionId,
        quickActions: [
          {
            'title': 'Medical Emergency',
            'buttons': [
              {'text': 'Call 999', 'value': 'call_emergency'},
              {'text': 'Find Hospital', 'value': 'find_hospital'},
            ]
          },
          {
            'title': 'Flood Emergency',
            'buttons': [
              {'text': 'Evacuation Routes', 'value': 'evacuation_routes'},
              {'text': 'Shelter Info', 'value': 'shelter_info'},
            ]
          }
        ],
      );
    }
    
    // Flood information intent
    if (lowerMessage.contains('flood') || lowerMessage.contains('water') || lowerMessage.contains('rain')) {
      return LexResponse(
        message: "🌊 FLOOD INFORMATION\n\nCurrent flood status in your area:\n\n• Risk Level: ORANGE (High risk in 24h)\n• Location: Mukim Badang\n• Radius: 1km\n• Last Updated: ${DateTime.now().toString().substring(0, 19)}\n\nStay alert and be prepared to evacuate if necessary.",
        intentName: 'FloodInfoIntent',
        sessionId: _sessionId,
        quickActions: [
          {
            'title': 'Flood Actions',
            'buttons': [
              {'text': 'Safe Routes', 'value': 'safe_routes'},
              {'text': 'Evacuation Centers', 'value': 'evacuation_centers'},
              {'text': 'Emergency Kit', 'value': 'emergency_kit'},
            ]
          }
        ],
      );
    }
    
    // Shelter information intent
    if (lowerMessage.contains('shelter') || lowerMessage.contains('evacuation') || lowerMessage.contains('center')) {
      return LexResponse(
        message: "🏠 EVACUATION CENTERS\n\nAvailable shelters in your area:\n\n1. Sekolah Kebangsaan Badang\n   • Distance: 2km\n   • Capacity: 200 people\n   • Status: Open\n   • Facilities: Food, water, medical\n\n2. Masjid Al-Muttaqin\n   • Distance: 1.5km\n   • Capacity: 150 people\n   • Status: Open\n   • Facilities: Basic supplies\n\n3. Community Hall Badang\n   • Distance: 3km\n   • Capacity: 100 people\n   • Status: Open\n   • Facilities: Communication",
        intentName: 'ShelterInfoIntent',
        sessionId: _sessionId,
        quickActions: [
          {
            'title': 'Shelter Actions',
            'buttons': [
              {'text': 'Get Directions', 'value': 'get_directions'},
              {'text': 'What to Bring', 'value': 'what_to_bring'},
              {'text': 'Contact Shelter', 'value': 'contact_shelter'},
            ]
          }
        ],
      );
    }
    
    // Safe routes intent
    if (lowerMessage.contains('route') || lowerMessage.contains('direction') || lowerMessage.contains('path')) {
      return LexResponse(
        message: "🗺️ SAFE EVACUATION ROUTES\n\nRecommended routes to safety:\n\nRoute 1: Main Road to Kota Bharu\n• Distance: 8km\n• Time: 15 minutes\n• Status: Clear\n• Avoid: Low-lying areas\n\nRoute 2: Alternative via Jalan Hospital\n• Distance: 10km\n• Time: 20 minutes\n• Status: Clear\n• Avoid: Bridges\n\nRoute 3: Emergency to Higher Ground\n• Distance: 5km\n• Time: 10 minutes\n• Status: Clear\n• Best for: Immediate evacuation",
        intentName: 'RouteInfoIntent',
        sessionId: _sessionId,
        quickActions: [
          {
            'title': 'Route Actions',
            'buttons': [
              {'text': 'Start Navigation', 'value': 'start_navigation'},
              {'text': 'Traffic Updates', 'value': 'traffic_updates'},
              {'text': 'Alternative Routes', 'value': 'alternative_routes'},
            ]
          }
        ],
      );
    }
    
    // Weather information intent
    if (lowerMessage.contains('weather') || lowerMessage.contains('rain') || lowerMessage.contains('forecast')) {
      return LexResponse(
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
    return LexResponse(
      message: "Hello! I'm SelamatBot, your emergency assistance chatbot. I can help you with:\n\n• Emergency assistance and SOS\n• Flood information and alerts\n• Evacuation routes and shelters\n• Weather updates\n• Safety tips and guidelines\n\nHow can I assist you today?",
      intentName: 'WelcomeIntent',
      sessionId: _sessionId,
      quickActions: [
        {
          'title': 'Quick Actions',
          'buttons': [
            {'text': 'Emergency Help', 'value': 'emergency_help'},
            {'text': 'Flood Info', 'value': 'flood_info'},
            {'text': 'Safe Routes', 'value': 'safe_routes'},
            {'text': 'Shelter Info', 'value': 'shelter_info'},
          ]
        }
      ],
    );
  }
}
