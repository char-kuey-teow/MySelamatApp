import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'config.dart';
import 'report.dart';
import 'services/cache_service.dart';
import 'services/geometry_service.dart';

// --- 1. CONFIGURATION CONSTANTS (from map.js) ---
const bool USE_MOCKS = false;
const String API_BASE = "http://localhost:3001"; // For real backend API access
const String MOCK_PATH =
    "http://localhost:8080/mocks"; // Assuming mock files are served
const String CLOUDFRONT_BASE = "https://d2m06s680fwyuz.cloudfront.net";
// Updated to use new API endpoint
const String FLOOD_LOCATIONS_API = "https://sbb646ua7a.execute-api.us-east-1.amazonaws.com/testing/floodLocations";
const String SAFE_ZONES_LOCATIONS_API = "https://w1q8jucej0.execute-api.us-east-1.amazonaws.com/testing/safe-zones-locations";
const LatLng DEFAULT_CENTER = LatLng(6.129, 102.243); // Kota Bharu
const bool USE_FAKE_USER_LOC = false;


// API key is now loaded from config.dart (gitignored file)
const String GOOGLE_API_KEY = Config.googleApiKey;
const String ROUTES_BASE = "https://routes.googleapis.com";

// --- 2. DATA MODELS ---

class SafeZone {
  final String name;
  final String type; // hospital, police, fire_department, school, stadium
  final LatLng location;
  
  SafeZone({
    required this.name, 
    required this.type,
    required this.location,
  });
}

enum RouteSafetyLevel {
  safe,      // No flood zones
  moderate,  // Low flood risk
  risky,     // High flood risk
}

enum RouteScenario {
  userInFloodZone,      // User inside flood → ESCAPE priority
  routeIntersectsFlood, // Route crosses flood → AVOID priority  
  safeDirectRoute,      // No flood issues → SPEED priority
}

class RouteOption {
  final String name;
  final int duration; // minutes
  final double distance; // km
  final RouteSafetyLevel safetyLevel;
  final List<LatLng> waypoints;
  final String instructions;
  final String summary;

  RouteOption({
    required this.name,
    required this.duration,
    required this.distance,
    required this.safetyLevel,
    required this.waypoints,
    required this.instructions,
    required this.summary,
  });

  RouteOption copyWith({
    String? name,
    int? duration,
    double? distance,
    RouteSafetyLevel? safetyLevel,
    List<LatLng>? waypoints,
    String? instructions,
    String? summary,
  }) {
    return RouteOption(
      name: name ?? this.name,
      duration: duration ?? this.duration,
      distance: distance ?? this.distance,
      safetyLevel: safetyLevel ?? this.safetyLevel,
      waypoints: waypoints ?? this.waypoints,
      instructions: instructions ?? this.instructions,
      summary: summary ?? this.summary,
    );
  }
}

class FloodRiskInfo {
  final String districtId;
  final String level;
  final List<String> reasons;
  final List<List<LatLng>> polygons;
  final String name;
  final String state;
  final String district;
  final bool isFlood;
  final int reportCount;
  final double? latestTimestamp;
  final Map<String, double>? coordinates;
  final List<Map<String, double>>? decagonCoordinates;

  FloodRiskInfo({
    required this.districtId,
    required this.level,
    required this.reasons,
    required this.polygons,
    required this.name,
    required this.state,
    required this.district,
    required this.isFlood,
    required this.reportCount,
    this.latestTimestamp,
    this.coordinates,
    this.decagonCoordinates,
  });
}

// --- 3. THE MAIN WIDGET ---

class FloodMapWidget extends StatefulWidget {
  const FloodMapWidget({super.key});

  @override
  State<FloodMapWidget> createState() => _FloodMapWidgetState();
}

class _FloodMapWidgetState extends State<FloodMapWidget> {
  // State Variables
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<FloodRiskInfo> _floodRiskInfoList = [];
  BitmapDescriptor? _userLocationIcon;

  // UI State for Advice/ETA Panels
  String _currentLevel = "GREEN";
  String _adviceMessage = "🟢 Low risk. Stay alert for updates.";
  String _etaSummary = "Tap a safe zone and press 'Safe Route'.";
  String _lastUpdated = "Loading...";
  
  // Custom info popup state
  SafeZone? _selectedSafeZone;
  
  // Scroll controller for risk panel
  final ScrollController _riskPanelScrollController = ScrollController();
  double _scrollPosition = 0.0;
  
  // Dynamic marker filtering
  List<SafeZone> _allSafeZones = []; // Store all safe zones from API
  LatLng? _currentMapCenter; // Track current map center
  
  // Periodic refresh timer
  Timer? _floodDataRefreshTimer;

  // --- 4. LIFECYCLE AND INITIALIZATION ---

  // Load custom user location icon with resizing (optimized for performance)
  Future<void> _loadUserLocationIcon() async {
    try {
      debugPrint('Loading user location icon from assets/icons/blue_ping.png');
      final ByteData data = await rootBundle.load('assets/icons/blue_ping.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Use compute to run image processing in isolate (off main thread)
      final Uint8List? resizedBytes = await compute(_processImageInIsolate, bytes);
      
      if (resizedBytes != null) {
        _userLocationIcon = BitmapDescriptor.fromBytes(resizedBytes);
        debugPrint('User location icon loaded and resized to 60x60 pixels');
      } else {
        throw Exception('Failed to process image');
      }
    } catch (e) {
      debugPrint('Failed to load user location icon: $e');
      // Fallback to default marker
      _userLocationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      debugPrint('Using fallback blue marker');
    }
  }

  // Static function to process image in isolate (runs off main thread)
  static Uint8List? _processImageInIsolate(Uint8List bytes) {
    try {
      // Resize the image to desired marker size
      final img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage != null) {
        // Resize to 60x60 pixels (adjust these values to change marker size)
        final img.Image resizedImage = img.copyResize(originalImage, width: 60, height: 60);
        return Uint8List.fromList(img.encodePng(resizedImage));
      }
    } catch (e) {
      debugPrint('Error processing image in isolate: $e');
    }
    return null;
  }

  // Add user location marker to the map
  void _addUserLocationMarker(LatLng userLocation) {
    debugPrint('Adding user location marker at: ${userLocation.latitude}, ${userLocation.longitude}');
    debugPrint('User location icon loaded: ${_userLocationIcon != null}');
    
    if (_userLocationIcon != null) {
      final userMarker = Marker(
        markerId: const MarkerId('user_location'),
        position: userLocation,
        icon: _userLocationIcon!,
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Current position',
        ),
      );
      
      setState(() {
        _markers.add(userMarker);
        debugPrint('User location marker added. Total markers: ${_markers.length}');
      });
    } else {
      debugPrint('User location icon is null, cannot add marker');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _riskPanelScrollController.dispose();
    _floodDataRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _loadUserLocationIcon();
    await _initMap();
  }

  // Equivalent to JS 'initMap' function
  Future<void> _initMap() async {
    final userLoc = await _getUserLocation();
    
    // 🔍 INVESTIGATION: Check user location
    debugPrint('🔍 INVESTIGATION - User Location Analysis:');
    debugPrint('📍 User coordinates: ${userLoc.latitude}, ${userLoc.longitude}');
    debugPrint('📍 User region: ${_getRegionFromCoordinates(userLoc)}');
    
    setState(() {
      _userLocation = userLoc;
      _lastUpdated = 'Last updated: ${DateTime.now().toString()}';
    });

    // Add user location marker immediately
    _addUserLocationMarker(userLoc);
    debugPrint('🚀 Starting optimized loading with cache...');

    try {
      // Check cache first for flood data only
      final cachedFloodData = await CacheService.getCachedFloodData();
      
      List<SafeZone> safeZones = [];
      dynamic latestData = cachedFloodData;
      
      // Use cached flood data if available, but always load safe zones fresh
      if (cachedFloodData != null) {
        debugPrint('✅ Using cached flood data for immediate display');
        
        // Show cached flood data immediately
        final friData = _parseFri(cachedFloodData);
        _floodRiskInfoList = friData;
        
        // Load safe zones fresh from API
        debugPrint('🔄 Loading safe zones fresh from API...');
        safeZones = await _getSafeZonesData();
        
        // Update UI with cached flood data and fresh safe zones
        await Future.wait([
          Future(() => _drawFRI(friData)),
          Future(() {
            _allSafeZones = safeZones;
            _currentMapCenter = userLoc;
            _updateVisibleSafeZones(userLoc);
          }),
          Future(() => _assessUserRisk(userLoc, friData)),
          Future(() => _setMapZoom(userLoc)),
        ]);
        
        debugPrint('✅ Cached flood data + fresh safe zones loaded - ${safeZones.length} safe zones displayed');
        
        // Start periodic refresh timer (every 10 minutes)
        _startPeriodicFloodDataRefresh();
      } else {
        debugPrint('🔄 No cache available, loading from API...');
        
        // Load both APIs in parallel for faster loading
        final futures = await Future.wait([
          _getLatestFloodData(),
          _getSafeZonesData(),
        ]);
        
        latestData = futures[0];
        safeZones = futures[1] as List<SafeZone>;
        
        if (latestData != null) {
          // Parse flood data
          final friData = _parseFri(latestData);
          _floodRiskInfoList = friData;
          
          // Update UI components in parallel
          await Future.wait([
            Future(() => _drawFRI(friData)),
            Future(() {
              _allSafeZones = safeZones;
              _currentMapCenter = userLoc;
              _updateVisibleSafeZones(userLoc);
            }),
            Future(() => _assessUserRisk(userLoc, friData)),
            Future(() => _setMapZoom(userLoc)),
          ]);
          
          debugPrint('✅ API loading completed - ${safeZones.length} safe zones loaded');
          
          // Start periodic refresh timer (every 10 minutes)
          _startPeriodicFloodDataRefresh();
        } else {
          throw Exception('Failed to get latest flood data from API');
        }
      }
    } catch (e) {
      debugPrint('Map initialization error: $e');
      _setAdviceFor("RED", ["Data loading failed"], "Error");
    }
  }

  // --- 5. ROUTE OPTIMIZATION SERVICE ---

  /// Analyze the route scenario to determine the best routing strategy
  RouteScenario _analyzeRouteScenario(LatLng userLocation, LatLng destination) {
    debugPrint('🔍 Analyzing route scenario...');
    
    // Check if user is inside any flood zone
    final userFloodZones = _getUserFloodZones(userLocation, _floodRiskInfoList);
    if (userFloodZones.isNotEmpty) {
      debugPrint('🚨 SCENARIO: User is INSIDE ${userFloodZones.length} flood zone(s) - ESCAPE priority');
      return RouteScenario.userInFloodZone;
    }
    
    // Check if direct route would intersect flood zones
    final directRoute = _calculateDirectRoute(userLocation, destination);
    final intersectingFloods = _getIntersectingFloodZones(directRoute);
    if (intersectingFloods.isNotEmpty) {
      debugPrint('⚠️ SCENARIO: Route intersects ${intersectingFloods.length} flood zone(s) - AVOID priority');
      return RouteScenario.routeIntersectsFlood;
    }
    
    debugPrint('✅ SCENARIO: Safe direct route - SPEED priority');
    return RouteScenario.safeDirectRoute;
  }

  /// Calculate a simple direct route for intersection analysis
  List<LatLng> _calculateDirectRoute(LatLng origin, LatLng destination) {
    // Create a simple direct line between origin and destination
    // This is a simplified approach - in production, you might want to use actual road network
    final points = <LatLng>[];
    final steps = 10; // Number of intermediate points
    
    for (int i = 0; i <= steps; i++) {
      final ratio = i / steps;
      final lat = origin.latitude + (destination.latitude - origin.latitude) * ratio;
      final lng = origin.longitude + (destination.longitude - origin.longitude) * ratio;
      points.add(LatLng(lat, lng));
    }
    
    return points;
  }

  /// Find flood zones that intersect with a given route
  List<FloodRiskInfo> _getIntersectingFloodZones(List<LatLng> routePoints) {
    final intersectingFloods = <FloodRiskInfo>[];
    
    for (var floodZone in _floodRiskInfoList) {
      for (var routePoint in routePoints) {
        if (_isPointInFloodZone(routePoint, floodZone)) {
          intersectingFloods.add(floodZone);
          break; // Found intersection, no need to check more points for this zone
        }
      }
    }
    
    return intersectingFloods;
  }

  /// Get optimized routes to a safe zone
  Future<List<RouteOption>> _getOptimizedRoutes(LatLng origin, LatLng destination) async {
    try {
      debugPrint('🗺️ Getting optimized routes from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}');
      
      // Analyze the scenario first
      final scenario = _analyzeRouteScenario(origin, destination);
      
      // Get multiple route options in parallel
      final futures = await Future.wait([
        _getFastestRoute(origin, destination),
        _getSafestRoute(origin, destination),
        _getBalancedRoute(origin, destination),
      ]);
      
      debugPrint('🔍 Route futures completed: ${futures.length}');
      for (int i = 0; i < futures.length; i++) {
        debugPrint('🔍 Route ${i + 1}: ${futures[i] != null ? "SUCCESS" : "FAILED"}');
      }
      
      final routes = futures.where((route) => route != null).cast<RouteOption>().toList();
      debugPrint('✅ Generated ${routes.length} route options');
      
      // Remove duplicate routes to minimize redundancy
      final uniqueRoutes = _removeDuplicateRoutes(routes);
      debugPrint('🔄 After deduplication: ${uniqueRoutes.length} unique routes');
      
      // Apply scenario-based naming
      final scenarioRoutes = _applyScenarioNaming(uniqueRoutes, scenario);
      
      if (scenarioRoutes.isEmpty) {
        debugPrint('❌ No routes generated! Check Google API key and coordinates.');
        
        // Create a simple fallback route
        final fallbackRoute = RouteOption(
          name: _getFallbackRouteName(scenario),
          duration: 15,
          distance: _calculateDistance(origin, destination),
          safetyLevel: RouteSafetyLevel.moderate,
          waypoints: [origin, destination],
          instructions: 'Direct route to destination',
          summary: '15min • ${_calculateDistance(origin, destination).toStringAsFixed(1)}km',
        );
        
        debugPrint('🔄 Using fallback route');
        return [fallbackRoute];
      }
      
      return scenarioRoutes;
    } catch (e) {
      debugPrint('❌ Error getting optimized routes: $e');
      return [];
    }
  }

  /// Remove duplicate routes to minimize redundancy
  List<RouteOption> _removeDuplicateRoutes(List<RouteOption> routes) {
    if (routes.length <= 1) return routes;
    
    final uniqueRoutes = <RouteOption>[];
    
    for (var route in routes) {
      // Check if this route is a duplicate of any existing route
      bool isDuplicate = false;
      
      for (var existingRoute in uniqueRoutes) {
        if (_areRoutesIdentical(route, existingRoute)) {
          debugPrint('🔄 Removing duplicate route: ${route.name} (identical to ${existingRoute.name})');
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        uniqueRoutes.add(route);
      }
    }
    
    return uniqueRoutes;
  }

  /// Check if two routes are identical based on key characteristics
  bool _areRoutesIdentical(RouteOption route1, RouteOption route2) {
    // Compare key route characteristics
    final durationDiff = (route1.duration - route2.duration).abs();
    final distanceDiff = (route1.distance - route2.distance).abs();
    
    // Routes are considered identical if:
    // 1. Duration difference is less than 1 minute
    // 2. Distance difference is less than 0.1 km
    // 3. Same number of waypoints (within 10% tolerance)
    final waypointCountDiff = (route1.waypoints.length - route2.waypoints.length).abs();
    final waypointTolerance = (route1.waypoints.length * 0.1).round();
    
    final isIdentical = durationDiff < 1 && 
                       distanceDiff < 0.1 && 
                       waypointCountDiff <= waypointTolerance;
    
    if (isIdentical) {
      debugPrint('🔄 Routes are identical: ${route1.name} vs ${route2.name}');
      debugPrint('   Duration: ${route1.duration}min vs ${route2.duration}min (diff: ${durationDiff}min)');
      debugPrint('   Distance: ${route1.distance.toStringAsFixed(2)}km vs ${route2.distance.toStringAsFixed(2)}km (diff: ${distanceDiff.toStringAsFixed(2)}km)');
      debugPrint('   Waypoints: ${route1.waypoints.length} vs ${route2.waypoints.length} (diff: $waypointCountDiff)');
    }
    
    return isIdentical;
  }

  /// Apply scenario-based naming to routes
  List<RouteOption> _applyScenarioNaming(List<RouteOption> routes, RouteScenario scenario) {
    return routes.asMap().entries.map((entry) {
      final index = entry.key;
      final route = entry.value;
      
      final newName = _getScenarioRouteName(scenario, index);
      
      return route.copyWith(name: newName);
    }).toList();
  }

  /// Get route name based on scenario and index
  String _getScenarioRouteName(RouteScenario scenario, int index) {
    switch (scenario) {
      case RouteScenario.userInFloodZone:
        final names = ['🚨 Escape Route', '🛡️ Safe Escape', '⚡ Fast Escape'];
        return index < names.length ? names[index] : '🚨 Escape Route ${index + 1}';
        
      case RouteScenario.routeIntersectsFlood:
        final names = ['🛡️ Safest Route', '⚖️ Balanced Route', '🚀 Fastest Route'];
        return index < names.length ? names[index] : '🛡️ Safe Route ${index + 1}';
        
      case RouteScenario.safeDirectRoute:
        final names = ['🚀 Fastest Route', '⚖️ Alternative Route', '🛡️ Scenic Route'];
        return index < names.length ? names[index] : '🚀 Route ${index + 1}';
    }
  }

  /// Get fallback route name based on scenario
  String _getFallbackRouteName(RouteScenario scenario) {
    switch (scenario) {
      case RouteScenario.userInFloodZone:
        return '🚨 Emergency Route';
        
      case RouteScenario.routeIntersectsFlood:
        return '🛡️ Safe Route';
        
      case RouteScenario.safeDirectRoute:
        return '🚀 Direct Route';
    }
  }

  /// Get the fastest route (ignoring flood zones)
  Future<RouteOption?> _getFastestRoute(LatLng origin, LatLng destination) async {
    try {
      final url = _buildDirectionsUrl(origin, destination, avoidFloodZones: false);
      debugPrint('🚀 Fastest route URL: $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('🚀 Fastest route response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🚀 Fastest route data: ${data.toString()}');
        return _parseRouteFromDirections(data, 'Fastest Route');
      } else {
        debugPrint('🚀 Fastest route error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error getting fastest route: $e');
    }
    return null;
  }

  /// Get the safest route (avoiding flood zones)
  Future<RouteOption?> _getSafestRoute(LatLng origin, LatLng destination) async {
    try {
      final url = _buildSmartDirectionsUrl(origin, destination, avoidFloodZones: true);
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = _parseRouteFromDirections(data, 'Safest Route');
        return route?.copyWith(safetyLevel: RouteSafetyLevel.safe);
      }
    } catch (e) {
      debugPrint('❌ Error getting safest route: $e');
    }
    return null;
  }

  /// Get a balanced route (considering both speed and safety)
  Future<RouteOption?> _getBalancedRoute(LatLng origin, LatLng destination) async {
    try {
      // Get fastest route first
      final fastest = await _getFastestRoute(origin, destination);
      
      if (fastest != null) {
        // Calculate safety score for the fastest route
        final safetyScore = _calculateRouteSafetyScore(fastest.waypoints);
        final safetyLevel = _getSafetyLevelFromScore(safetyScore);
        
        debugPrint('⚖️ Balanced route safety score: ${safetyScore.toStringAsFixed(1)}%');
        
        return fastest.copyWith(
          name: 'Balanced Route',
          safetyLevel: safetyLevel,
        );
      }
      
      // If fastest route fails, try to get safest route
      final safest = await _getSafestRoute(origin, destination);
      return safest;
    } catch (e) {
      debugPrint('❌ Error getting balanced route: $e');
    }
    return null;
  }

  /// Build Google Directions API URL with smart waypoints
  String _buildSmartDirectionsUrl(LatLng origin, LatLng destination, {bool avoidFloodZones = false}) {
    final originStr = '${origin.latitude},${origin.longitude}';
    final destStr = '${destination.latitude},${destination.longitude}';
    
    debugPrint('🔑 Using Google API Key: ${GOOGLE_API_KEY.substring(0, 10)}...');
    
    var url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$originStr&'
        'destination=$destStr&'
        'alternatives=true&'
        'key=$GOOGLE_API_KEY';
    
    if (avoidFloodZones) {
      // Add smart waypoints based on scenario
      final smartWaypoints = _getSmartWaypoints(origin, destination);
      if (smartWaypoints.isNotEmpty) {
        url += '&waypoints=optimize:true|${smartWaypoints.join('|')}';
        debugPrint('🎯 Added ${smartWaypoints.length} smart waypoints to URL');
      } else {
        debugPrint('✅ No waypoints needed for this route scenario');
      }
    }
    
    debugPrint('🌐 Built Smart URL: $url');
    return url;
  }

  /// Legacy function - redirects to smart URL builder
  String _buildDirectionsUrl(LatLng origin, LatLng destination, {bool avoidFloodZones = false}) {
    return _buildSmartDirectionsUrl(origin, destination, avoidFloodZones: avoidFloodZones);
  }

  /// Get smart waypoints based on route scenario
  List<String> _getSmartWaypoints(LatLng origin, LatLng destination) {
    final scenario = _analyzeRouteScenario(origin, destination);
    final waypoints = <String>[];
    
    switch (scenario) {
      case RouteScenario.userInFloodZone:
        // ESCAPE: Add waypoints to exit flood zones first
        waypoints.addAll(_getEscapeWaypoints(origin, destination));
        break;
        
      case RouteScenario.routeIntersectsFlood:
        // AVOID: Add waypoints to avoid flood intersections
        waypoints.addAll(_getAvoidanceWaypoints(origin, destination));
        break;
        
      case RouteScenario.safeDirectRoute:
        // DIRECT: No waypoints needed
        debugPrint('✅ Safe direct route - no waypoints needed');
        break;
    }
    
    debugPrint('🎯 Smart waypoints generated: ${waypoints.length} waypoints');
    return waypoints;
  }

  /// Get escape waypoints for users inside flood zones
  List<String> _getEscapeWaypoints(LatLng userLocation, LatLng destination) {
    final waypoints = <String>[];
    final userFloodZones = _getUserFloodZones(userLocation, _floodRiskInfoList);
    
    for (var floodZone in userFloodZones) {
      // Find the closest exit point from this flood zone
      final exitPoint = _findClosestExitPoint(floodZone, userLocation, destination);
      waypoints.add('${exitPoint.latitude},${exitPoint.longitude}');
      
      debugPrint('🚨 ESCAPE: User in flood zone ${floodZone.districtId}, adding exit waypoint at ${exitPoint.latitude},${exitPoint.longitude}');
    }
    
    return waypoints;
  }

  /// Get avoidance waypoints for routes intersecting flood zones
  List<String> _getAvoidanceWaypoints(LatLng origin, LatLng destination) {
    final waypoints = <String>[];
    final directRoute = _calculateDirectRoute(origin, destination);
    final intersectingFloods = _getIntersectingFloodZones(directRoute);
    
    for (var floodZone in intersectingFloods) {
      // Find waypoint to go around this flood zone
      final avoidancePoint = _findAvoidancePoint(floodZone, origin, destination);
      waypoints.add('${avoidancePoint.latitude},${avoidancePoint.longitude}');
      
      debugPrint('⚠️ AVOID: Route intersects flood zone ${floodZone.districtId}, adding avoidance waypoint at ${avoidancePoint.latitude},${avoidancePoint.longitude}');
    }
    
    return waypoints;
  }

  /// Find the closest exit point from a flood zone
  LatLng _findClosestExitPoint(FloodRiskInfo floodZone, LatLng userLocation, LatLng destination) {
    // For now, use a simple approach: find the edge point closest to destination
    // In production, you'd want more sophisticated flood zone boundary analysis
    
    if (floodZone.polygons.isEmpty) {
      // Fallback: add offset from flood zone center
      return LatLng(userLocation.latitude + 0.01, userLocation.longitude + 0.01);
    }
    
    // Find the polygon edge point closest to destination
    final polygon = floodZone.polygons.first;
    LatLng closestExit = polygon[0];
    double minDistance = _calculateDistance(destination, closestExit);
    
    for (var point in polygon) {
      final distance = _calculateDistance(destination, point);
      if (distance < minDistance) {
        minDistance = distance;
        closestExit = point;
      }
    }
    
    // Add small offset to ensure we're outside the flood zone
    final offsetLat = closestExit.latitude + (destination.latitude > closestExit.latitude ? 0.005 : -0.005);
    final offsetLng = closestExit.longitude + (destination.longitude > closestExit.longitude ? 0.005 : -0.005);
    
    return LatLng(offsetLat, offsetLng);
  }

  /// Find avoidance point to go around a flood zone
  LatLng _findAvoidancePoint(FloodRiskInfo floodZone, LatLng origin, LatLng destination) {
    // Simple approach: find a point that's around the flood zone
    // In production, you'd want more sophisticated pathfinding
    
    if (floodZone.polygons.isEmpty) {
      // Fallback: use origin with offset
      return LatLng(origin.latitude + 0.01, origin.longitude + 0.01);
    }
    
    // Find the center of the flood zone
    final center = _getPolygonCenter(floodZone.polygons.first);
    
    // Calculate perpendicular offset from the direct route
    final directVector = LatLng(
      destination.latitude - origin.latitude,
      destination.longitude - origin.longitude,
    );
    
    // Add perpendicular offset (simple 90-degree rotation)
    final avoidancePoint = LatLng(
      center.latitude + directVector.longitude * 0.01, // Perpendicular offset
      center.longitude - directVector.latitude * 0.01,
    );
    
    return avoidancePoint;
  }


  /// Parse route from Google Directions API response
  RouteOption? _parseRouteFromDirections(Map<String, dynamic> data, String routeName) {
    try {
      debugPrint('🔍 Parsing route data: ${data.toString()}');
      
      if (data['status'] == 'OK' && data['routes'] != null && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final legs = route['legs'] as List;
        
        debugPrint('🔍 Route has ${legs.length} legs');
        
        if (legs.isNotEmpty) {
          final leg = legs[0];
          final duration = (leg['duration']['value'] as int) ~/ 60; // Convert to minutes
          final distance = (leg['distance']['value'] as int) / 1000; // Convert to km
          
          debugPrint('🔍 Route duration: $duration min, distance: $distance km');
          
          // Extract waypoints from polyline
          final polyline = route['overview_polyline']['points'] as String;
          debugPrint('🔍 Polyline: $polyline');
          final waypoints = _decodePolyline(polyline);
          debugPrint('🔍 Decoded ${waypoints.length} waypoints');
          
          // Generate instructions
          final steps = leg['steps'] as List;
          final instructions = steps.take(3).map((step) => step['html_instructions'] as String).join(' → ');
          
          debugPrint('✅ Successfully parsed route: $routeName');
          
          return RouteOption(
            name: routeName,
            duration: duration,
            distance: distance,
            safetyLevel: RouteSafetyLevel.moderate, // Default, will be updated
            waypoints: waypoints,
            instructions: instructions,
            summary: '${duration}min • ${distance.toStringAsFixed(1)}km',
          );
        }
      } else {
        debugPrint('❌ Route parsing failed - Status: ${data['status']}, Routes: ${data['routes']}');
        if (data['error_message'] != null) {
          debugPrint('❌ Error message: ${data['error_message']}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error parsing route: $e');
    }
    return null;
  }

  /// Calculate route safety score based on flood zone intersections
  double _calculateRouteSafetyScore(List<LatLng> waypoints) {
    if (_floodRiskInfoList.isEmpty) return 100.0; // No flood zones = 100% safe
    
    int intersectionCount = 0;
    
    for (var waypoint in waypoints) {
      for (var floodZone in _floodRiskInfoList) {
        if (_isPointInFloodZone(waypoint, floodZone)) {
          intersectionCount++;
          break; // Count each waypoint only once
        }
      }
    }
    
    final safetyScore = 100.0 - ((intersectionCount / waypoints.length) * 100.0);
    return safetyScore.clamp(0.0, 100.0);
  }

  /// Get safety level from score
  RouteSafetyLevel _getSafetyLevelFromScore(double score) {
    if (score >= 80) return RouteSafetyLevel.safe;
    if (score >= 50) return RouteSafetyLevel.moderate;
    return RouteSafetyLevel.risky;
  }

  /// Check if point is in any flood zone
  bool _isPointInFloodZone(LatLng point, FloodRiskInfo floodZone) {
    return GeometryService.isPointInAnyPolygon(point, floodZone.polygons);
  }

  /// Get center of polygon
  LatLng _getPolygonCenter(List<LatLng> polygon) {
    return GeometryService.getPolygonCenter(polygon);
  }

  /// Decode Google polyline string to LatLng points
  List<LatLng> _decodePolyline(String polyline) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;
    
    while (index < polyline.length) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      
      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    
    return points;
  }

  // --- 6. DATA FETCHING AND PARSING ---

  /// Helper function to identify region from coordinates
  String _getRegionFromCoordinates(LatLng coords) {
    final lat = coords.latitude;
    final lng = coords.longitude;
    
    // Kota Bharu, Kelantan: ~6.1°N, 102.2°E
    if (lat >= 5.8 && lat <= 6.4 && lng >= 101.8 && lng <= 102.6) {
      return 'Kota Bharu, Kelantan';
    }
    // Kuala Lumpur/Selangor: ~3.1°N, 101.7°E
    else if (lat >= 2.8 && lat <= 3.4 && lng >= 101.2 && lng <= 102.0) {
      return 'Kuala Lumpur/Selangor';
    }
    // Penang: ~5.4°N, 100.3°E
    else if (lat >= 5.2 && lat <= 5.6 && lng >= 100.1 && lng <= 100.5) {
      return 'Penang';
    }
    // Johor: ~1.5°N, 103.8°E
    else if (lat >= 1.2 && lat <= 2.8 && lng >= 103.0 && lng <= 104.5) {
      return 'Johor';
    }
    else {
      return 'Unknown region (${lat.toStringAsFixed(2)}°N, ${lng.toStringAsFixed(2)}°E)';
    }
  }

  /// Load safe zones data (always fresh, no caching)
  Future<List<SafeZone>> _getSafeZonesData() async {
    try {
      debugPrint('🔄 Loading safe zones fresh from API...');
      final response = await http.get(Uri.parse(SAFE_ZONES_LOCATIONS_API));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final safeZones = _parseSafeZonesLocations(data);
          debugPrint('✅ Safe zones loaded: ${safeZones.length} locations');
          
          // No caching - always fresh data
          
          return safeZones;
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Safe zones API failed: $e');
      return []; // Empty list - no fallback
    }
  }

  /// Set map zoom (extracted for parallel execution)
  Future<void> _setMapZoom(LatLng userLoc) async {
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: userLoc,
            zoom: 13.0,
          ),
        ),
      );
      debugPrint('🗺️ Map zoomed to 3km radius');
    }
  }

  /// Start periodic refresh timer for flood data (every 10 minutes)
  void _startPeriodicFloodDataRefresh() {
    _floodDataRefreshTimer?.cancel(); // Cancel existing timer
    
    _floodDataRefreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      debugPrint('⏰ 10-minute timer triggered - refreshing flood data...');
      _refreshFloodDataInBackground();
    });
    
    debugPrint('✅ Periodic flood data refresh started (every 10 minutes)');
  }

  /// Refresh flood data in background (every 10 minutes)
  Future<void> _refreshFloodDataInBackground() async {
    try {
      debugPrint('🔄 Refreshing flood data in background (10-minute update)...');
      
      // Only refresh flood data, safe zones can stay cached longer
      final freshFloodData = await _getLatestFloodData();
      
      if (freshFloodData != null) {
        // Update UI with fresh flood data
        final friData = _parseFri(freshFloodData);
        _floodRiskInfoList = friData;
        
        // Redraw flood zones with fresh data
        _drawFRI(friData);
        
        // Reassess user risk with fresh data
        if (_userLocation != null) {
          _assessUserRisk(_userLocation!, friData);
        }
        
        // Update last updated timestamp
        setState(() {
          _lastUpdated = 'Last updated: ${DateTime.now().toString()}';
        });
        
        debugPrint('✅ Background flood data refresh completed - UI updated');
      }
    } catch (e) {
      debugPrint('❌ Background flood data refresh failed: $e');
      // Don't show error to user since we have cached data
    }
  }


  // Get latest flood data from new API
  Future<dynamic> _getLatestFloodData() async {
    try {
      debugPrint('🔄 Loading flood data from API...');
      final response = await http.get(Uri.parse(FLOOD_LOCATIONS_API));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final locationsData = data['data'];
          debugPrint('✅ Flood data loaded: ${locationsData.length} locations');
          
          // Cache the full API response for future use
          await CacheService.cacheFloodData(data);
          
          // 🔍 INVESTIGATION: Check what locations we're getting
          debugPrint('🔍 INVESTIGATION - Flood API Response Analysis:');
          for (int i = 0; i < locationsData.length && i < 3; i++) {
            final location = locationsData[i];
            debugPrint('📍 Location ${i + 1}:');
            debugPrint('   ID: ${location['id']}');
            debugPrint('   Name: ${location['name']}');
            debugPrint('   Severity: ${location['severity']}');
            debugPrint('   Coordinates: ${location['coordinates']}');
            debugPrint('   Decagon points: ${location['decagonCoordinates']?.length ?? 0}');
          }
          
          return locationsData;
        }
      }
      
      debugPrint('❌ Flood API failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Flood API error: $e');
    }
    
    return null;
  }

  List<FloodRiskInfo> _parseFri(dynamic data) {
    final List<FloodRiskInfo> floodRiskInfoList = [];
    
    // Handle both API response format and cached format
    List<dynamic> locationsData;
    if (data is List) {
      // Direct list format (from API call)
      debugPrint('🔍 INVESTIGATION - Parsing Flood Data (Direct List):');
      locationsData = data;
    } else if (data is Map && data['success'] == true && data['data'] != null) {
      // API response format (from cache)
      debugPrint('🔍 INVESTIGATION - Parsing Flood Data (Cached API Response):');
      locationsData = data['data'] as List<dynamic>;
    } else {
      debugPrint('❌ Invalid flood data format: ${data.runtimeType}');
      return floodRiskInfoList;
    }
    
    debugPrint('📊 Processing ${locationsData.length} flood locations');
    
    if (locationsData.isNotEmpty) {
      for (int i = 0; i < locationsData.length; i++) {
        var location = locationsData[i];
        if (location is Map<String, dynamic>) {
          // Handle decagon coordinates from new API
          List<LatLng> decagonPolygon = [];

          try {
            if (location['decagonCoordinates'] != null && location['decagonCoordinates'] is List) {
              final decagonData = location['decagonCoordinates'] as List<dynamic>;
              if (decagonData.isNotEmpty) {
                // New API returns decagon coordinates as [{"latitude": x, "longitude": y}, ...]
                decagonPolygon = decagonData
                    .map((point) {
                      if (point is Map<String, dynamic>) {
                        final lat = (point['latitude'] as num).toDouble();
                        final lng = (point['longitude'] as num).toDouble();
                        return LatLng(lat, lng);
                      }
                      debugPrint('⚠️ Invalid decagon point format: $point');
                      return null;
                    })
                    .where((point) => point != null)
                    .cast<LatLng>()
                    .toList();
                
                // 🔍 INVESTIGATION: Debug parsed decagon coordinates
                if (decagonPolygon.isNotEmpty) {
                  debugPrint('🔍 Location ${i + 1} - Decagon data:');
                  debugPrint('   Location ID: ${location['id']}');
                  debugPrint('   Decagon points: ${decagonPolygon.length}');
                  debugPrint('   First point: ${decagonPolygon.first.latitude}, ${decagonPolygon.first.longitude}');
                  debugPrint('   Last point: ${decagonPolygon.last.latitude}, ${decagonPolygon.last.longitude}');
                }
              }
            }
          } catch (e) {
            debugPrint('❌ Error parsing decagon for location ${location['id']}: $e');
          }

          debugPrint('🔍 Parsing location: ${location['id']}');
          debugPrint('   Decagon points: ${decagonPolygon.length}');
          if (decagonPolygon.isNotEmpty) {
            debugPrint('   First point: ${decagonPolygon[0].latitude.toStringAsFixed(4)}, ${decagonPolygon[0].longitude.toStringAsFixed(4)}');
          }

          // Convert severity to uppercase for consistency
          final severity = (location['severity'] as String).toUpperCase();
          
          floodRiskInfoList.add(
            FloodRiskInfo(
              districtId: location['id'] as String,
              level: severity,
              reasons: [location['isFlood'] == true ? 'Flood detected' : 'No flood detected'],
              polygons: [decagonPolygon],
              name: location['name'] as String,
              state: location['state'] as String,
              district: location['district'] as String,
              isFlood: location['isFlood'] as bool,
              reportCount: location['reportCount'] as int,
              latestTimestamp: (location['latestTimestamp'] as num?)?.toDouble(),
              coordinates: location['coordinates'] != null 
                  ? Map<String, double>.from(location['coordinates'])
                  : null,
              decagonCoordinates: location['decagonCoordinates'] != null
                  ? (location['decagonCoordinates'] as List)
                      .map((coord) => Map<String, double>.from(coord))
                      .toList()
                  : null,
            ),
          );
        }
      }
    }
    return floodRiskInfoList;
  }

  /// Parse safe zones locations from API response
  List<SafeZone> _parseSafeZonesLocations(dynamic data) {
    debugPrint('🔍 PARSING SAFE ZONES LOCATIONS:');
    debugPrint('   Data type: ${data.runtimeType}');
    debugPrint('   Data null? ${data == null}');
    
    if (data == null) {
      debugPrint('   ❌ Data is null');
      return [];
    }
    
    // Handle API response format: {success: true, data: {locations: [...]}}
    if (data is Map && data['success'] == true && data['data'] != null && data['data']['locations'] != null) {
      debugPrint('   📋 Processing API response format');
      final locations = data['data']['locations'] as List<dynamic>;
      debugPrint('   📊 Locations list length: ${locations.length}');
      
      final parsedZones = locations.map((location) {
        try {
          final zone = SafeZone(
            name: location['name'] ?? '',
            type: location['type'] ?? 'unknown',
            location: LatLng(
              location['latitude'] as double, 
              location['longitude'] as double,
            ),
          );
          debugPrint('   ✅ Parsed: ${zone.name} (${zone.type})');
          return zone;
        } catch (e) {
          debugPrint('   ❌ Failed to parse location: $location - Error: $e');
          return null;
        }
      }).where((zone) => zone != null).cast<SafeZone>().toList();
      
      debugPrint('   🎯 Successfully parsed ${parsedZones.length} zones');
      return parsedZones;
    } else {
      debugPrint('   ❌ Invalid API response format');
      debugPrint('   Available keys: ${data is Map ? data.keys.toList() : 'Not a map'}');
      return [];
    }
  }


  // --- 6. MAP DRAWING FUNCTIONS (Equivalents to JS functions) ---

  void _drawFRI(List<FloodRiskInfo> friData) {
    final Set<Polygon> newPolygons = {};
    for (var d in friData) {
      if (d.polygons.isNotEmpty && d.polygons[0].isNotEmpty) {
        newPolygons.add(
          Polygon(
            polygonId: PolygonId(d.districtId),
            points: d.polygons[0],
            strokeWidth: 1,
            strokeColor: Colors.black.withOpacity(0.4),
            fillColor: _colorForLevel(
              d.level,
            ).withOpacity(d.level == 'GREEN' ? 0.15 : 0.25),
            consumeTapEvents: true,
            onTap: () {
              _onFriTapped(d);
            },
          ),
        );
      }
    }
    setState(() {
      _polygons = newPolygons;
    });
  }

  void _onFriTapped(FloodRiskInfo info) {
    _setAdviceFor(
      info.level,
      info.reasons,
      _nameFromDistrictId(info.districtId),
    );
    // In a real app, you would show an InfoWindow/BottomSheet here.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_nameFromDistrictId(info.districtId)}: Level ${info.level}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _drawSafeZones(List<SafeZone> safeZones) {
    debugPrint('🎨 DRAWING SAFE ZONES:');
    debugPrint('   Input safe zones: ${safeZones.length}');
    
    final Set<Marker> safeZoneMarkers = {};
    for (var s in safeZones) {
      debugPrint('   📍 Adding marker: ${s.name} (${s.type}) at ${s.location.latitude}, ${s.location.longitude}');
      safeZoneMarkers.add(
        Marker(
          markerId: MarkerId(s.name),
          position: s.location,
          icon: _getMarkerIconForType(s.type),
          onTap: () {
            _showCustomInfoPopup(s);
          },
        ),
      );
    }
    
    // Preserve existing markers (like user location) and add safe zone markers
    setState(() {
      _markers.addAll(safeZoneMarkers);
    });
    
    debugPrint('✅ Added ${safeZoneMarkers.length} safe zone markers. Total markers: ${_markers.length}');
  }

  /// Get appropriate marker icon based on location type
  BitmapDescriptor _getMarkerIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'hospital':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'police':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 'fire_department':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'school':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'stadium':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    }
  }

  /// Get emoji for location type
  String _getTypeEmoji(String type) {
    switch (type.toLowerCase()) {
      case 'hospital':
        return '🏥';
      case 'police':
        return '🚔';
      case 'fire_department':
        return '🚒';
      case 'school':
        return '🏫';
      case 'stadium':
        return '🏟️';
      default:
        return '📍';
    }
  }

  /// Update visible safe zones based on current map center (10km radius)
  void _updateVisibleSafeZones(LatLng mapCenter) {
    debugPrint('🔍 UPDATING VISIBLE SAFE ZONES:');
    debugPrint('   Total safe zones: ${_allSafeZones.length}');
    debugPrint('   Map center: ${mapCenter.latitude}, ${mapCenter.longitude}');
    
    if (_allSafeZones.isEmpty) {
      debugPrint('   ❌ No safe zones available');
      return;
    }
    
    // Filter safe zones within 10km of map center
    final nearbyZones = _allSafeZones.where((zone) {
      final distance = Geolocator.distanceBetween(
        mapCenter.latitude, mapCenter.longitude,
        zone.location.latitude, zone.location.longitude,
      );
      return distance <= 10000; // 10km in meters
    }).toList();
    
    debugPrint('   📍 Nearby zones (10km): ${nearbyZones.length}');
    
    // Apply flood zone filtering rule: only hospitals inside flood zones
    final filteredZones = _filterSafeZonesByFloodZones(nearbyZones);
    
    debugPrint('   🎯 Filtered zones: ${filteredZones.length}');
    
    // Clear existing safe zone markers and add new ones
    _clearSafeZoneMarkers();
    _drawSafeZones(filteredZones);
    
    _currentMapCenter = mapCenter;
  }

  /// Filter safe zones based on flood zone rules: only hospitals inside flood zones
  List<SafeZone> _filterSafeZonesByFloodZones(List<SafeZone> safeZones) {
    debugPrint('🔍 FILTERING SAFE ZONES BY FLOOD ZONES:');
    debugPrint('   Input safe zones: ${safeZones.length}');
    debugPrint('   Flood zones available: ${_floodRiskInfoList.length}');
    
    if (_floodRiskInfoList.isEmpty) {
      debugPrint('   ⚠️ No flood zones - showing all safe zones');
      return safeZones;
    }
    
    final filteredZones = <SafeZone>[];
    
    for (var safeZone in safeZones) {
      final isInsideFloodZone = _isSafeZoneInFloodZone(safeZone);
      debugPrint('   🏥 ${safeZone.name} (${safeZone.type}) - Inside flood zone: $isInsideFloodZone');
      
      if (isInsideFloodZone) {
        // Inside flood zone - only show hospitals
        if (safeZone.type.toLowerCase() == 'hospital' || 
            safeZone.type.toLowerCase() == 'medical_centre' ||
            safeZone.type.toLowerCase() == 'clinic') {
          debugPrint('     ✅ Adding hospital inside flood zone');
          filteredZones.add(safeZone);
        } else {
          debugPrint('     ❌ Skipping non-hospital inside flood zone');
        }
      } else {
        // Outside flood zone - show all types
        debugPrint('     ✅ Adding safe zone outside flood zone');
        filteredZones.add(safeZone);
      }
    }
    
    debugPrint('   🎯 Filtered result: ${filteredZones.length} zones');
    return filteredZones;
  }

  /// Check if a safe zone is inside any flood zone
  bool _isSafeZoneInFloodZone(SafeZone safeZone) {
    for (var floodZone in _floodRiskInfoList) {
      if (GeometryService.isPointInAnyPolygon(safeZone.location, floodZone.polygons)) {
        return true;
      }
    }
    return false;
  }

  /// Clear only safe zone markers (preserve user location marker)
  void _clearSafeZoneMarkers() {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value != 'user_location');
    });
  }

  /// Calculate distance between two LatLng points in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude, point1.longitude,
      point2.latitude, point2.longitude,
    );
  }


  void _showCustomInfoPopup(SafeZone safeZone) {
    setState(() {
      _selectedSafeZone = safeZone;
    });
  }

  void _hideCustomInfoPopup() {
    setState(() {
      _selectedSafeZone = null;
    });
  }

  void _showRouteModal(SafeZone destination) async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User location not available')),
      );
      return;
    }

    // Show loading modal first
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding optimal routes...'),
          ],
        ),
      ),
    );

    try {
      // Get optimized routes
      final routes = await _getOptimizedRoutes(_userLocation!, destination.location);
      
      // Close loading modal
      if (context.mounted) {
        Navigator.pop(context);
        
        if (routes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No routes found')),
          );
          return;
        }

        // Show route selection modal
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Route to ${destination.name}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${_getTypeEmoji(destination.type)} ${destination.type.toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Close button
                                IconButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.grey[100],
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Routes list
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: routes.length,
                          itemBuilder: (context, index) {
                            final route = routes[index];
                            return _buildRouteOption(route, destination);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }
    } catch (e) {
      // Close loading modal
      if (context.mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting routes: $e')),
        );
      }
    }
  }

  Widget _buildRouteOption(RouteOption route, SafeZone destination) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context);
            _startNavigation(route, destination);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Route icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getRouteColor(route.safetyLevel).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    _getRouteIcon(route.name),
                    color: _getRouteColor(route.safetyLevel),
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Route details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        route.summary,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildSafetyBadge(route.safetyLevel),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              route.instructions,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyBadge(RouteSafetyLevel level) {
    Color color;
    String text;
    
    switch (level) {
      case RouteSafetyLevel.safe:
        color = Colors.green;
        text = 'Safe';
        break;
      case RouteSafetyLevel.moderate:
        color = Colors.orange;
        text = 'Moderate';
        break;
      case RouteSafetyLevel.risky:
        color = Colors.red;
        text = 'Risky';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Color _getRouteColor(RouteSafetyLevel level) {
    switch (level) {
      case RouteSafetyLevel.safe:
        return Colors.green;
      case RouteSafetyLevel.moderate:
        return Colors.orange;
      case RouteSafetyLevel.risky:
        return Colors.red;
    }
  }

  IconData _getRouteIcon(String routeName) {
    if (routeName.contains('Fastest')) return Icons.speed;
    if (routeName.contains('Safest')) return Icons.shield;
    return Icons.balance;
  }

  void _startNavigation(RouteOption route, SafeZone destination) {
    // Clear existing polylines
    setState(() {
      _polylines.clear();
    });

    // Add route polyline to map
    if (route.waypoints.isNotEmpty) {
      final polyline = Polyline(
        polylineId: const PolylineId('selected_route'),
        points: route.waypoints,
        color: _getRouteColor(route.safetyLevel),
        width: 5,
        patterns: route.safetyLevel == RouteSafetyLevel.safe 
            ? [] 
            : [PatternItem.dash(10), PatternItem.gap(5)],
      );

      setState(() {
        _polylines.add(polyline);
      });

      // Update ETA summary
      _updateEtaSummary(
        route.duration,
        route.distance,
        _userLocation!,
        destination,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${route.name} selected (${route.summary})'),
          backgroundColor: _getRouteColor(route.safetyLevel),
        ),
      );
    }
  }


  // --- 8. GEOLOCATION (Equivalent to JS 'getUserLocation') ---

  Future<LatLng> _getUserLocation() async {

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return DEFAULT_CENTER;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return DEFAULT_CENTER;
      }
      if (permission == LocationPermission.denied) {
        return DEFAULT_CENTER;
      }
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(position.latitude, position.longitude);
  }

  // --- 9. GEOMETRY LOGIC (Now using GeometryService) ---

  /// Find flood zones that contain the user's location
  List<FloodRiskInfo> _getUserFloodZones(LatLng userLocation, List<FloodRiskInfo> friData) {
    final userZones = <FloodRiskInfo>[];
    
    for (var zone in friData) {
      // Check if user is in any polygon of this zone
      if (GeometryService.isPointInAnyPolygon(userLocation, zone.polygons)) {
        userZones.add(zone);
      }
    }
    
    return userZones;
  }

  /// Assess user's risk based on their location relative to flood zones
  void _assessUserRisk(LatLng userLocation, List<FloodRiskInfo> friData) {
    // 🔍 INVESTIGATION: Compare user location with flood zone locations
    debugPrint('🔍 INVESTIGATION - Risk Assessment Analysis:');
    debugPrint('📍 User location: ${userLocation.latitude}, ${userLocation.longitude} (${_getRegionFromCoordinates(userLocation)})');
    debugPrint('📍 Available flood zones: ${friData.length}');
    
    for (var zone in friData) {
      if (zone.polygons.isNotEmpty && zone.polygons.first.isNotEmpty) {
        final firstPoint = zone.polygons.first.first;
        debugPrint('   Zone: ${zone.districtId} - ${firstPoint.latitude}, ${firstPoint.longitude} (${_getRegionFromCoordinates(firstPoint)})');
      }
    }
    
    final userZones = _getUserFloodZones(userLocation, friData);
    
    if (userZones.isEmpty) {
      // User is outside all flood zones - SAFE
      _setAdviceFor(
        "GREEN",
        ["User location is safe"],
        "Your Location",
        user: userLocation,
      );
      debugPrint('🟢 User is outside all flood zones');
    } else {
      // User is inside one or more flood zones - show highest risk
      final highestRisk = userZones.reduce(
        (a, b) => _severity(b.level) > _severity(a.level) ? b : a,
      );
      
      _setAdviceFor(
        highestRisk.level,
        highestRisk.reasons,
        _nameFromDistrictId(highestRisk.districtId),
        user: userLocation,
      );
      debugPrint('🔴 User is inside flood zone: ${highestRisk.districtId}');
    }
  }

  // --- 10. HELPERS (from map.js) ---

  int _severity(String l) {
    return l == 'SEVERE'
        ? 4  // Highest severity
        : l == 'CRITICAL'
        ? 3
        : l == 'MODERATE'
        ? 2
        : l == 'MINOR' || l == 'GREEN'
        ? 1  // Lowest severity
        : 0;
  }

  String _nameFromDistrictId(String id) {
    if (id.isEmpty) return "Unknown area";
    final parts = id.split(":");
    return parts.last.replaceAll("_", " ");
  }

  Color _colorForLevel(String l) {
    return l == 'SEVERE'
        ? const Color(0xffd32f2f)  // RED for SEVERE
        : l == 'CRITICAL'
        ? const Color(0xfff57c00)  // ORANGE for CRITICAL
        : l == 'MODERATE'
        ? const Color(0xfffbc02d)  // YELLOW for MODERATE
        : l == 'MINOR' || l == 'GREEN'
        ? const Color(0xff43a047)  // GREEN for MINOR/GREEN
        : const Color(0xff43a047); // Default to GREEN
  }

  String _adviceForLevel(String l) {
    if (l == 'SEVERE') {
      return "🔴 Severe risk. Evacuate if instructed. Avoid rivers/underpasses.";
    }
    if (l == 'CRITICAL') {
      return "🟠 Critical risk. Immediate evacuation required. Move to higher ground.";
    }
    if (l == 'MODERATE') {
      return "🟡 Heavy rain possible. Prepare go-bag. Avoid low areas.";
    }
    if (l == 'MINOR' || l == 'GREEN') {
      return "🟢 Safe area. No immediate flood risk detected.";
    }
    return "🟢 Low risk. Stay alert for updates.";
  }

  String _getSeverityText(String level) {
    switch (level.toUpperCase()) {
      case 'MINOR':
      case 'GREEN':
        return 'Minor';
      case 'MODERATE':
      case 'YELLOW':
        return 'Moderate';
      case 'SEVERE':
        return 'Severe';
      case 'CRITICAL':
      case 'RED':
        return 'Critical';
      default:
        return level.toUpperCase();
    }
  }

  void _setAdviceFor(
    String level,
    List<String> reasons,
    String title, {
    LatLng? user,
    LatLng? zone,
  }) {
    final msg = _adviceForLevel(level);
    String details = '';
    if (user != null) {
      details +=
          'User: ${user.latitude.toStringAsFixed(4)}, ${user.longitude.toStringAsFixed(4)}\n';
    }
    if (zone != null) {
      details +=
          'Zone: ${zone.latitude.toStringAsFixed(4)}, ${zone.longitude.toStringAsFixed(4)}\n';
    }

    setState(() {
      _currentLevel = level;
      _adviceMessage = '$msg\n${reasons.join(", ")}\n$details';
    });
  }

  void _updateEtaSummary(
    int min,
    double km,
    LatLng origin,
    SafeZone destination,
  ) {
    final toLabel = destination.name;
    final fromStr =
        '${origin.latitude.toStringAsFixed(4)}, ${origin.longitude.toStringAsFixed(4)}';

    setState(() {
      _etaSummary =
          'ETA: ~$min min • Distance: ${km.toStringAsFixed(1)} km\nFrom: $fromStr | To: $toLabel';
    });
  }


  // --- 10. FLUTTER UI BUILDER (Replacing the HTML map/panels) ---

  @override
  Widget build(BuildContext context) {
    // Determine the initial camera position based on the state
    final initialCameraPosition = CameraPosition(
      target: _userLocation ?? DEFAULT_CENTER,
      zoom: 13,
    );

    // The main map view area
    final mapWidget = SizedBox(
      width: double.infinity,
      height: 270,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              // Only adjust camera position, don't re-run full initialization
              if (_userLocation != null) {
                _setMapZoom(_userLocation!);
              }
            },
            onCameraMove: (CameraPosition position) {
              // Update visible safe zones when map moves
              if (_currentMapCenter == null || 
                  _calculateDistance(_currentMapCenter!, position.target) > 1000) {
                // Only update if moved more than 1km to avoid excessive updates
                debugPrint('🗺️ Camera moved to: ${position.target.latitude}, ${position.target.longitude}');
                _updateVisibleSafeZones(position.target);
              }
            },
            initialCameraPosition: initialCameraPosition,
            polygons: _polygons,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: true,
          ),
        ),
      ),
    );

    // Advice Panel UI (Replacing the JS 'advice' div)
    final advicePanel = Card(
      elevation: 2,
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 120,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(11.4),
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  if (notification is ScrollUpdateNotification) {
                    setState(() {
                      _scrollPosition = notification.metrics.pixels;
                    });
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _riskPanelScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Your Location",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _colorForLevel(_currentLevel),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getSeverityText(_currentLevel),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 10),
                      Text(_adviceMessage),
                      const SizedBox(height: 4),
                      Text(
                        _lastUpdated,
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Custom scrollbar indicator
            Positioned(
              right: 4,
              top: 8,
              bottom: 8,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Builder(
                  builder: (context) {
                    if (!_riskPanelScrollController.hasClients) {
                      return Container();
                    }
                    
                    final maxScrollExtent = _riskPanelScrollController.position.maxScrollExtent;
                    final viewportHeight = _riskPanelScrollController.position.viewportDimension;
                    final contentHeight = maxScrollExtent + viewportHeight;
                    
                    if (maxScrollExtent <= 0) {
                      return Container();
                    }
                    
                    final thumbHeight = (viewportHeight / contentHeight) * (120 - 16);
                    final thumbTop = (_scrollPosition / maxScrollExtent) * (120 - 16 - thumbHeight);
                    
                    return Stack(
                      children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Positioned(
                          top: thumbTop,
                          child: Container(
                            width: 4,
                            height: thumbHeight,
                            decoration: BoxDecoration(
                              color: Colors.grey[600],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // ETA/Distance Panel UI (Replacing the JS 'etaSummary' div)
    final etaPanel = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route ETA & Distance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _etaSummary.split('\n')[0],
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          if (_etaSummary.contains('\n'))
            Text(
              _etaSummary.split('\n')[1],
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
        ],
      ),
    );

    // Legend UI (Replacing the JS 'legend' div)
    final legend = Container(
      padding: const EdgeInsets.all(9.72),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegendItem('Minor', _colorForLevel('MINOR')),
          _buildLegendItem('Moderate', _colorForLevel('MODERATE')),
          _buildLegendItem('Severe', _colorForLevel('SEVERE')),
          _buildLegendItem('Critical', _colorForLevel('CRITICAL')),
        ],
      ),
    );

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 1. Advice Panel (replaces Risk Status Card)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: advicePanel,
              ),
              const SizedBox(height: 16.0),

              // 2. Map Widget
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: mapWidget,
              ),
              const SizedBox(height: 24.0),

              // 3. Legend and Route ETA Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 8, child: legend),
                    const SizedBox(width: 16.0),
                    Expanded(flex: 22, child: etaPanel),
                  ],
                ),
              ),
              const SizedBox(height: 32.0),

              // 4. Emergency Escape Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReportScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'Incident Report',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Custom Info Popup Overlay
        if (_selectedSafeZone != null)
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: _buildCustomInfoPopup(_selectedSafeZone!),
          ),
      ],
    );
  }

  Widget _buildCustomInfoPopup(SafeZone safeZone) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 340,
        minHeight: 102,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with close button
          Container(
            padding: const EdgeInsets.all(13.6),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _getMarkerIconForType(safeZone.type).hashCode == BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed).hashCode 
                        ? Colors.red.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Center(
                    child: Text(
                      _getTypeEmoji(safeZone.type),
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(width: 10.2),
                
                // Title and type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeZone.name,
                        style: const TextStyle(
                          fontSize: 13.6,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1.7),
                      Text(
                        safeZone.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.2,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Close button
                IconButton(
                  onPressed: _hideCustomInfoPopup,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.grey,
                    size: 17,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(6.8),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(13.6),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _hideCustomInfoPopup();
                  _showRouteModal(safeZone);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2254C5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6.8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions, size: 15.3),
                    const SizedBox(width: 6.8),
                    const Text(
                      'Show Safe Routes',
                      style: TextStyle(
                        fontSize: 11.9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label, 
            style: const TextStyle(fontSize: 11),
          )
        ],
      ),
    );
  }
}

// --- Example `main` function to run the app ---
void main() {
  // Ensure Flutter binding is initialized for services like Geolocation
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MySelamat FloodSafe Map',
      theme: ThemeData(fontFamily: 'Public Sans', primarySwatch: Colors.blue),
      // We wrap the map content in a Scaffold to provide app bar and other UI
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'MySelamat Flood Map',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF2254C5),
        ),
        body: const FloodMapWidget(),
      ),
    );
  }
}
