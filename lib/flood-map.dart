import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng2;

// --- 1. CONFIGURATION CONSTANTS (from map.js) ---
const bool USE_MOCKS = true;
const String API_BASE = "http://localhost:3001"; // For real backend API access
const String MOCK_PATH = "http://localhost:8080/mocks"; // Assuming mock files are served
const LatLng DEFAULT_CENTER = LatLng(6.129, 102.243); // Kota Bharu
const bool USE_FAKE_USER_LOC = true;
const LatLng FAKE_USER_LOC = LatLng(6.191, 102.273);

// Replace with your actual key in production
const String GOOGLE_API_KEY = "AIzaSyAupowXVdjw9VQESNxsqBeWskKjXvfeTZE"; 
const String ROUTES_BASE = "https://routes.googleapis.com";

// --- 2. DATA MODELS ---

class SafeZone {
  final String name;
  final LatLng location;
  SafeZone({required this.name, required this.location});
}

class FloodRiskInfo {
  final String districtId;
  final String level;
  final List<String> reasons;
  final List<List<LatLng>> polygons;
  
  FloodRiskInfo({
    required this.districtId, 
    required this.level, 
    required this.reasons,
    required this.polygons,
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
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // UI State for Advice/ETA Panels
  String _currentLevel = "GREEN";
  String _adviceTitle = "Risk Summary";
  String _adviceMessage = "🟢 Low risk. Stay alert for updates.";
  String _etaSummary = "Tap a safe zone and press 'Safe Route'.";
  String _lastUpdated = "Loading...";

  // --- 4. LIFECYCLE AND INITIALIZATION ---

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  // Equivalent to JS 'initMap' function
  Future<void> _initMap() async {
    final userLoc = await _getUserLocation();
    setState(() {
      _userLocation = userLoc;
      _lastUpdated = 'Last updated: ${DateTime.now().toString()}';
    });

    try {
      // 1. Load Data
      final fri = await _safeFetch('$MOCK_PATH/fri.latest.json');
      final safe = await _safeFetch('$MOCK_PATH/safe-zones.json');
      // GeoJSON loading for hazards is complex in Flutter; we'll simulate it for now.
      
      // 2. Process and Draw Layers
      final friData = _parseFri(fri);
      final safeZones = _parseSafeZones(safe);
      
      _drawFRI(friData);
      _drawSafeZones(safeZones);
      
      // 3. Initialize Panel
      final top = friData.reduce((a, b) => _severity(b.level) > _severity(a.level) ? b : a);
      _setAdviceFor(top.level, top.reasons, _nameFromDistrictId(top.districtId));

      // 4. Fit map to user area (5km circle)
      if (_mapController != null) {
        final dist = latlng2.Distance();
        // Calculate the bounding box for 5km around the user
        final northEast = dist.offset(latlng2.LatLng(userLoc.latitude, userLoc.longitude), 5000, 45); // 45 degrees for NE
        final southWest = dist.offset(latlng2.LatLng(userLoc.latitude, userLoc.longitude), 5000, 225); // 225 degrees for SW

        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(southWest.latitude, southWest.longitude),
              northeast: LatLng(northEast.latitude, northEast.longitude),
            ),
            100, // padding
          ),
        );
      }
    } catch (e) {
      debugPrint('Map initialization error: $e');
      _setAdviceFor("RED", ["Data loading failed"], "Error");
    }
  }
  
  // --- 5. DATA FETCHING AND PARSING ---

  // Equivalent to JS 'safeFetch'
  Future<dynamic> _safeFetch(String url) async {
    final uri = Uri.parse(url);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load $url: ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  List<FloodRiskInfo> _parseFri(dynamic data) {
    if (data is! List) return [];
    return data.map((d) {
      // Converts [[lng, lat], [lng, lat], ...] to List<LatLng>
      final polygons = (d['polygon']?[0] as List<dynamic>?)
          ?.map((point) => LatLng(point[1] as double, point[0] as double))
          .toList() ?? [];

      return FloodRiskInfo(
        districtId: d['districtId'] ?? '',
        level: d['level'] ?? 'GREEN',
        reasons: (d['reasons'] as List<dynamic>?)?.map((r) => r.toString()).toList() ?? [],
        polygons: [polygons],
      );
    }).toList();
  }
  
  List<SafeZone> _parseSafeZones(dynamic data) {
    if (data is! List) return [];
    return data.map((s) => SafeZone(
      name: s['name'] ?? '',
      location: LatLng(s['lat'] as double, s['lng'] as double),
    )).toList();
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
            fillColor: _colorForLevel(d.level).withOpacity(d.level == 'GREEN' ? 0.15 : 0.25),
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
    _setAdviceFor(info.level, info.reasons, _nameFromDistrictId(info.districtId));
    // In a real app, you would show an InfoWindow/BottomSheet here.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_nameFromDistrictId(info.districtId)}: Level ${info.level}'),
      duration: const Duration(seconds: 2),
    ));
  }

  void _drawSafeZones(List<SafeZone> safeZones) {
    final Set<Marker> newMarkers = {};
    for (var s in safeZones) {
      newMarkers.add(
        Marker(
          markerId: MarkerId(s.name),
          position: s.location,
          infoWindow: InfoWindow(
            title: s.name,
            snippet: 'Tap for Safe Route',
            onTap: () {
              // This is where we would trigger the modal/button for routing in Flutter
              _showRouteModal(s);
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    setState(() {
      _markers = newMarkers;
    });
  }

  void _showRouteModal(SafeZone destination) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(destination.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); 
                  _getSafeRoute(_userLocation!, destination);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Calculate Safe Route'),
              ),
              const SizedBox(height: 10),
              Text(
                'Destination Coords: ${destination.location.latitude.toStringAsFixed(4)}, ${destination.location.longitude.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 7. GOOGLE ROUTES API CALL (Equivalent to JS 'getSafeRoute') ---

  Future<void> _getSafeRoute(LatLng origin, SafeZone destination) async {
    setState(() {
      _etaSummary = "Calculating route...";
      _polylines = {};
    });

    try {
      final body = {
        "origin": { "location": { "latLng": { "latitude": origin.latitude, "longitude": origin.longitude } } },
        "destination": { "location": { "latLng": { "latitude": destination.location.latitude, "longitude": destination.location.longitude } } },
        "travelMode": "DRIVE",
        "routingPreference": "TRAFFIC_AWARE",
        "polylineQuality": "HIGH_QUALITY",
        "polylineEncoding": "GEO_JSON_LINESTRING"
      };

      final url = Uri.parse('$ROUTES_BASE/directions/v2:computeRoutes?key=$GOOGLE_API_KEY');

      final res = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-Goog-FieldMask": "routes.distanceMeters,routes.duration,routes.polyline.geoJsonLinestring,routes.polyline.encodedPolyline"
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode != 200 || data['routes'] == null || data['routes'].isEmpty) {
        final msg = data['error']?['message'] ?? 'Unknown route error.';
        debugPrint('ComputeRoutes error: ${res.statusCode} $msg');
        _setEtaSummaryError('Route error: $msg');
        return;
      }

      final route = data['routes'][0];
      
      // Decode Polyline
      final List<LatLng> path = [];
      if (route['polyline']?['geoJsonLinestring']?['coordinates'] != null) {
        // GeoJSON: coordinates are [lng, lat]
        for (var point in route['polyline']['geoJsonLinestring']['coordinates']) {
          path.add(LatLng(point[1], point[0]));
        }
      } else if (route['polyline']?['encodedPolyline'] != null) {
        // Fallback to encoded polyline (requires google_maps_flutter util)
        // Note: Flutter's Google Maps package doesn't expose a polyline decoder directly. 
        // We'll rely only on GeoJSON for simplicity and alignment with the JS request.
        // For a production app, a dedicated polyline utility package would be needed.
        _setEtaSummaryError("Route error: Encoded polyline fallback not implemented in Flutter.");
        return;
      }
      
      if (path.isEmpty) {
        _setEtaSummaryError("Route error: No polyline data found.");
        return;
      }

      // Draw Polyline
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('safe_route'),
            points: path,
            color: Colors.red,
            width: 4,
          )
        };
      });
      
      // Update ETA box
      final distanceMeters = route['distanceMeters'] as int;
      final durationString = route['duration'] as String; // e.g., "600s"
      
      final sec = int.parse(durationString.replaceAll('s', ''));
      final min = (sec / 60).round();
      final km = distanceMeters / 1000.0;
      
      _updateEtaSummary(min, km, origin, destination);

      _setAdviceFor("GREEN", ["Route calculated"], "Routing",
        user: origin, zone: destination.location);

    } catch (e) {
      debugPrint('Routes API fetch failed: $e');
      _setEtaSummaryError('Route error: request failed.');
    }
  }

  // --- 8. GEOLOCATION (Equivalent to JS 'getUserLocation') ---

  Future<LatLng> _getUserLocation() async {
    if (USE_FAKE_USER_LOC) {
      return FAKE_USER_LOC;
    }

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
      timeout: const Duration(seconds: 5),
    );
    return LatLng(position.latitude, position.longitude);
  }
  
  // --- 9. HELPERS (from map.js) ---

  int _severity(String l){ return l=='RED'?3 : l=='ORANGE'?2 : l=='YELLOW'?1 : 0; }
  
  String _nameFromDistrictId(String id){
    if(id.isEmpty) return "Unknown area";
    final parts = id.split(":");
    return parts.last.replaceAll("_", " ");
  }
  
  Color _colorForLevel(String l){return l=='RED'?const Color(0xffd32f2f):l=='ORANGE'?const Color(0xfff57c00):l=='YELLOW'?const Color(0xfffbc02d):const Color(0xff43a047);}

  String _adviceForLevel(String l){
    if(l=='RED')return"🔴 Severe risk. Evacuate if instructed. Avoid rivers/underpasses.";
    if(l=='ORANGE')return"🟠 High risk in 24h. Move valuables. Plan evacuation.";
    if(l=='YELLOW')return"🟡 Heavy rain possible. Prepare go-bag. Avoid low areas.";
    return"🟢 Low risk. Stay alert for updates.";
  }

  String _badgeForLevel(String level){
    final l = level.toUpperCase();
    return l;
  }
  
  void _setAdviceFor(String level, List<String> reasons, String title, {LatLng? user, LatLng? zone}) {
    final msg = _adviceForLevel(level);
    String details = '';
    if (user != null) {
      details += 'User: ${user.latitude.toStringAsFixed(4)}, ${user.longitude.toStringAsFixed(4)}\n';
    }
    if (zone != null) {
      details += 'Zone: ${zone.latitude.toStringAsFixed(4)}, ${zone.longitude.toStringAsFixed(4)}\n';
    }
    
    setState(() {
      _currentLevel = level;
      _adviceTitle = "$title ${_badgeForLevel(level)}";
      _adviceMessage = '$msg\n${reasons.join(", ")}\n$details';
    });
  }

  void _updateEtaSummary(int min, double km, LatLng origin, SafeZone destination){
    final toLabel = destination.name;
    final fromStr = '${origin.latitude.toStringAsFixed(4)}, ${origin.longitude.toStringAsFixed(4)}';

    setState(() {
      _etaSummary = 'ETA: ~$min min • Distance: ${km.toStringAsFixed(1)} km\nFrom: $fromStr | To: $toLabel';
    });
  }
  
  void _setEtaSummaryError(String msg){
    setState(() {
      _etaSummary = msg;
    });
  }


  // --- 10. FLUTTER UI BUILDER (Replacing the HTML map/panels) ---

  @override
  Widget build(BuildContext context) {
    // Determine the initial camera position based on the state
    final initialCameraPosition = CameraPosition(
      target: _userLocation ?? DEFAULT_CENTER,
      zoom: 12,
    );
    
    // The main map view area
    final mapWidget = AspectRatio(
      aspectRatio: 1.2,
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
              // Re-run initMap to adjust camera after controller is available
              if (_userLocation != null) {
                _initMap(); 
              }
            },
            initialCameraPosition: initialCameraPosition,
            polygons: _polygons,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),
        ),
      ),
    );
    
    // Advice Panel UI (Replacing the JS 'advice' div)
    final advicePanel = Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _adviceTitle.split(' ')[0], 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _colorForLevel(_currentLevel),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _currentLevel,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _adviceTitle.split(' ').skip(1).join(' '),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const Divider(height: 10),
            Text(_adviceMessage),
            const SizedBox(height: 4),
            Text(
              _lastUpdated,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegendItem('Green', _colorForLevel('GREEN')),
          _buildLegendItem('Yellow', _colorForLevel('YELLOW')),
          _buildLegendItem('Orange', _colorForLevel('ORANGE')),
          _buildLegendItem('Red', _colorForLevel('RED')),
          const SizedBox(height: 8),
          const Text('Tap district for details', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54)),
        ],
      ),
    );

    return SingleChildScrollView(
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
                Expanded(flex: 1, child: legend),
                const SizedBox(width: 16.0),
                Expanded(flex: 2, child: etaPanel),
              ],
            ),
          ),
          const SizedBox(height: 32.0),
          
          // 4. Emergency Escape Button (Placeholder logic)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: () { /* Handle emergency action */ },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828), 
                minimumSize: const Size(double.infinity, 50), 
              ),
              child: const Text('Emergency Escape', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
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
      theme: ThemeData(
        fontFamily: 'Public Sans', 
        primarySwatch: Colors.blue,
      ),
      // We wrap the map content in a Scaffold to provide app bar and other UI
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MySelamat Flood Map', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF2254C5),
        ),
        body: const FloodMapWidget(),
      ),
    );
  }
}
