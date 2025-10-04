import 'package:flutter/material.dart';
import 'lex_service.dart';
import 'amplify_interactions_service.dart';
import 'config.dart';

// --- Chatbot Service with Amazon Lex Integration ---

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

  static void initialize({String? userId}) async {
    if (_isInitialized) return;
    
    _messages.clear();
    
    // Initialize the appropriate Lex service based on configuration
    if (Config.useAmplify) {
      await AmplifyInteractionsService.initialize(userId: userId);
      // Add user location to session attributes if available
      AmplifyInteractionsService.setSessionAttribute('userLocation', 'Malaysia');
      AmplifyInteractionsService.setSessionAttribute('appVersion', '1.0.0');
    } else {
      LexService.initialize(userId: userId);
      // Add user location to session attributes if available
      LexService.setSessionAttribute('userLocation', 'Malaysia');
      LexService.setSessionAttribute('appVersion', '1.0.0');
    }
    
    _addWelcomeMessage();
    _isInitialized = true;
  }

  static void _addWelcomeMessage() {
    final serviceName = Config.useAmplify ? "AWS Amplify and Amazon Lex" : "Amazon Lex";
    _messages.add(ChatMessage(
      text: "Hello! I'm SelamatBot, your emergency assistance chatbot powered by $serviceName. I can help you with emergency assistance, flood information, and weather updates. How can I help you today?",
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
          text: "Weather Info",
          action: "weather_info",
          icon: Icons.wb_sunny,
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

    // Send message to the appropriate Lex service
    dynamic lexResponse;
    if (Config.useAmplify) {
      lexResponse = await AmplifyInteractionsService.sendMessage(message);
    } else {
      lexResponse = await LexService.sendMessage(message);
    }
    
    // Convert Lex response to ChatMessage
    final botResponse = ChatMessage(
      text: lexResponse.message,
      isUser: false,
      timestamp: DateTime.now(),
      quickActions: lexResponse.quickActions?.map((action) => 
        QuickAction(
          text: action['title'] ?? '',
          action: action['buttons']?[0]?['value'] ?? '',
          icon: _getIconForAction(action['buttons']?[0]?['value'] ?? ''),
        )
      ).toList(),
    );
    
    _messages.add(botResponse);
    return [botResponse];
  }

  static IconData _getIconForAction(String action) {
    switch (action) {
      case 'emergency_help':
      case 'call_emergency':
        return Icons.sos;
      case 'flood_info':
        return Icons.water_drop;
      case 'safe_routes':
      case 'get_directions':
        return Icons.directions;
      case 'shelter_info':
      case 'evacuation_centers':
        return Icons.home;
      case 'weather_info':
        return Icons.wb_sunny;
      default:
        return Icons.help_outline;
    }
  }

  static Future<List<ChatMessage>> processQuickAction(String action) async {
    // Add user action message
    _messages.add(ChatMessage(
      text: "Quick action: $action",
      isUser: true,
      timestamp: DateTime.now(),
    ));

    // Send quick action to the appropriate Lex service
    dynamic lexResponse;
    if (Config.useAmplify) {
      lexResponse = await AmplifyInteractionsService.sendMessage(action);
    } else {
      lexResponse = await LexService.sendMessage(action);
    }
    
    // Convert Lex response to ChatMessage
    final botResponse = ChatMessage(
      text: lexResponse.message,
      isUser: false,
      timestamp: DateTime.now(),
      quickActions: lexResponse.quickActions?.map((action) => 
        QuickAction(
          text: action['title'] ?? '',
          action: action['buttons']?[0]?['value'] ?? '',
          icon: _getIconForAction(action['buttons']?[0]?['value'] ?? ''),
        )
      ).toList(),
    );
    
    _messages.add(botResponse);
    return [botResponse];
  }


  // Get session information for debugging
  static Map<String, dynamic> getSessionInfo() {
    if (Config.useAmplify) {
      return AmplifyInteractionsService.getSessionInfo();
    } else {
      return LexService.getSessionInfo();
    }
  }

  // Clear session and restart
  static void restartSession({String? userId}) async {
    _messages.clear();
    if (Config.useAmplify) {
      AmplifyInteractionsService.resetSession();
      if (userId != null) {
        await AmplifyInteractionsService.initialize(userId: userId);
      }
    } else {
      LexService.resetSession();
      if (userId != null) {
        LexService.initialize(userId: userId);
      }
    }
    _addWelcomeMessage();
  }

}

