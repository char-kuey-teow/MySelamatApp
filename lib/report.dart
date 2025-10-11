import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
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

  // Photo state
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  // Location state
  bool _isGettingLocation = false;
  String _locationStatus = '';

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
  void initState() {
    super.initState();
    _getCurrentLocationAndAddress();
  }

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

  Future<void> _pickImage() async {
    try {
      // Check storage permission first
      final permission = await Permission.photos.request();
      if (!permission.isGranted) {
        _showStatusMessage('Storage permission is required to select photos.', isError: true);
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        _showStatusMessage('Photo selected successfully', isError: false);
      }
    } catch (e) {
      print('Error picking image: $e');
      _showStatusMessage('Error selecting image. Please check permissions and try again.', isError: true);
    }
  }

  Future<void> _takePhoto() async {
    try {
      // Check camera permission first
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        _showStatusMessage('Camera permission is required to take photos.', isError: true);
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        _showStatusMessage('Photo taken successfully', isError: false);
      }
    } catch (e) {
      print('Error taking photo: $e');
      _showStatusMessage('Error taking photo. Please check camera permissions and try again.', isError: true);
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
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

      // Upload photo first if selected
      String? photoUrl;
      if (_selectedImage != null) {
        _showStatusMessage('Uploading photo...', isError: false);
        photoUrl = await S3Service.uploadPhoto(_selectedImage!, 'user_123');
        if (photoUrl == null) {
          _showStatusMessage('Photo upload failed, but continuing with report...', isError: true);
        } else {
          _showStatusMessage('Photo uploaded successfully', isError: false);
        }
      }

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
        'photoUrl': photoUrl, // Include photo URL if uploaded
        'hasPhoto': _selectedImage != null,
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

  Future<void> _getCurrentLocationAndAddress() async {
    setState(() {
      _isGettingLocation = true;
      _locationStatus = 'Getting your location...';
    });

    try {
      final permission = await Permission.location.request();
      if (permission.isGranted) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        // Get address from coordinates
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          String address = '';
          
          // Build address from placemark components
          if (place.locality?.isNotEmpty == true) {
            address += place.locality!;
          }
          if (place.administrativeArea?.isNotEmpty == true) {
            if (address.isNotEmpty) address += ', ';
            address += place.administrativeArea!;
          }
          
          setState(() {
            _locationController.text = address.isNotEmpty ? address : 'Location detected';
            _locationStatus = 'Location detected successfully';
          });
        } else {
          setState(() {
            _locationController.text = 'Location detected';
            _locationStatus = 'Location detected (address unavailable)';
          });
        }
      } else {
        setState(() {
          _locationController.text = 'Location permission denied';
          _locationStatus = 'Please enable location permissions';
        });
      }
    } catch (e) {
      print('Error getting location and address: $e');
      setState(() {
        _locationController.text = 'Unable to get location';
        _locationStatus = 'Location service unavailable';
      });
    } finally {
      setState(() {
        _isGettingLocation = false;
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
      _selectedImage = null;
      _locationController.clear();
    });
    // Re-get location after form reset
    _getCurrentLocationAndAddress();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
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
            const SizedBox(height: 20.0),

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
              const SizedBox(height: 20.0),
            ],

            // Photo Upload Section
            const Text(
              'Photo Evidence',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12.0),
            _buildPhotoSection(),
            const SizedBox(height: 20.0),

            // Location Section
            Row(
              children: [
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isGettingLocation ? null : _getCurrentLocationAndAddress,
                  icon: _isGettingLocation 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                  label: Text(
                    _isGettingLocation ? 'Getting...' : 'Refresh',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _locationController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Getting your location...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: const Icon(Icons.location_on, color: primaryBlue),
                suffixIcon: _isGettingLocation 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
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
            if (_locationStatus.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _locationStatus,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 24.0),

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

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedImage == null) ...[
          // Photo selection buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Take Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Choose Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo,
                  size: 40,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'No photo selected',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Photo evidence is recommended',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Selected image preview
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Retake'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Change'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
