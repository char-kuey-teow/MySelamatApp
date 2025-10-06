import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'services/s3_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Form state
  String _selectedDisasterType = 'Flood';
  String? _selectedWaterLevel;
  final TextEditingController _locationController = TextEditingController();

  // UI state
  bool _isSubmitting = false;
  String _submitStatus = '';
  bool _isError = false;

  // Colors
  static const Color primaryBlue = Color(0xFF2254C5);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color dangerRed = Color(0xFFF44336);

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _selectDisasterType(String type) {
    setState(() {
      _selectedDisasterType = type;
      // Reset water level when changing disaster type
      if (type != 'Flood') {
        _selectedWaterLevel = null;
      }
    });
  }

  void _selectWaterLevel(String level) {
    setState(() {
      _selectedWaterLevel = level;
    });
  }

  Future<void> _submitReport() async {
    if (_locationController.text.trim().isEmpty) {
      _showStatusMessage('Please enter a location', isError: true);
      return;
    }

    if (_selectedDisasterType == 'Flood' && _selectedWaterLevel == null) {
      _showStatusMessage('Please select a water level', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitStatus = 'Submitting report...';
      _isError = false;
    });

    try {
      // Get current location
      final position = await _getCurrentLocation();

      // Prepare report data
      final reportData = {
        'disasterType': _selectedDisasterType,
        'waterLevel': _selectedWaterLevel,
        'location': _locationController.text.trim(),
        'userLatitude': position?.latitude,
        'userLongitude': position?.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'userId': 'user_123', // In real app, get from authentication
        'userName': 'John Doe', // In real app, get from user profile
      };

      // Test AWS credentials first
      print('Testing AWS credentials...');
      final credentialTest = await S3Service.testCredentials();
      if (!credentialTest) {
        _showStatusMessage('AWS credentials failed. Please check AWS configuration.', isError: true);
        return;
      }

      // Test S3 connection
      print('Testing S3 connection...');
      final connectionTest = await S3Service.testConnection();
      if (!connectionTest) {
        _showStatusMessage('S3 connection failed. Please check bucket permissions.', isError: true);
        return;
      }

      // Send to AWS S3
      final success = await S3Service.uploadReport(reportData);

      if (success) {
        _showStatusMessage('Report submitted successfully!', isError: false);
        // Reset form after successful submission
        _resetForm();
      } else {
        _showStatusMessage(
          'Failed to submit report. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      print('Error submitting report: $e');
      _showStatusMessage(
        'Error submitting report. Please try again.',
        isError: true,
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
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
      print('Error getting location: $e');
    }
    return null;
  }

  void _showStatusMessage(String message, {required bool isError}) {
    setState(() {
      _submitStatus = message;
      _isError = isError;
    });

    // Clear status after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _submitStatus = '';
        });
      }
    });
  }

  void _resetForm() {
    setState(() {
      _selectedDisasterType = 'Flood';
      _selectedWaterLevel = null;
      _locationController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 30.0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Report',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status message
            if (_submitStatus.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                decoration: BoxDecoration(
                  color:
                      _isError
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isError ? Colors.red : Colors.green,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isError ? Icons.error : Icons.check_circle,
                      color: _isError ? Colors.red : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _submitStatus,
                        style: TextStyle(
                          color: _isError ? Colors.red : Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Disaster Type Section
            const Text(
              'Disaster Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(child: _buildDisasterTypeButton('Flood', primaryBlue)),
                const SizedBox(width: 8.0),
                Expanded(
                  child: _buildDisasterTypeButton('Earthquake', primaryBlue),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: _buildDisasterTypeButton('Landslide', primaryBlue),
                ),
              ],
            ),
            const SizedBox(height: 24.0),

            // Water Level Section (only show for Flood)
            if (_selectedDisasterType == 'Flood') ...[
              const Text(
                'Water level',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(child: _buildWaterLevelButton('Low', primaryBlue)),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: _buildWaterLevelButton('Medium', warningOrange),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(child: _buildWaterLevelButton('High', dangerRed)),
                ],
              ),
              const SizedBox(height: 24.0),
            ],

            // Location Section
            const Text(
              'Flood location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'District, State (e.g., Shah Alam, Selangor)',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryBlue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 32.0),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: successGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child:
                    _isSubmitting
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Report',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisasterTypeButton(String type, Color color) {
    final isSelected = _selectedDisasterType == type;
    return GestureDetector(
      onTap: () => _selectDisasterType(type),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            type,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaterLevelButton(String level, Color color) {
    final isSelected = _selectedWaterLevel == level;
    return GestureDetector(
      onTap: () => _selectWaterLevel(level),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            level,
            style: TextStyle(
              color: isSelected ? color : Colors.black,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }
}
