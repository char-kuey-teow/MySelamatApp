import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for vibration/haptic feedback
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  // Animation Controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Status tracking
  String _currentStatus = '';
  bool _isSosActive = false;
  Timer? _locationUpdateTimer;
  bool _isErrorStatus = false;
  //submission data
  String? _sentCategory;
  Position? _sentLocation;
  DateTime? _sentTimestamp;

  // Location and user data
  String _userId =
      'user_123'; // In a real app, this would come from authentication
  String _userName =
      'John Doe'; // In a real app, this would come from user profile

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize location services
    _initializeLocation();
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

    _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isSosPressed) {
        timer.cancel();
        _resetSosState();
        return;
      }

      setState(() {
        _holdProgress =
            ((timer.tick * 100) / (_holdDuration.inMilliseconds / 100)).round();
      });

      if (timer.tick >= (_holdDuration.inMilliseconds / 100).round()) {
        // 3 seconds
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

  void _showStatusMessage(BuildContext context, String message, {bool isError = false}) {
    setState(() {
      _currentStatus = message;
      _isErrorStatus = isError;
    });

    if (!isError) {
    // Simulate status updates with longer delays
    Timer(const Duration(seconds: 20), () {
      if (mounted && !_isErrorStatus) { // Only update if still on success path
        setState(() {
          _currentStatus = 'Rescue on the way';
        });
      }
    });

    Timer(const Duration(seconds: 40), () {
      if (mounted && !_isErrorStatus) { // Only update if still on success path
        setState(() {
          _currentStatus = 'Reached';
        });
      }
    });
  }

  }

  void _markSafe() {
    setState(() {
      _isSosActive = false;
      _currentStatus = '';

      _sentCategory = null;
      _sentLocation = null;
      _sentTimestamp = null;
    });
    _locationUpdateTimer?.cancel();
  }

  // Location and AWS Integration Methods
  Future<void> _initializeLocation() async {
    // Request location permissions
    final permission = await Permission.location.request();
    if (permission.isGranted) {
      try {
        await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (e) {
        print('Error getting location: $e');
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      final permission = await Permission.location.request();
      if (permission.isGranted) {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
    return null;
  }

  Future<void> _sendSosToAWS(String category) async {
    try {
      // Get current location
      final position = await _getCurrentLocation();
      if (position == null) {
      _showStatusMessage(context, 'Error: Could not get location. Cannot send SOS.', isError: true);
      return;
    }

      // Prepare SOS data
      final sosData = {
        'userId': _userId,
        'userName': _userName,
        'category': category,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'active',
      };

      // Send to AWS (simulated with HTTP request)
      final response = await http.post(
        Uri.parse('https://your-aws-api-gateway-url/sos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer your-auth-token', // In real app, get from AWS Cognito
        },
        body: jsonEncode(sosData),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isSosActive = true;
          _showCategories = false;

          _sentCategory = category;
          _sentLocation = position;
          _sentTimestamp = DateTime.now();
        });

        // Start location updates every 5 minutes
        _startLocationUpdates();

        _showStatusMessage(context, 'SOS sent to emergency services');
      } else {
        _showStatusMessage(context, 'Error sending SOS. Please try again.', isError: true);
      }
    } catch (e) {
      print('Error sending SOS to AWS: $e');
      _showStatusMessage(context, 'Error sending SOS. Please try again.', isError: true);
    }
  }

  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 5), (
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

          await http.post(
            Uri.parse('https://your-aws-api-gateway-url/location-update'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer your-auth-token',
            },
            body: jsonEncode(locationUpdate),
          );

          // Update UI if needed
          setState(() {});

          print(
            'Location updated: ${DateTime.now()} - Lat: ${position.latitude}, Lng: ${position.longitude}',
          );
        }
      } catch (e) {
        print('Error updating location: $e');
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
                  color: _isErrorStatus ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: _isErrorStatus ? Border.all(color: Colors.red, width: 1) : Border.all(color: Colors.green, width: 1),
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
              width: 180,
              height: 180,
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
                  // Progress ring
                  if (_isHolding)
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: _holdProgress / 100,
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.8),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  // SOS text
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

    // Format the location and time for display
    final String locationText =
        'Lat: ${_sentLocation!.latitude.toStringAsFixed(4)}, Lng: ${_sentLocation!.longitude.toStringAsFixed(4)}';

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
                icon: Icons.warning_amber_rounded,
                label: 'Incident',
                value: _sentCategory!,
                color: sosColor,
              ),
              _buildDetailRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: locationText,
                color: secondaryTextColor,
              ),
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
