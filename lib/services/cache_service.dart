import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  // Cache keys
  static const String _floodDataKey = 'flood_zones_cache';
  static const String _floodDataTimeKey = 'flood_zones_cache_time';
  static const String _safeZonesDataKey = 'safe_zones_cache';
  static const String _safeZonesDataTimeKey = 'safe_zones_cache_time';
  static const String _userLocationKey = 'user_location_cache';
  static const String _userLocationTimeKey = 'user_location_cache_time';

  // Cache durations
  static const Duration _floodDataCacheDuration = Duration(minutes: 10); // Updated to 10 minutes
  static const Duration _safeZonesCacheDuration = Duration(hours: 24);
  static const Duration _userLocationCacheDuration = Duration(minutes: 5);

  /// Cache flood zones data
  static Future<void> cacheFloodData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_floodDataKey, jsonEncode(data));
      await prefs.setString(_floodDataTimeKey, DateTime.now().toIso8601String());
      print('✅ Flood data cached successfully');
    } catch (e) {
      print('❌ Error caching flood data: $e');
    }
  }

  /// Get cached flood zones data
  static Future<Map<String, dynamic>?> getCachedFloodData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_floodDataKey);
      final time = prefs.getString(_floodDataTimeKey);

      if (data != null && time != null) {
        final age = DateTime.now().difference(DateTime.parse(time));
        if (age < _floodDataCacheDuration) {
          print('✅ Using cached flood data (age: ${age.inMinutes} minutes)');
          return jsonDecode(data);
        } else {
          print('⚠️ Flood data cache expired (age: ${age.inHours} hours)');
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting cached flood data: $e');
      return null;
    }
  }

  /// Cache safe zones data
  static Future<void> cacheSafeZonesData(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_safeZonesDataKey, jsonEncode(data));
      await prefs.setString(_safeZonesDataTimeKey, DateTime.now().toIso8601String());
      print('✅ Safe zones data cached successfully');
    } catch (e) {
      print('❌ Error caching safe zones data: $e');
    }
  }

  /// Get cached safe zones data
  static Future<List<Map<String, dynamic>>?> getCachedSafeZonesData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_safeZonesDataKey);
      final time = prefs.getString(_safeZonesDataTimeKey);

      if (data != null && time != null) {
        final age = DateTime.now().difference(DateTime.parse(time));
        if (age < _safeZonesCacheDuration) {
          print('✅ Using cached safe zones data (age: ${age.inMinutes} minutes)');
          return List<Map<String, dynamic>>.from(jsonDecode(data));
        } else {
          print('⚠️ Safe zones data cache expired (age: ${age.inHours} hours)');
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting cached safe zones data: $e');
      return null;
    }
  }

  /// Cache user location data
  static Future<void> cacheUserLocation(Map<String, dynamic> locationData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userLocationKey, jsonEncode(locationData));
      await prefs.setString(_userLocationTimeKey, DateTime.now().toIso8601String());
      print('✅ User location cached successfully');
    } catch (e) {
      print('❌ Error caching user location: $e');
    }
  }

  /// Get cached user location data
  static Future<Map<String, dynamic>?> getCachedUserLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_userLocationKey);
      final time = prefs.getString(_userLocationTimeKey);

      if (data != null && time != null) {
        final age = DateTime.now().difference(DateTime.parse(time));
        if (age < _userLocationCacheDuration) {
          print('✅ Using cached user location (age: ${age.inMinutes} minutes)');
          return jsonDecode(data);
        } else {
          print('⚠️ User location cache expired (age: ${age.inMinutes} minutes)');
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting cached user location: $e');
      return null;
    }
  }

  /// Clear all cache
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_floodDataKey);
      await prefs.remove(_floodDataTimeKey);
      await prefs.remove(_safeZonesDataKey);
      await prefs.remove(_safeZonesDataTimeKey);
      await prefs.remove(_userLocationKey);
      await prefs.remove(_userLocationTimeKey);
      print('✅ All cache cleared');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  /// Clear specific cache
  static Future<void> clearFloodDataCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_floodDataKey);
      await prefs.remove(_floodDataTimeKey);
      print('✅ Flood data cache cleared');
    } catch (e) {
      print('❌ Error clearing flood data cache: $e');
    }
  }

  static Future<void> clearSafeZonesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_safeZonesDataKey);
      await prefs.remove(_safeZonesDataTimeKey);
      print('✅ Safe zones cache cleared');
    } catch (e) {
      print('❌ Error clearing safe zones cache: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final floodTime = prefs.getString(_floodDataTimeKey);
      final safeZonesTime = prefs.getString(_safeZonesDataTimeKey);
      final userLocationTime = prefs.getString(_userLocationTimeKey);

      final stats = <String, dynamic>{};

      if (floodTime != null) {
        final age = DateTime.now().difference(DateTime.parse(floodTime));
        stats['floodData'] = {
          'cached': true,
          'age': '${age.inMinutes} minutes',
          'expired': age >= _floodDataCacheDuration,
        };
      } else {
        stats['floodData'] = {'cached': false};
      }

      if (safeZonesTime != null) {
        final age = DateTime.now().difference(DateTime.parse(safeZonesTime));
        stats['safeZones'] = {
          'cached': true,
          'age': '${age.inMinutes} minutes',
          'expired': age >= _safeZonesCacheDuration,
        };
      } else {
        stats['safeZones'] = {'cached': false};
      }

      if (userLocationTime != null) {
        final age = DateTime.now().difference(DateTime.parse(userLocationTime));
        stats['userLocation'] = {
          'cached': true,
          'age': '${age.inMinutes} minutes',
          'expired': age >= _userLocationCacheDuration,
        };
      } else {
        stats['userLocation'] = {'cached': false};
      }

      return stats;
    } catch (e) {
      print('❌ Error getting cache stats: $e');
      return {};
    }
  }

  /// Check if cache is available and fresh
  static Future<bool> isFloodDataCacheAvailable() async {
    final cachedData = await getCachedFloodData();
    return cachedData != null;
  }

  static Future<bool> isSafeZonesCacheAvailable() async {
    final cachedData = await getCachedSafeZonesData();
    return cachedData != null;
  }

  static Future<bool> isUserLocationCacheAvailable() async {
    final cachedData = await getCachedUserLocation();
    return cachedData != null;
  }
}
