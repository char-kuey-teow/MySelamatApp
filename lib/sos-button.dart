import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for vibration/haptic feedback
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'profile.dart';
import 'config.dart';

// --- Placeholder for the Home Screen ---
// In a real app, this would be your FloodSafeScreen from the earlier file.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const primaryColor = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home, size: 80, color: primaryColor),
          Text(
            'Welcome to MySelamat Home Screen',
            style: TextStyle(fontSize: 24, color: primaryColor),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// The actual SOS Screen (Unmodified logic, now a child of MainNavigator)
// -----------------------------------------------------------

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  // We reuse the colors defined in the parent context if needed, but for simplicity
  // we'll keep the constants here, removing the static prefix.
  final headerBarColor = const Color(0xFF2254C5);
  final primaryColor = const Color(0xFF1B5E20);
  final sosColor = const Color(0xFFD32F2F);
  final backgroundColor = const Color(0xFF121212);
  final secondaryTextColor = Colors.white70;

  // SOS Button State
  double _sosScale = 1.0;
  bool _isSosPressed = false;
  bool _isHolding = false;
  bool _showCategories = false;
  static const Duration _holdDuration = Duration(seconds: 3);
  Timer? _holdTimer;
  int _holdProgress = 0;

  // Animation Controllers - Optimized for performance
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Performance optimization: Cache frequently used values
  static const double _sosButtonSize = 180.0;
  static const double _progressRingSize = 200.0;
  static const Duration _animationDuration = Duration(milliseconds: 800);
  static const Duration _holdTimerInterval = Duration(
    milliseconds: 50,
  ); // Reduced from 100ms

  // Status tracking
  String _currentStatus = '';
  bool _isSosActive = false;
  Timer? _locationUpdateTimer;
  bool _isErrorStatus = false;
  //submission data
  String? _sentCategory;
  Position? _sentLocation;
  DateTime? _sentTimestamp;
  String? _locationAddress; // Store the geocoded address
  Map<String, String>? _locationDetails; // Store detailed location info

  // Location and user data
  UserProfile? _currentUserProfile;
  String _userId = 'demo_user_123';
  String _userName = 'Demo User';

  // Performance optimization: Cache location data
  Position? _cachedPosition;
  DateTime? _lastLocationUpdate;
  Map<String, String>? _cachedLocationDetails;
  static const Duration _locationCacheTimeout = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize location services and load user profile
    _initializeLocation();
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh user profile when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshUserProfile();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdTimer?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _onSosDown(BuildContext context, TapDownDetails details) {
    if (_showCategories || _isSosActive) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isSosPressed = true;
      _isHolding = true;
      _sosScale = 0.95;
      _holdProgress = 0;
    });

    _pulseController.repeat(reverse: true);

    // Optimized timer with reduced frequency and pre-calculated values
    final totalTicks =
        (_holdDuration.inMilliseconds / _holdTimerInterval.inMilliseconds)
            .round();

    _holdTimer = Timer.periodic(_holdTimerInterval, (timer) {
      if (!_isSosPressed) {
        timer.cancel();
        _resetSosState();
        return;
      }

      // Only update UI every few ticks to reduce setState calls
      if (timer.tick % 2 == 0) {
        setState(() {
          _holdProgress = ((timer.tick * 100) / totalTicks).round();
        });
      } else {
        // Update progress without setState for smoother animation
        _holdProgress = ((timer.tick * 100) / totalTicks).round();
      }

      if (timer.tick >= totalTicks) {
        timer.cancel();
        _onHoldComplete(context);
      }
    });
  }

  void _onSosUp(BuildContext context, TapUpDetails details) => _resetSosState();
  void _onSosCancel() => _resetSosState();

  void _resetSosState() {
    setState(() {
      _isSosPressed = false;
      _isHolding = false;
      _sosScale = 1.0;
      _holdProgress = 0;
    });

    _pulseController.stop();
    _holdTimer?.cancel();
  }

  void _onHoldComplete(BuildContext context) {
    HapticFeedback.vibrate();
    setState(() {
      _showCategories = true;
      _isHolding = false;
      _sosScale = 1.0;
    });

    _pulseController.stop();
  }

  void _showStatusMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    // Only update if the message actually changed to avoid unnecessary rebuilds
    if (_currentStatus != message || _isErrorStatus != isError) {
      setState(() {
        _currentStatus = message;
        _isErrorStatus = isError;
      });
    }
  }

  void _startRescueSequence() {
    // Start rescue sequence only after SOS is successfully sent
    Timer(const Duration(seconds: 20), () {
      if (mounted && _isSosActive && !_isErrorStatus) {
        setState(() {
          _currentStatus = 'Rescue on the way';
        });
      }
    });

    Timer(const Duration(seconds: 40), () {
      if (mounted && _isSosActive && !_isErrorStatus) {
        setState(() {
          _currentStatus = 'Reached';
        });
      }
    });
  }

  void _markSafe() {
    setState(() {
      _isSosActive = false;
      _currentStatus = '';

      _sentCategory = null;
      _sentLocation = null;
      _sentTimestamp = null;
      _locationAddress = null;
      _locationDetails = null;
    });
    _locationUpdateTimer?.cancel();
  }

  // User Profile Loading Method
  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('userProfile');

      if (userData != null) {
        final userMap = jsonDecode(userData);
        setState(() {
          _currentUserProfile = UserProfile.fromJson(userMap);
          _userId = _currentUserProfile!.id;
          _userName = _currentUserProfile!.displayName;
        });
        print('User profile loaded: ${_currentUserProfile!.displayName}');
      } else {
        print('No user profile found, using demo data');
      }
    } catch (e) {
      print('Error loading user profile: $e');
      // Continue with demo data
    }
  }

  // Refresh user profile data when returning to SOS screen
  Future<void> _refreshUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('userProfile');

      if (userData != null) {
        final userMap = jsonDecode(userData);
        final updatedProfile = UserProfile.fromJson(userMap);

        // Only update if the profile has actually changed
        if (_currentUserProfile == null ||
            _currentUserProfile!.address != updatedProfile.address ||
            _currentUserProfile!.phoneNumber != updatedProfile.phoneNumber ||
            _currentUserProfile!.displayName != updatedProfile.displayName ||
            _currentUserProfile!.email != updatedProfile.email ||
            !_listEquals(
              _currentUserProfile!.floodRegions,
              updatedProfile.floodRegions,
            )) {
          setState(() {
            _currentUserProfile = updatedProfile;
            _userId = _currentUserProfile!.id;
            _userName = _currentUserProfile!.displayName;
          });
          print('User profile refreshed: ${_currentUserProfile!.displayName}');
        }
      }
    } catch (e) {
      print('Error refreshing user profile: $e');
    }
  }

  // Helper method to compare lists
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  // Enhanced geocoding service using Google Maps Geocoding API with caching
  Future<Map<String, String>> _getLocationDetailsFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      // Check cache first for performance
      final cacheKey =
          '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
      if (_cachedLocationDetails != null &&
          _cachedLocationDetails!['coordinates'] == cacheKey) {
        print('Using cached location details for: $cacheKey');
        return _cachedLocationDetails!;
      }

      print('Geocoding coordinates: $latitude, $longitude');

      // Use the geocoding package to get placemarks with reduced timeout for better performance
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(
        const Duration(seconds: 6), // Reduced from 10 seconds
        onTimeout: () {
          print('Geocoding timeout, using fallback location detection');
          throw TimeoutException(
            'Geocoding timeout',
            const Duration(seconds: 6),
          );
        },
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        print('Placemark found:');
        print('- Country: ${place.country}');
        print('- Administrative Area: ${place.administrativeArea}');
        print('- Sub Administrative Area: ${place.subAdministrativeArea}');
        print('- Locality: ${place.locality}');
        print('- Sub Locality: ${place.subLocality}');
        print('- Thoroughfare: ${place.thoroughfare}');
        print('- Sub Thoroughfare: ${place.subThoroughfare}');

        // Extract area and state information for Malaysian locations
        String area = '';
        String state = '';

        // For Malaysian locations, get area and state
        if (place.country?.toLowerCase().contains('malaysia') == true) {
          // Get the main area (city/district)
          if (place.locality?.isNotEmpty == true) {
            area = place.locality!;
          } else if (place.subAdministrativeArea?.isNotEmpty == true) {
            area = place.subAdministrativeArea!;
          }

          // Get the state
          if (place.administrativeArea?.isNotEmpty == true) {
            state = place.administrativeArea!;
          }
        } else {
          // General fallback for any location
          if (place.locality?.isNotEmpty == true) {
            area = place.locality!;
          }
          if (place.administrativeArea?.isNotEmpty == true) {
            state = place.administrativeArea!;
          }
        }

        // Return separate area and state fields for better display
        final result = {
          'area': area.isNotEmpty ? area : 'Unknown Area',
          'state': state.isNotEmpty ? state : '',
          'coordinates':
              '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
        };

        // Cache the result
        _cachedLocationDetails = result;
        return result;
      }

      print('No placemarks found for coordinates: $latitude, $longitude');
      // Use geocoding API for fallback area detection
      Map<String, String> fallbackResult =
          await _getAreaAndStateFromCoordinates(latitude, longitude);
      final result = {
        'area': fallbackResult['area'] ?? 'Unknown Area',
        'state': fallbackResult['state'] ?? '',
        'coordinates':
            '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
      };

      // Cache the result
      _cachedLocationDetails = result;
      return result;
    } on TimeoutException catch (e) {
      print('Geocoding timeout: $e');
      // Use geocoding API for fallback area detection
      Map<String, String> fallbackResult =
          await _getAreaAndStateFromCoordinates(latitude, longitude);
      final result = {
        'area': fallbackResult['area'] ?? 'Unknown Area',
        'state': fallbackResult['state'] ?? '',
        'coordinates':
            '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
      };

      // Cache the result
      _cachedLocationDetails = result;
      return result;
    } catch (e) {
      print('Error geocoding coordinates: $e');
      // Use geocoding API for fallback area detection
      Map<String, String> fallbackResult =
          await _getAreaAndStateFromCoordinates(latitude, longitude);
      final result = {
        'area': fallbackResult['area'] ?? 'Unknown Area',
        'state': fallbackResult['state'] ?? '',
        'coordinates':
            '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
      };

      // Cache the result
      _cachedLocationDetails = result;
      return result;
    }
  }

  // Fallback method to determine both area and state from coordinates using geocoding API
  Future<Map<String, String>> _getAreaAndStateFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    print(
      'Using geocoding API for coordinate-based area detection: $latitude, $longitude',
    );

    try {
      // Use the geocoding package to get placemarks with timeout handling
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('Geocoding timeout in fallback method');
          throw TimeoutException(
            'Geocoding timeout',
            const Duration(seconds: 8),
          );
        },
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        print('Fallback geocoding found placemark:');
        print('- Country: ${place.country}');
        print('- Administrative Area: ${place.administrativeArea}');
        print('- Locality: ${place.locality}');
        print('- Sub Administrative Area: ${place.subAdministrativeArea}');

        // Extract area and state information
        String area = '';
        String state = '';

        // Get the main area (city/district)
        if (place.locality?.isNotEmpty == true) {
          area = place.locality!;
        } else if (place.subAdministrativeArea?.isNotEmpty == true) {
          area = place.subAdministrativeArea!;
        }

        // Get the state/province
        if (place.administrativeArea?.isNotEmpty == true) {
          state = place.administrativeArea!;
        }

        // Return separate area and state
        final result = {
          'area':
              area.isNotEmpty
                  ? area
                  : (place.country?.isNotEmpty == true
                      ? place.country!
                      : 'Unknown Area'),
          'state': state.isNotEmpty ? state : '',
        };

        print(
          'Fallback geocoding result: Area=${result['area']}, State=${result['state']}',
        );
        return result;
      }

      print('No placemarks found in fallback geocoding');
      return {'area': 'Unknown Area', 'state': ''};
    } on TimeoutException catch (e) {
      print('Geocoding timeout in fallback method: $e');
      return {'area': 'Location Unknown (Timeout)', 'state': ''};
    } catch (e) {
      print('Error in fallback geocoding: $e');
      return {'area': 'Location Unknown (Error)', 'state': ''};
    }
  }

  // Location and AWS Integration Methods
  Future<void> _initializeLocation() async {
    print('Initializing location services...');

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    print('Location services enabled: $serviceEnabled');

    if (!serviceEnabled) {
      _showStatusMessage(
        context,
        'Location services are disabled. Please enable GPS to use SOS features.',
        isError: true,
      );
      return;
    }

    // Request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    print('Initial permission check: $permission');

    if (permission == LocationPermission.denied) {
      print('Requesting location permission...');
      permission = await Geolocator.requestPermission();
      print('Permission after request: $permission');

      if (permission == LocationPermission.denied) {
        _showStatusMessage(
          context,
          'Location permissions are denied. Please enable location access in settings.',
          isError: true,
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showStatusMessage(
        context,
        'Location permissions are permanently denied. Please enable location access in app settings.',
        isError: true,
      );
      return;
    }

    // Test location access with a comprehensive check
    try {
      print('Testing location access...');
      Position testPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      print(
        'Test position obtained: ${testPosition.latitude}, ${testPosition.longitude}',
      );
      print('Test position accuracy: ${testPosition.accuracy}m');

      // Check if we got real coordinates (not Google's test coordinates)
      if (testPosition.latitude == 37.4219983 &&
          testPosition.longitude == -122.084) {
        print(
          'Got Google test coordinates during initialization, requesting real location...',
        );

        // Try to get real location with different settings
        testPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 45),
          forceAndroidLocationManager: false,
        );

        if (testPosition.latitude == 37.4219983 &&
            testPosition.longitude == -122.084) {
          print('Still getting test coordinates. This may be due to:');
          print('1. Running on emulator without location set');
          print('2. GPS disabled on device');
          print('3. Location permissions not properly granted');
          print('4. Device in airplane mode or poor GPS signal');
          print(
            'Real location will be obtained when sending SOS if GPS is properly configured',
          );
        } else {
          print(
            'Successfully obtained real coordinates after retry: ${testPosition.latitude}, ${testPosition.longitude}',
          );
        }
      } else {
        print(
          'Location services initialized successfully with real coordinates',
        );
      }
    } catch (e) {
      print('Error getting initial location: $e');
      _showStatusMessage(
        context,
        'Unable to access location. Please check GPS settings and permissions.',
        isError: true,
      );
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      // Check cache first for performance
      if (_cachedPosition != null && _lastLocationUpdate != null) {
        final timeDiff = DateTime.now().difference(_lastLocationUpdate!);
        if (timeDiff < _locationCacheTimeout) {
          print(
            'Using cached location: ${_cachedPosition!.latitude}, ${_cachedPosition!.longitude}',
          );
          return _cachedPosition;
        }
      }

      print('Starting location request...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Location services enabled: $serviceEnabled');

      if (!serviceEnabled) {
        _showStatusMessage(
          context,
          'Location services are disabled. Please enable GPS.',
          isError: true,
        );
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      print('Current permission: $permission');

      if (permission == LocationPermission.denied) {
        print('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        print('Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          _showStatusMessage(
            context,
            'Location permission denied. Cannot get location.',
            isError: true,
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showStatusMessage(
          context,
          'Location permissions permanently denied. Please enable in settings.',
          isError: true,
        );
        return null;
      }

      // Get last known position first to check if we have recent data
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      print('Last known position: $lastKnownPosition');

      if (lastKnownPosition != null) {
        // Check if last known position is recent (within 2 minutes for better performance)
        final timeDiff = DateTime.now().difference(lastKnownPosition.timestamp);
        if (timeDiff.inMinutes < 2) {
          print('Using recent last known position');
          _cachedPosition = lastKnownPosition;
          _lastLocationUpdate = DateTime.now();
          return lastKnownPosition;
        }
      }

      print(
        'Getting fresh location with medium accuracy for better performance...',
      );

      // Get current position with medium accuracy and shorter timeout for better performance
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy.medium, // Reduced from high for better performance
        timeLimit: const Duration(seconds: 15), // Reduced from 30 seconds
        forceAndroidLocationManager: false, // Use FusedLocationProviderClient
      );

      print('Got fresh position: ${position.latitude}, ${position.longitude}');
      print('Position accuracy: ${position.accuracy}m');
      print('Position timestamp: ${position.timestamp}');

      // Cache the position
      _cachedPosition = position;
      _lastLocationUpdate = DateTime.now();

      // Validate that we got a real position (not Google's test coordinates)
      if (position.latitude == 37.4219983 && position.longitude == -122.084) {
        print(
          'Got Google test coordinates, requesting fresh location with high accuracy...',
        );
        // Try again with high accuracy and longer timeout for real GPS
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 30), // Longer timeout for GPS
          forceAndroidLocationManager:
              false, // Use FusedLocationProviderClient for better accuracy
        );
        print(
          'Second attempt position: ${position.latitude}, ${position.longitude}',
        );

        // If still test coordinates, try one more time with different settings
        if (position.latitude == 37.4219983 && position.longitude == -122.084) {
          print(
            'Still getting test coordinates, trying with LocationManager...',
          );
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 45), // Even longer timeout
            forceAndroidLocationManager: true, // Force Android LocationManager
          );
          print(
            'Third attempt position: ${position.latitude}, ${position.longitude}',
          );
        }

        // Update cache with new position
        _cachedPosition = position;
        _lastLocationUpdate = DateTime.now();
      }

      return position;
    } catch (e) {
      print('Error getting current location: $e');
      _showStatusMessage(
        context,
        'Failed to get location. Please check GPS signal and permissions.',
        isError: true,
      );
      return null;
    }
  }

  Future<void> _sendSosToAWS(String category) async {
    try {
      // Show loading status while getting location
      _showStatusMessage(context, 'Getting your location...', isError: false);

      // Get current location automatically with retry mechanism
      Position? position = await _getCurrentLocation();

      // If we get Google test coordinates, try to get a real location
      if (position != null &&
          position.latitude == 37.4219983 &&
          position.longitude == -122.084) {
        print(
          'Got Google test coordinates, attempting to get real location...',
        );
        _showStatusMessage(
          context,
          'Getting your real location...',
          isError: false,
        );

        // Try to get location using multiple methods
        try {
          // Method 1: Try with best accuracy and longer timeout using FusedLocationProviderClient
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 45),
            forceAndroidLocationManager: false,
          );

          // If still test coordinates, try method 2 with LocationManager
          if (position.latitude == 37.4219983 &&
              position.longitude == -122.084) {
            print(
              'Still getting test coordinates, trying with LocationManager...',
            );
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 30),
              forceAndroidLocationManager: true,
            );
          }

          // If still test coordinates, try method 3 with medium accuracy but longer timeout
          if (position.latitude == 37.4219983 &&
              position.longitude == -122.084) {
            print(
              'Still getting test coordinates, trying with medium accuracy and extended timeout...',
            );
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 60),
              forceAndroidLocationManager: false,
            );
          }
        } catch (e) {
          print('Error getting alternative location: $e');
        }
      }

      if (position == null) {
        _showStatusMessage(
          context,
          'Error: Could not get location. Cannot send SOS.',
          isError: true,
        );
        return;
      }

      // Final check for test coordinates
      if (position.latitude == 37.4219983 && position.longitude == -122.084) {
        print(
          'Using Google test coordinates (default emulator location). This might be due to:',
        );
        print('1. Running on emulator without location set');
        print('2. GPS disabled on device');
        print('3. Location permissions not properly granted');
        print('4. Device in airplane mode or poor GPS signal');
        print('Continuing with SOS using default coordinates...');

        // Show a warning to the user about location accuracy
        _showStatusMessage(
          context,
          'Warning: Using default coordinates. Please enable GPS for accurate location.',
          isError: true,
        );
      }

      // Update status to show location obtained
      _showStatusMessage(
        context,
        'Location obtained. Getting address...',
        isError: false,
      );

      // Get detailed location information using Google Maps Geocoding API
      final locationDetails = await _getLocationDetailsFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Update status to show address obtained
      _showStatusMessage(
        context,
        'Address obtained. Sending SOS...',
        isError: false,
      );

      // Get current timestamp
      final currentTimestamp = DateTime.now();

      // Prepare SOS data with proper user info and detailed location
      final sosData = {
        'userId': _userId,
        'userName': _userName,
        'userEmail': _currentUserProfile?.email ?? 'demo@myselamat.com',
        'userAddress': _currentUserProfile?.address ?? 'Demo Address',
        'category': category,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'coordinates': locationDetails['coordinates'],
        'area': locationDetails['area'],
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': currentTimestamp.toIso8601String(),
        'status': 'active',
        'deviceInfo': {
          'platform': 'android', // You can make this dynamic
          'appVersion': '1.0.0',
        },
      };

      // Send SOS data based on configuration
      if (Config.useDemoMode) {
        // Simulate successful SOS sending for demo purposes
        print('DEMO MODE: SOS Data prepared: ${jsonEncode(sosData)}');
        await Future.delayed(const Duration(seconds: 2));
      } else {
        // Send to actual emergency services API
        print('Sending SOS to: ${Config.emergencyApiUrl}');
        final response = await http.post(
          Uri.parse('${Config.emergencyApiUrl}/sos'),
          headers: {
            'Content-Type': 'application/json',
            // Add authentication headers as needed
          },
          body: jsonEncode(sosData),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to send SOS: ${response.statusCode}');
        }
      }

      // For demo purposes, always succeed
      setState(() {
        _isSosActive = true;
        _showCategories = false;

        _sentCategory = category;
        _sentLocation = position;
        _sentTimestamp = currentTimestamp;
        _locationAddress = locationDetails['area'] ?? 'Unknown Location';
        _locationDetails = locationDetails;
      });

      // Start location updates every 5 minutes
      _startLocationUpdates();

      _showStatusMessage(
        context,
        'SOS sent to emergency services successfully!',
      );

      // Start the rescue sequence after SOS is successfully sent
      _startRescueSequence();
    } catch (e) {
      print('Error sending SOS: $e');
      _showStatusMessage(
        context,
        'Error sending SOS. Please try again.',
        isError: true,
      );
    }
  }

  void _startLocationUpdates() {
    // Optimized location updates with longer interval for better performance
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 10), (
      timer,
    ) async {
      if (!_isSosActive) {
        timer.cancel();
        return;
      }

      try {
        final position = await _getCurrentLocation();
        if (position != null) {
          // Update location on AWS
          final locationUpdate = {
            'userId': _userId,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          };

          // Send location update based on configuration
          if (Config.useDemoMode) {
            // Simulate location update for demo purposes
            print('DEMO MODE: Location update: ${jsonEncode(locationUpdate)}');
            await Future.delayed(const Duration(seconds: 1));
          } else {
            // Send to actual emergency services API
            final response = await http.post(
              Uri.parse('${Config.emergencyApiUrl}/location-update'),
              headers: {
                'Content-Type': 'application/json',
                // Add authentication headers as needed
              },
              body: jsonEncode(locationUpdate),
            );

            if (response.statusCode != 200) {
              print(
                'Failed to update location on server: ${response.statusCode}',
              );
              return;
            }
          }

          // Update UI with latest location (simulated success)
          setState(() {
            _sentLocation = position;
          });
          print(
            'Location updated successfully: ${DateTime.now()} - Lat: ${position.latitude}, Lng: ${position.longitude}',
          );
        } else {
          print('Failed to get location for update');
          // Show error to user if location fails multiple times
          if (mounted) {
            _showStatusMessage(
              context,
              'Warning: Unable to update location. Please check GPS signal.',
              isError: true,
            );
          }
        }
      } catch (e) {
        print('Error updating location: $e');
        if (mounted) {
          _showStatusMessage(
            context,
            'Error updating location. Please check your connection.',
            isError: true,
          );
        }
      }
    });
  }

  void _handleIncidentTap(String type) {
    _sendSosToAWS(type);
  }

  // --- Main Build Method for SOS Screen Content ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        toolbarHeight: 30.0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'SOS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: headerBarColor,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10.0),
          child: Container(height: 10.0, color: headerBarColor),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Status message area
            if (_currentStatus.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                margin: const EdgeInsets.only(bottom: 8.0),
                decoration: BoxDecoration(
                  color:
                      _isErrorStatus
                          ? Colors.red.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      _isErrorStatus
                          ? Border.all(color: Colors.red, width: 1)
                          : Border.all(color: Colors.green, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isErrorStatus ? Icons.close : Icons.check_circle,
                      color: _isErrorStatus ? Colors.red : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentStatus,
                        style: TextStyle(
                          color: _isErrorStatus ? Colors.red : Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_isSosActive)
                      TextButton(
                        onPressed: _markSafe,
                        child: const Text(
                          'Mark Safe',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            _buildSentSosDetails(),
            // "Choose your incident type" header (only show when categories are visible)
            if (_showCategories) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose your incident type',
                  style: TextStyle(fontSize: 12, color: primaryColor),
                ),
              ),
              const SizedBox(height: 8.0),
            ],

            const Text(
              'Emergency Request',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4.0),

            // Instruction text
            Text(
              _showCategories
                  ? 'Select your emergency type below'
                  : 'Press and hold for 3 seconds to send an alert with your live location',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryTextColor),
            ),
            const SizedBox(height: 16.0),

            // SOS Button Area
            _buildSosButton(context),
            const SizedBox(height: 12.0),

            // Keep holding message
            if (_isHolding) ...[
              Text(
                'Keep holding...',
                style: TextStyle(
                  fontSize: 14,
                  color: sosColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4.0),
              // Progress indicator
              Container(
                width: 150,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _holdProgress / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: sosColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
            ],

            // Category buttons (only show after 3-second hold) - 2x2 grid
            if (_showCategories) ...[
              // First row: Trapped in Building + Medical Emergency
              Row(
                children: [
                  Expanded(
                    child: _buildIncidentButton(
                      icon: Icons.apartment,
                      label: 'Trapped in Building',
                      onPressed:
                          () => _handleIncidentTap('Trapped in Building'),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: _buildIncidentButton(
                      icon: Icons.medical_services_outlined,
                      label: 'Medical Emergency',
                      onPressed: () => _handleIncidentTap('Medical Emergency'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              // Second row: Flooded Area + Fire/Explosion
              Row(
                children: [
                  Expanded(
                    child: _buildIncidentButton(
                      icon: Icons.waves,
                      label: 'Flooded Area',
                      onPressed: () => _handleIncidentTap('Flooded Area'),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: _buildIncidentButton(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Fire / Explosion',
                      onPressed: () => _handleIncidentTap('Fire / Explosion'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              // Push to Talk button with different styling
              _buildPushToTalkButton(),
            ],
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildSosButton(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _onSosDown(context, details),
      onTapUp: (details) => _onSosUp(context, details),
      onTapCancel: _onSosCancel,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isHolding ? _pulseAnimation.value * _sosScale : _sosScale,
            child: Container(
              width: _sosButtonSize,
              height: _sosButtonSize,
              decoration: BoxDecoration(
                color: sosColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: sosColor.withOpacity(_isHolding ? 0.8 : 0.5),
                    blurRadius: _isHolding ? 30 : 20,
                    spreadRadius: _isHolding ? 10 : 5,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress ring - Only rebuild when holding
                  if (_isHolding)
                    SizedBox(
                      width: _progressRingSize,
                      height: _progressRingSize,
                      child: CircularProgressIndicator(
                        value: _holdProgress / 100,
                        strokeWidth: 4,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xCCFFFFFF), // Pre-calculated opacity
                        ),
                        backgroundColor: const Color(
                          0x33FFFFFF,
                        ), // Pre-calculated opacity
                      ),
                    ),
                  // SOS text - Static widget for better performance
                  const Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncidentButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  Widget _buildPushToTalkButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.mic, color: Colors.white, size: 18),
      label: const Text(
        'Push to Talk',
        style: TextStyle(fontSize: 12, color: Colors.white),
      ),
      onPressed: () => _handleIncidentTap('Push to Talk'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(
            color: Colors.orange,
            width: 2,
          ), // Different border
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildSentSosDetails() {
    if (!_isSosActive ||
        _sentLocation == null ||
        _sentTimestamp == null ||
        _sentCategory == null) {
      return const SizedBox.shrink(); // Hide if SOS is not active or data is missing
    }

    // Format the time for display
    final String timeText =
        '${_sentTimestamp!.hour.toString().padLeft(2, '0')}:${_sentTimestamp!.minute.toString().padLeft(2, '0')}:${_sentTimestamp!.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Card(
        color: Colors.white12, // Dark background for contrast
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Current Active Alert',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Divider(color: Colors.white30),

              _buildDetailRow(
                icon: Icons.person_outline,
                label: 'User',
                value: _userName,
                color: Colors.white,
              ),
              _buildDetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _currentUserProfile?.email ?? 'demo@myselamat.com',
                color: Colors.white70,
              ),
              _buildDetailRow(
                icon: Icons.warning_amber_rounded,
                label: 'Incident',
                value: _sentCategory!,
                color: sosColor,
              ),

              // Display coordinates
              if (_locationDetails != null) ...[
                _buildDetailRow(
                  icon: Icons.gps_fixed,
                  label: 'Coordinates',
                  value: _locationDetails!['coordinates'] ?? 'Unknown',
                  color: Colors.cyan,
                ),

                // Display area as separate field
                if (_locationDetails!['area'] != null &&
                    _locationDetails!['area']!.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.location_city,
                    label: 'Area',
                    value: _locationDetails!['area']!,
                    color: Colors.orange,
                  ),

                // Display state as separate field (only if state exists)
                if (_locationDetails!['state'] != null &&
                    _locationDetails!['state']!.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.public,
                    label: 'State',
                    value: _locationDetails!['state']!,
                    color: Colors.blue,
                  ),
              ] else ...[
                // Fallback to basic location display
                _buildDetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value:
                      _locationAddress ??
                      'Lat: ${_sentLocation!.latitude.toStringAsFixed(4)}, Lng: ${_sentLocation!.longitude.toStringAsFixed(4)}',
                  color: secondaryTextColor,
                ),
              ],

              _buildDetailRow(
                icon: Icons.access_time_outlined,
                label: 'Time',
                value: timeText,
                color: secondaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withOpacity(0.8)),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
