import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalSOSState {
  final bool isActive;
  final String? category;
  final DateTime? timestamp;
  final double? latitude;
  final double? longitude;
  final String? coordinates;
  final String? area;
  final String? state;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final String status; // 'active', 'resolved', 'cancelled'
  final Map<String, String>? locationDetails;
  final String? sosId; // Store the SOS ID for updates

  LocalSOSState({
    required this.isActive,
    this.category,
    this.timestamp,
    this.latitude,
    this.longitude,
    this.coordinates,
    this.area,
    this.state,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.status = 'active',
    this.locationDetails,
    this.sosId,
  });

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'category': category,
      'timestamp': timestamp?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'coordinates': coordinates,
      'area': area,
      'state': state,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'status': status,
      'locationDetails': locationDetails,
      'sosId': sosId,
    };
  }

  factory LocalSOSState.fromJson(Map<String, dynamic> json) {
    return LocalSOSState(
      isActive: json['isActive'] ?? false,
      category: json['category'],
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      coordinates: json['coordinates'],
      area: json['area'],
      state: json['state'],
      accuracy: json['accuracy']?.toDouble(),
      altitude: json['altitude']?.toDouble(),
      speed: json['speed']?.toDouble(),
      heading: json['heading']?.toDouble(),
      status: json['status'] ?? 'active',
      locationDetails: json['locationDetails'] != null 
          ? Map<String, String>.from(json['locationDetails'])
          : null,
      sosId: json['sosId'],
    );
  }

  LocalSOSState copyWith({
    bool? isActive,
    String? category,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? coordinates,
    String? area,
    String? state,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    String? status,
    Map<String, String>? locationDetails,
    String? sosId,
  }) {
    return LocalSOSState(
      isActive: isActive ?? this.isActive,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      coordinates: coordinates ?? this.coordinates,
      area: area ?? this.area,
      state: state ?? this.state,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      status: status ?? this.status,
      locationDetails: locationDetails ?? this.locationDetails,
      sosId: sosId ?? this.sosId,
    );
  }
}

class SOSStateService {
  static const String _sosStateKey = 'activeSOS';
  static const String _sosHistoryKey = 'sosHistory';

  /// Save active SOS state to local storage
  static Future<void> saveActiveSOS(LocalSOSState sosState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(sosState.toJson());
      await prefs.setString(_sosStateKey, jsonString);
      print('✅ SOS state saved to local storage');
    } catch (e) {
      print('❌ Error saving SOS state: $e');
    }
  }

  /// Load active SOS state from local storage
  static Future<LocalSOSState?> loadActiveSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_sosStateKey);
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString);
        final sosState = LocalSOSState.fromJson(json);
        
        // Check if SOS is still valid (not expired)
        if (sosState.isActive && sosState.timestamp != null) {
          final hoursSinceCreated = DateTime.now().difference(sosState.timestamp!).inHours;
          
          // Auto-expire SOS after 24 hours
          if (hoursSinceCreated >= 24) {
            print('SOS expired after 24 hours, clearing state');
            await clearActiveSOS();
            return null;
          }
        }
        
        print('✅ SOS state loaded from local storage');
        return sosState;
      }
      
      return null;
    } catch (e) {
      print('❌ Error loading SOS state: $e');
      return null;
    }
  }

  /// Clear active SOS state from local storage
  static Future<void> clearActiveSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sosStateKey);
      print('✅ SOS state cleared from local storage');
    } catch (e) {
      print('❌ Error clearing SOS state: $e');
    }
  }

  /// Check if there's an active SOS
  static Future<bool> hasActiveSOS() async {
    final sosState = await loadActiveSOS();
    return sosState?.isActive == true;
  }

  /// Add SOS to history
  static Future<void> addToHistory(LocalSOSState sosState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_sosHistoryKey);
      
      List<Map<String, dynamic>> history = [];
      if (historyString != null) {
        history = List<Map<String, dynamic>>.from(jsonDecode(historyString));
      }
      
      // Add new SOS to history
      history.add(sosState.toJson());
      
      // Keep only last 50 SOS reports
      if (history.length > 50) {
        history = history.sublist(history.length - 50);
      }
      
      await prefs.setString(_sosHistoryKey, jsonEncode(history));
      print('✅ SOS added to history');
    } catch (e) {
      print('❌ Error adding SOS to history: $e');
    }
  }

  /// Get SOS history
  static Future<List<LocalSOSState>> getSOSHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_sosHistoryKey);
      
      if (historyString != null) {
        final history = List<Map<String, dynamic>>.from(jsonDecode(historyString));
        return history.map((json) => LocalSOSState.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('❌ Error loading SOS history: $e');
      return [];
    }
  }
}
