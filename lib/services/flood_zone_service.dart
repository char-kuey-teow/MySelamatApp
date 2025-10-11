import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'geometry_service.dart';

class FloodZoneService {
  static const String FLOOD_LOCATIONS_API = "https://sbb646ua7a.execute-api.us-east-1.amazonaws.com/testing/floodLocations";
  
  /// Check if user is currently within any flood zone
  static Future<bool> isUserInFloodZone(Position userPosition) async {
    try {
      floodZoneDebugPrint('🔍 Checking if user is in flood zone...');
      floodZoneDebugPrint('📍 User position: ${userPosition.latitude}, ${userPosition.longitude}');
      
      // Get flood zone data (try cache first, then API)
      final floodData = await _getFloodZoneData();
      if (floodData == null || floodData.isEmpty) {
        floodZoneDebugPrint('❌ No flood zone data available');
        return false;
      }
      
      final userLatLng = LatLng(userPosition.latitude, userPosition.longitude);
      
      // Check if user is within any flood zone polygon
      for (final floodZone in floodData) {
        floodZoneDebugPrint('🔍 Checking flood zone: ${floodZone['name']}');
        floodZoneDebugPrint('   Available keys: ${floodZone.keys.toList()}');
        
        // Try both 'polygons' and 'decagonCoordinates' fields
        bool isInZone = false;
        
        if (floodZone['polygons'] != null) {
          floodZoneDebugPrint('   Using polygons field');
          isInZone = _isPointInFloodZonePolygons(userLatLng, floodZone['polygons']);
        } else if (floodZone['decagonCoordinates'] != null) {
          floodZoneDebugPrint('   Using decagonCoordinates field');
          isInZone = _isPointInFloodZonePolygons(userLatLng, floodZone['decagonCoordinates']);
        } else {
          floodZoneDebugPrint('   No polygon data found');
        }
        
        if (isInZone) {
          floodZoneDebugPrint('✅ User is in flood zone: ${floodZone['name']}');
          return true;
        }
      }
      
      floodZoneDebugPrint('❌ User is not in any flood zone');
      return false;
    } catch (e) {
      floodZoneDebugPrint('❌ Error checking flood zone: $e');
      return false;
    }
  }
  
  /// Get flood zone data (cache first, then API)
  static Future<List<dynamic>?> _getFloodZoneData() async {
    try {
      // Try cache first
      final cachedData = await _getCachedFloodData();
      if (cachedData != null) {
        floodZoneDebugPrint('✅ Using cached flood zone data');
        return cachedData;
      }
      
      // Fallback to API
      floodZoneDebugPrint('🔄 Loading flood zone data from API...');
      final response = await http.get(Uri.parse(FLOOD_LOCATIONS_API));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final locationsData = data['data'] as List<dynamic>;
          floodZoneDebugPrint('✅ Flood zone data loaded: ${locationsData.length} locations');
          
          // Cache the data
          await _cacheFloodData(data);
          
          return locationsData;
        }
      }
      
      floodZoneDebugPrint('❌ Failed to load flood zone data: ${response.statusCode}');
      return null;
    } catch (e) {
      floodZoneDebugPrint('❌ Error loading flood zone data: $e');
      return null;
    }
  }
  
  /// Get cached flood data
  static Future<List<dynamic>?> _getCachedFloodData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('flood_data_cache');
      final time = prefs.getString('flood_data_cache_time');
      
      if (data != null && time != null) {
        final age = DateTime.now().difference(DateTime.parse(time));
        const cacheDuration = Duration(minutes: 10);
        
        if (age < cacheDuration) {
          final parsedData = jsonDecode(data);
          if (parsedData['success'] == true && parsedData['data'] != null) {
            return parsedData['data'] as List<dynamic>;
          }
        }
      }
      return null;
    } catch (e) {
      floodZoneDebugPrint('❌ Error getting cached flood data: $e');
      return null;
    }
  }
  
  /// Cache flood data
  static Future<void> _cacheFloodData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('flood_data_cache', jsonEncode(data));
      await prefs.setString('flood_data_cache_time', DateTime.now().toIso8601String());
      floodZoneDebugPrint('✅ Flood data cached successfully');
    } catch (e) {
      floodZoneDebugPrint('❌ Error caching flood data: $e');
    }
  }
  
  /// Check if a point is inside flood zone polygons (handles API format)
  static bool _isPointInFloodZonePolygons(LatLng point, dynamic polygons) {
    if (polygons == null) return false;
    
    floodZoneDebugPrint('   Polygon data type: ${polygons.runtimeType}');
    floodZoneDebugPrint('   Polygon data length: ${polygons is List ? polygons.length : 'not a list'}');
    
    // Handle different polygon formats from API
    List<List<LatLng>> polygonList;
    if (polygons is List) {
      if (polygons.isEmpty) {
        floodZoneDebugPrint('   Empty polygon list');
        return false;
      }
      
      // Check if it's a list of coordinate objects (decagonCoordinates format)
      if (polygons.first is Map && polygons.first.containsKey('latitude')) {
        floodZoneDebugPrint('   DecagonCoordinates format detected');
        polygonList = [polygons.map((coord) => LatLng(
          coord['latitude'] as double, 
          coord['longitude'] as double
        )).toList()];
      }
      // Check if it's a list of lists (multiple polygons)
      else if (polygons.first is List) {
        floodZoneDebugPrint('   Multiple polygons format detected');
        polygonList = polygons.map((poly) => 
          (poly as List).map((coord) => LatLng(
            coord['latitude'] as double, 
            coord['longitude'] as double
          )).toList()
        ).toList();
      } else {
        floodZoneDebugPrint('   Unknown polygon format');
        return false;
      }
    } else {
      floodZoneDebugPrint('   Not a list format');
      return false;
    }
    
    floodZoneDebugPrint('   Converted to ${polygonList.length} polygon(s)');
    if (polygonList.isNotEmpty) {
      floodZoneDebugPrint('   First polygon has ${polygonList.first.length} points');
    }
    
    // Use GeometryService for point-in-polygon check
    final result = GeometryService.isPointInAnyPolygon(point, polygonList);
    floodZoneDebugPrint('   Point-in-polygon result: $result');
    return result;
  }
  
  /// Log SOS attempt outside flood zone for analytics
  static Future<void> logSOSAttemptOutsideFloodZone(Position userPosition) async {
    try {
      final logData = {
        'timestamp': DateTime.now().toIso8601String(),
        'userLatitude': userPosition.latitude,
        'userLongitude': userPosition.longitude,
        'action': 'sos_attempt_outside_flood_zone',
        'reason': 'User attempted SOS outside flood zone',
      };
      
      // Store in local storage for analytics
      final prefs = await SharedPreferences.getInstance();
      final existingLogs = prefs.getStringList('sos_attempt_logs') ?? [];
      existingLogs.add(jsonEncode(logData));
      
      // Keep only last 100 logs to prevent storage bloat
      if (existingLogs.length > 100) {
        existingLogs.removeRange(0, existingLogs.length - 100);
      }
      
      await prefs.setStringList('sos_attempt_logs', existingLogs);
      floodZoneDebugPrint('📊 Logged SOS attempt outside flood zone');
    } catch (e) {
      floodZoneDebugPrint('❌ Error logging SOS attempt: $e');
    }
  }
}

// Debug print function
void floodZoneDebugPrint(String message) {
  print('🌊 FloodZoneService: $message');
}
