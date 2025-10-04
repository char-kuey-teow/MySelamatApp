import 'package:flutter_test/flutter_test.dart';
import 'package:my_selamat_app/lex_service.dart';
import 'package:my_selamat_app/config.dart';

void main() {
  group('LexService Tests', () {
    setUp(() {
      // Initialize the service before each test
      LexService.initialize(userId: 'test_user_123');
    });

    tearDown(() {
      // Reset session after each test
      LexService.resetSession();
    });

    test('should initialize with correct user ID', () {
      expect(LexService.currentUserId, equals('test_user_123'));
      expect(LexService.currentSessionId, isNotEmpty);
    });

    test('should generate session ID on initialization', () {
      final sessionId1 = LexService.currentSessionId;
      LexService.resetSession();
      final sessionId2 = LexService.currentSessionId;
      
      expect(sessionId1, isNot(equals(sessionId2)));
    });

    test('should handle emergency messages correctly', () async {
      final response = await LexService.sendMessage('I need emergency help');
      
      expect(response.message, isNotEmpty);
      expect(response.intentName, equals('EmergencyIntent'));
      expect(response.quickActions, isNotNull);
      expect(response.quickActions!.isNotEmpty, isTrue);
    });

    test('should handle flood information requests', () async {
      final response = await LexService.sendMessage('What is the flood status?');
      
      expect(response.message, isNotEmpty);
      expect(response.intentName, equals('FloodInfoIntent'));
      expect(response.message, contains('FLOOD INFORMATION'));
    });

    test('should handle shelter information requests', () async {
      final response = await LexService.sendMessage('Where are the evacuation centers?');
      
      expect(response.message, isNotEmpty);
      expect(response.intentName, equals('ShelterInfoIntent'));
      expect(response.message, contains('EVACUATION CENTERS'));
    });

    test('should handle route information requests', () async {
      final response = await LexService.sendMessage('Show me safe routes');
      
      expect(response.message, isNotEmpty);
      expect(response.intentName, equals('RouteInfoIntent'));
      expect(response.message, contains('SAFE EVACUATION ROUTES'));
    });

    test('should handle weather information requests', () async {
      final response = await LexService.sendMessage('What is the weather forecast?');
      
      expect(response.message, isNotEmpty);
      expect(response.intentName, equals('WeatherInfoIntent'));
      expect(response.message, contains('WEATHER FORECAST'));
    });

    test('should provide default response for unknown messages', () async {
      final response = await LexService.sendMessage('random message');
      
      expect(response.message, isNotEmpty);
      expect(response.intentName, equals('WelcomeIntent'));
      expect(response.message, contains('SelamatBot'));
    });

    test('should maintain session state between messages', () async {
      // Send first message
      await LexService.sendMessage('I need help with flood information');
      
      // Check session attributes are maintained
      expect(LexService.currentSessionAttributes, isA<Map<String, dynamic>>());
      
      // Send follow-up message
      final response = await LexService.sendMessage('What about evacuation routes?');
      
      expect(response.message, isNotEmpty);
    });

    test('should handle quick actions correctly', () async {
      final response = await LexService.sendMessage('emergency help');
      
      expect(response.quickActions, isNotNull);
      
      // Test quick action processing
      if (response.quickActions != null && response.quickActions!.isNotEmpty) {
        final quickAction = response.quickActions!.first;
        expect(quickAction['title'], isNotEmpty);
        expect(quickAction['buttons'], isA<List>());
      }
    });

    test('should test connection successfully in demo mode', () async {
      // In demo mode, connection test should always succeed
      final isConnected = await LexService.testConnection();
      expect(isConnected, isTrue);
    });

    test('should handle empty messages gracefully', () async {
      final response = await LexService.sendMessage('');
      
      expect(response.message, isNotEmpty);
      expect(response.intentName, equals('WelcomeIntent'));
    });

    test('should handle very long messages', () async {
      final longMessage = 'This is a very long message that might cause issues with the chatbot system. ' * 10;
      final response = await LexService.sendMessage(longMessage);
      
      expect(response.message, isNotEmpty);
      // Should not crash and should return a valid response
    });

    test('should extract quick actions correctly', () {
      final mockJson = {
        'sessionState': {
          'dialogAction': {
            'responseCard': {
              'genericAttachments': [
                {
                  'title': 'Emergency Actions',
                  'subTitle': 'Choose an action',
                  'buttons': [
                    {'text': 'Call 999', 'value': 'call_emergency'},
                    {'text': 'Find Hospital', 'value': 'find_hospital'},
                  ]
                }
              ]
            }
          }
        }
      };

      final response = LexResponse.fromJson(mockJson);
      expect(response.quickActions, isNotNull);
      expect(response.quickActions!.length, equals(1));
      expect(response.quickActions!.first['title'], equals('Emergency Actions'));
      expect(response.quickActions!.first['buttons'].length, equals(2));
    });
  });

  group('Config Tests', () {
    test('should validate Lex configuration correctly', () {
      // Test with valid configuration (demo mode)
      expect(Config.isLexConfigValid, isTrue);
      expect(Config.useDemoMode, isTrue);
    });

    test('should have required bot configuration', () {
      expect(Config.lexBotName, isNotEmpty);
      expect(Config.lexBotAlias, isNotEmpty);
      expect(Config.awsRegion, isNotEmpty);
    });
  });

  group('Error Handling Tests', () {
    test('should handle network errors gracefully', () async {
      // This test would require mocking network failures
      // For now, we test that the service doesn't crash
      final response = await LexService.sendMessage('test message');
      expect(response.message, isNotEmpty);
    });

    test('should provide meaningful error messages', () async {
      // Test error handling by sending a message
      final response = await LexService.sendMessage('test');
      expect(response.message, isNotEmpty);
      expect(response.message, isNot(contains('Exception')));
      expect(response.message, isNot(contains('Error')));
    });
  });
}
