import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

/// Service for geometric calculations and spatial operations
class GeometryService {
  /// Check if a point is inside a polygon using ray casting algorithm
  /// 
  /// This is a robust point-in-polygon test that works for any polygon shape.
  /// It uses the ray casting algorithm which casts a ray from the point to
  /// infinity and counts intersections with polygon edges.
  /// 
  /// Parameters:
  /// - [point]: The point to test (LatLng)
  /// - [polygon]: The polygon vertices (List<LatLng>)
  /// 
  /// Returns:
  /// - true if point is inside polygon, false otherwise
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    
    bool inside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;
      
      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    
    return inside;
  }
  
  /// Check if a point is inside any polygon from a list of polygons
  /// 
  /// Parameters:
  /// - [point]: The point to test (LatLng)
  /// - [polygons]: List of polygons (List<List<LatLng>>)
  /// 
  /// Returns:
  /// - true if point is inside any polygon, false otherwise
  static bool isPointInAnyPolygon(LatLng point, List<List<LatLng>> polygons) {
    for (final polygon in polygons) {
      if (isPointInPolygon(point, polygon)) {
        return true;
      }
    }
    return false;
  }
  
  /// Calculate the distance between two points using Haversine formula
  /// 
  /// Parameters:
  /// - [point1]: First point (LatLng)
  /// - [point2]: Second point (LatLng)
  /// 
  /// Returns:
  /// - Distance in kilometers
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double lat1Rad = point1.latitude * (3.14159265359 / 180);
    final double lat2Rad = point2.latitude * (3.14159265359 / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (3.14159265359 / 180);
    
    final double a = (deltaLatRad / 2).sin() * (deltaLatRad / 2).sin() +
        lat1Rad.cos() * lat2Rad.cos() *
        (deltaLngRad / 2).sin() * (deltaLngRad / 2).sin();
    final double c = 2 * (a.sqrt()).asin();
    
    return earthRadius * c;
  }
  
  /// Calculate the center point of a polygon
  /// 
  /// Parameters:
  /// - [polygon]: The polygon vertices (List<LatLng>)
  /// 
  /// Returns:
  /// - The center point (LatLng)
  static LatLng getPolygonCenter(List<LatLng> polygon) {
    if (polygon.isEmpty) {
      throw ArgumentError('Polygon cannot be empty');
    }
    
    double lat = 0, lng = 0;
    for (final point in polygon) {
      lat += point.latitude;
      lng += point.longitude;
    }
    
    return LatLng(lat / polygon.length, lng / polygon.length);
  }
  
  /// Check if a polygon is valid (has at least 3 points)
  /// 
  /// Parameters:
  /// - [polygon]: The polygon vertices (List<LatLng>)
  /// 
  /// Returns:
  /// - true if polygon is valid, false otherwise
  static bool isValidPolygon(List<LatLng> polygon) {
    return polygon.length >= 3;
  }
  
  /// Find the closest point on a polygon to a given point
  /// 
  /// Parameters:
  /// - [point]: The reference point (LatLng)
  /// - [polygon]: The polygon vertices (List<LatLng>)
  /// 
  /// Returns:
  /// - The closest point on the polygon (LatLng)
  static LatLng findClosestPointOnPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) {
      throw ArgumentError('Polygon cannot be empty');
    }
    
    LatLng closestPoint = polygon[0];
    double minDistance = calculateDistance(point, closestPoint);
    
    for (final polygonPoint in polygon) {
      final distance = calculateDistance(point, polygonPoint);
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = polygonPoint;
      }
    }
    
    return closestPoint;
  }
}

// Extension for math functions
extension MathExtensions on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double asin() => math.asin(this);
  double sqrt() => math.sqrt(this);
}
