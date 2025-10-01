import 'package:flutter/material.dart';

// --- Chatbot Service for Text-Only Communication ---

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<QuickAction>? quickActions;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickActions,
  });
}

class QuickAction {
  final String text;
  final String action;
  final IconData icon;

  QuickAction({
    required this.text,
    required this.action,
    required this.icon,
  });
}

class ChatbotService {
  static final List<ChatMessage> _messages = [];
  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    
    _messages.clear();
    _addWelcomeMessage();
    _isInitialized = true;
  }

  static void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: "Hello! I'm SelamatBot, your emergency assistance chatbot. How can I help you today?",
      isUser: false,
      timestamp: DateTime.now(),
      quickActions: [
        QuickAction(
          text: "Emergency Help",
          action: "emergency_help",
          icon: Icons.sos,
        ),
        QuickAction(
          text: "Flood Info",
          action: "flood_info",
          icon: Icons.water_drop,
        ),
        QuickAction(
          text: "Safe Routes",
          action: "safe_routes",
          icon: Icons.directions,
        ),
        QuickAction(
          text: "Shelter Info",
          action: "shelter_info",
          icon: Icons.home,
        ),
      ],
    ));
  }

  static List<ChatMessage> getMessages() {
    return List.from(_messages);
  }

  static void clearMessages() {
    _messages.clear();
    _addWelcomeMessage();
  }

  static Future<List<ChatMessage>> processUserMessage(String message) async {
    // Add user message
    _messages.add(ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 1000));

    // Generate bot response
    final response = _generateResponse(message.toLowerCase());
    
    // Add bot response
    _messages.add(ChatMessage(
      text: response.text,
      isUser: false,
      timestamp: DateTime.now(),
      quickActions: response.quickActions,
    ));

    return [response];
  }

  static Future<List<ChatMessage>> processQuickAction(String action) async {
    // Add user action message
    _messages.add(ChatMessage(
      text: "Quick action: $action",
      isUser: true,
      timestamp: DateTime.now(),
    ));

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Generate response for quick action
    final response = _generateQuickActionResponse(action);
    
    // Add bot response
    _messages.add(ChatMessage(
      text: response.text,
      isUser: false,
      timestamp: DateTime.now(),
      quickActions: response.quickActions,
    ));

    return [response];
  }

  static ChatMessage _generateResponse(String message) {
    // Emergency keywords
    if (message.contains('emergency') || message.contains('help') || message.contains('sos')) {
      return ChatMessage(
        text: "🚨 EMERGENCY ALERT! I'm here to help. Please stay calm and follow these steps:\n\n1. If you're in immediate danger, call 999 immediately\n2. Move to higher ground if there's flooding\n3. Gather essential items (medication, documents, phone)\n4. Follow evacuation routes if instructed\n\nWould you like me to help you find the nearest emergency services or safe location?",
        isUser: false,
        timestamp: DateTime.now(),
        quickActions: [
          QuickAction(text: "Call 999", action: "call_emergency", icon: Icons.phone),
          QuickAction(text: "Find Safe Zone", action: "find_safe_zone", icon: Icons.location_on),
          QuickAction(text: "Emergency Contacts", action: "emergency_contacts", icon: Icons.contacts),
        ],
      );
    }

    // Flood-related keywords
    if (message.contains('flood') || message.contains('water') || message.contains('rain')) {
      return ChatMessage(
        text: "🌊 Flood Information:\n\nCurrent Status: Orange Alert (High Risk)\nLocation: Mukim Badang\nRisk Level: High risk in 24 hours\n\nRecommendations:\n• Move valuables to higher ground\n• Prepare evacuation plan\n• Monitor water levels\n• Stay informed via official channels\n\nWould you like information about safe routes or evacuation centers?",
        isUser: false,
        timestamp: DateTime.now(),
        quickActions: [
          QuickAction(text: "Safe Routes", action: "safe_routes", icon: Icons.directions),
          QuickAction(text: "Evacuation Centers", action: "evacuation_centers", icon: Icons.home),
          QuickAction(text: "Weather Update", action: "weather_update", icon: Icons.cloud),
        ],
      );
    }

    // Route and navigation
    if (message.contains('route') || message.contains('direction') || message.contains('way')) {
      return ChatMessage(
        text: "🗺️ Safe Route Information:\n\nRecommended evacuation routes:\n• Route 1: Main road to Kota Bharu (15 min)\n• Route 2: Alternative route via Jalan Hospital (20 min)\n• Route 3: Emergency route to higher ground (10 min)\n\n⚠️ Avoid low-lying areas and bridges during flooding.\n\nWould you like detailed directions or real-time traffic updates?",
        isUser: false,
        timestamp: DateTime.now(),
        quickActions: [
          QuickAction(text: "Get Directions", action: "get_directions", icon: Icons.navigation),
          QuickAction(text: "Traffic Updates", action: "traffic_updates", icon: Icons.traffic),
          QuickAction(text: "Alternative Routes", action: "alternative_routes", icon: Icons.alt_route),
        ],
      );
    }

    // Shelter information
    if (message.contains('shelter') || message.contains('evacuation') || message.contains('center')) {
      return ChatMessage(
        text: "🏠 Evacuation Centers:\n\nNearby shelters:\n• Sekolah Kebangsaan Badang (2km)\n• Masjid Al-Muttaqin (1.5km)\n• Community Hall Badang (3km)\n\nAll centers are equipped with:\n• Basic supplies\n• Medical assistance\n• Communication facilities\n• Food and water\n\nNeed help finding the nearest center?",
        isUser: false,
        timestamp: DateTime.now(),
        quickActions: [
          QuickAction(text: "Nearest Shelter", action: "nearest_shelter", icon: Icons.location_on),
          QuickAction(text: "Shelter Status", action: "shelter_status", icon: Icons.info),
          QuickAction(text: "What to Bring", action: "what_to_bring", icon: Icons.backpack),
        ],
      );
    }

    // Weather information
    if (message.contains('weather') || message.contains('forecast') || message.contains('rain')) {
      return ChatMessage(
        text: "🌤️ Weather Update:\n\nCurrent: Heavy rain, 25°C\nForecast: Rain expected for next 48 hours\nWind: 15-20 km/h from Southeast\nHumidity: 85%\n\n⚠️ Flood risk: HIGH\n\nStay updated with the latest weather information and follow official advisories.",
        isUser: false,
        timestamp: DateTime.now(),
        quickActions: [
          QuickAction(text: "Detailed Forecast", action: "detailed_forecast", icon: Icons.calendar_today),
          QuickAction(text: "Flood Alerts", action: "flood_alerts", icon: Icons.warning),
          QuickAction(text: "Safety Tips", action: "safety_tips", icon: Icons.tips_and_updates),
        ],
      );
    }

    // General help
    if (message.contains('help') || message.contains('what') || message.contains('how')) {
      return ChatMessage(
        text: "I'm here to help with emergency situations and flood-related information. You can ask me about:\n\n• Emergency procedures\n• Flood status and alerts\n• Safe evacuation routes\n• Nearby shelters\n• Weather updates\n• Safety tips\n\nWhat would you like to know?",
        isUser: false,
        timestamp: DateTime.now(),
        quickActions: [
          QuickAction(text: "Emergency Help", action: "emergency_help", icon: Icons.sos),
          QuickAction(text: "Flood Info", action: "flood_info", icon: Icons.water_drop),
          QuickAction(text: "Safety Tips", action: "safety_tips", icon: Icons.tips_and_updates),
        ],
      );
    }

    // Default response
    return ChatMessage(
      text: "I understand you're looking for help. I'm SelamatBot, specialized in emergency assistance and flood information. Could you please be more specific about what you need help with?\n\nI can assist with:\n• Emergency situations\n• Flood information\n• Safe routes\n• Shelter locations\n• Weather updates",
      isUser: false,
      timestamp: DateTime.now(),
      quickActions: [
        QuickAction(text: "Emergency Help", action: "emergency_help", icon: Icons.sos),
        QuickAction(text: "Flood Info", action: "flood_info", icon: Icons.water_drop),
        QuickAction(text: "Safe Routes", action: "safe_routes", icon: Icons.directions),
        QuickAction(text: "Shelter Info", action: "shelter_info", icon: Icons.home),
      ],
    );
  }

  static ChatMessage _generateQuickActionResponse(String action) {
    switch (action) {
      case 'emergency_help':
        return ChatMessage(
          text: "🚨 EMERGENCY ASSISTANCE\n\nIf you're in immediate danger:\n1. Call 999 immediately\n2. Move to higher ground\n3. Stay away from floodwaters\n4. Follow official instructions\n\nEmergency contacts:\n• Police: 999\n• Fire & Rescue: 999\n• Hospital: 09-748 5533\n• Civil Defense: 09-748 1000",
          isUser: false,
          timestamp: DateTime.now(),
          quickActions: [
            QuickAction(text: "Call 999", action: "call_emergency", icon: Icons.phone),
            QuickAction(text: "Find Safe Zone", action: "find_safe_zone", icon: Icons.location_on),
          ],
        );

      case 'flood_info':
        return ChatMessage(
          text: "🌊 FLOOD INFORMATION\n\nCurrent Status: ORANGE ALERT\nLocation: Mukim Badang\nRisk: High risk in 24 hours\nRadius: 1km\nLast Updated: 9/29/2025, 12:28 AM\n\nRecommendations:\n• Move valuables to higher ground\n• Prepare evacuation plan\n• Monitor water levels\n• Stay informed",
          isUser: false,
          timestamp: DateTime.now(),
          quickActions: [
            QuickAction(text: "Safe Routes", action: "safe_routes", icon: Icons.directions),
            QuickAction(text: "Evacuation Centers", action: "evacuation_centers", icon: Icons.home),
          ],
        );

      case 'safe_routes':
        return ChatMessage(
          text: "🗺️ SAFE EVACUATION ROUTES\n\nRoute 1: Main Road to Kota Bharu\n• Distance: 8km\n• Time: 15 minutes\n• Status: Clear\n\nRoute 2: Alternative via Jalan Hospital\n• Distance: 10km\n• Time: 20 minutes\n• Status: Clear\n\nRoute 3: Emergency to Higher Ground\n• Distance: 5km\n• Time: 10 minutes\n• Status: Clear\n\n⚠️ Avoid low-lying areas and bridges",
          isUser: false,
          timestamp: DateTime.now(),
          quickActions: [
            QuickAction(text: "Get Directions", action: "get_directions", icon: Icons.navigation),
            QuickAction(text: "Traffic Updates", action: "traffic_updates", icon: Icons.traffic),
          ],
        );

      case 'shelter_info':
        return ChatMessage(
          text: "🏠 EVACUATION CENTERS\n\n1. Sekolah Kebangsaan Badang\n• Distance: 2km\n• Capacity: 200 people\n• Status: Open\n• Facilities: Food, water, medical\n\n2. Masjid Al-Muttaqin\n• Distance: 1.5km\n• Capacity: 150 people\n• Status: Open\n• Facilities: Basic supplies\n\n3. Community Hall Badang\n• Distance: 3km\n• Capacity: 100 people\n• Status: Open\n• Facilities: Communication",
          isUser: false,
          timestamp: DateTime.now(),
          quickActions: [
            QuickAction(text: "Nearest Shelter", action: "nearest_shelter", icon: Icons.location_on),
            QuickAction(text: "What to Bring", action: "what_to_bring", icon: Icons.backpack),
          ],
        );

      default:
        return ChatMessage(
          text: "I'm processing your request. How else can I help you?",
          isUser: false,
          timestamp: DateTime.now(),
          quickActions: [
            QuickAction(text: "Emergency Help", action: "emergency_help", icon: Icons.sos),
            QuickAction(text: "Flood Info", action: "flood_info", icon: Icons.water_drop),
            QuickAction(text: "Safe Routes", action: "safe_routes", icon: Icons.directions),
            QuickAction(text: "Shelter Info", action: "shelter_info", icon: Icons.home),
          ],
        );
    }
  }
}

