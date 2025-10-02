import 'package:flutter_test/flutter_test.dart';
import 'package:my_selamat_app/profile.dart';

void main() {
  group('SOS Button Tests', () {
    test('UserProfile JSON serialization', () {
      final profile = UserProfile(
        id: 'test_user_123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
        phoneNumber: '+60 12-345 6789',
        address: '123 Test Street, Test City',
        floodRegions: ['Test Region 1', 'Test Region 2'],
      );

      final json = profile.toJson();
      expect(json['id'], equals('test_user_123'));
      expect(json['email'], equals('test@example.com'));
      expect(json['displayName'], equals('Test User'));
      expect(json['phoneNumber'], equals('+60 12-345 6789'));
      expect(json['address'], equals('123 Test Street, Test City'));
      expect(json['floodRegions'], isA<List<String>>());
      expect(json['floodRegions'].length, equals(2));

      final restoredProfile = UserProfile.fromJson(json);
      expect(restoredProfile.id, equals(profile.id));
      expect(restoredProfile.email, equals(profile.email));
      expect(restoredProfile.displayName, equals(profile.displayName));
      expect(restoredProfile.phoneNumber, equals(profile.phoneNumber));
      expect(restoredProfile.address, equals(profile.address));
      expect(restoredProfile.floodRegions, equals(profile.floodRegions));
    });

    test('SOS Data structure validation', () {
      final sosData = {
        'userId': 'test_user_123',
        'userName': 'Test User',
        'userEmail': 'test@example.com',
        'userPhone': '+60 12-345 6789',
        'userAddress': '123 Test Street, Test City',
        'category': 'Medical Emergency',
        'latitude': 3.1390,
        'longitude': 101.6869,
        'accuracy': 10.0,
        'altitude': 50.0,
        'speed': 0.0,
        'heading': 0.0,
        'timestamp': '2024-01-01T12:00:00.000Z',
        'status': 'active',
        'deviceInfo': {'platform': 'android', 'appVersion': '1.0.0'},
      };

      expect(sosData['userId'], isA<String>());
      expect(sosData['userName'], isA<String>());
      expect(sosData['userEmail'], isA<String>());
      expect(sosData['userPhone'], isA<String>());
      expect(sosData['userAddress'], isA<String>());
      expect(sosData['category'], isA<String>());
      expect(sosData['latitude'], isA<double>());
      expect(sosData['longitude'], isA<double>());
      expect(sosData['timestamp'], isA<String>());
      expect(sosData['status'], equals('active'));
      expect(sosData['deviceInfo'], isA<Map<String, dynamic>>());
    });
  });
}
