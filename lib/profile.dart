import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_image_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';
import 'firebase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  bool _isLoggedIn = false;
  User? _firebaseUser;
  UserProfile? _userProfile;
  bool _isLoading = false;

  // Form controllers
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _regionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  // Performance optimization: Cache frequently used values
  static const Duration _loadingTimeout = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _setupAuthListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh login status when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshLoginStatus();
      }
    });
  }

  void _setupAuthListener() {
    _authService.authStateChanges.listen((User? user) {
      if (mounted) {
        setState(() {
          _firebaseUser = user;
          _isLoggedIn = user != null;
        });

        if (user != null) {
          _loadUserProfile();
        } else {
          // Only clear data if we're not in demo mode
          _checkDemoModeBeforeClearing();
        }
      }
    });
  }

  Future<void> _checkDemoModeBeforeClearing() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) {
      // Not in demo mode either, clear the data
      _clearUserData();
    }
    // If in demo mode, keep the logged in state
  }

  Future<void> _refreshLoginStatus() async {
    // Only refresh if we're not already logged in
    if (!_isLoggedIn) {
      await _checkLoginStatus();
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    for (var controller in _regionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Add timeout to prevent hanging
      await Future.any([
        _performLoginCheck(),
        Future.delayed(
          _loadingTimeout,
          () => throw TimeoutException('Login check timeout', _loadingTimeout),
        ),
      ]);
    } catch (e) {
      print('Error checking login status: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to check login status');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performLoginCheck() async {
    // Check Firebase auth state first
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      if (mounted) {
        setState(() {
          _firebaseUser = currentUser;
          _isLoggedIn = true;
        });
        await _loadUserProfile();
      }
    } else {
      // Check SharedPreferences for demo mode
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (isLoggedIn && mounted) {
        final userData = prefs.getString('userProfile');
        if (userData != null) {
          final userMap = jsonDecode(userData);
          setState(() {
            _isLoggedIn = true; // Ensure this is set for demo mode
            _userProfile = UserProfile.fromJson(userMap);
            _addressController.text = _userProfile!.address;
            _phoneController.text = _userProfile!.phoneNumber;
            for (
              int i = 0;
              i < _userProfile!.floodRegions.length && i < 5;
              i++
            ) {
              _regionControllers[i].text = _userProfile!.floodRegions[i];
            }
          });
        } else {
          // Demo mode flag exists but no profile data, set logged in state anyway
          setState(() {
            _isLoggedIn = true;
          });
        }
      } else {
        // Not logged in via Firebase or demo mode
        setState(() {
          _isLoggedIn = false;
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('userProfile');

      if (userData != null && mounted) {
        final userMap = jsonDecode(userData);
        setState(() {
          _userProfile = UserProfile.fromJson(userMap);
          _addressController.text = _userProfile!.address;
          _phoneController.text = _userProfile!.phoneNumber;
          for (int i = 0; i < _userProfile!.floodRegions.length && i < 5; i++) {
            _regionControllers[i].text = _userProfile!.floodRegions[i];
          }
        });
      } else if (_firebaseUser != null && mounted) {
        // User is authenticated but no profile data - show additional info form
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showAdditionalInfoForm();
          }
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load user profile');
      }
    }
  }

  void _clearUserData() {
    setState(() {
      _userProfile = null;
      _addressController.clear();
      _phoneController.clear();
      for (var controller in _regionControllers) {
        controller.clear();
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Add timeout to prevent hanging
      final userCredential = await Future.any([
        _authService.signInWithGoogle(context),
        Future.delayed(
          _loadingTimeout,
          () =>
              throw TimeoutException('Google Sign-In timeout', _loadingTimeout),
        ),
      ]);

      if (userCredential != null && mounted) {
        final user = userCredential.user;
        print('Firebase Google Sign-In successful: ${user?.email}');

        setState(() {
          _firebaseUser = user;
          _isLoggedIn = true;
        });

        // Check if user already has profile data
        final prefs = await SharedPreferences.getInstance();
        final userData = prefs.getString('userProfile');

        if (userData != null && mounted) {
          // User has existing profile, load it
          final userMap = jsonDecode(userData);
          setState(() {
            _userProfile = UserProfile.fromJson(userMap);
            _addressController.text = _userProfile!.address;
            _phoneController.text = _userProfile!.phoneNumber;
            for (
              int i = 0;
              i < _userProfile!.floodRegions.length && i < 5;
              i++
            ) {
              _regionControllers[i].text = _userProfile!.floodRegions[i];
            }
          });
          _showSuccessSnackBar('Welcome back, ${user?.displayName ?? 'User'}!');
        } else if (mounted) {
          // User needs to fill additional info
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showAdditionalInfoForm();
            }
          });
        }
      }
    } catch (error) {
      print('Error signing in with Google: $error');
      if (mounted) {
        if (error is TimeoutException) {
          _showErrorSnackBar('Sign-in timed out. Please try again.');
        } else {
          _showErrorSnackBar('Failed to sign in with Google');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInDemo() async {
    setState(() => _isLoading = true);

    try {
      // Create a demo user profile
      final demoProfile = UserProfile(
        id: 'demo_user_123',
        email: 'demo@myselamat.com',
        displayName: 'Demo User',
        photoUrl: null,
        phoneNumber: '+60 12-345-6789',
        address: 'Bukit Jalil, Kuala Lumpur',
        floodRegions: ['Kuala Lumpur', 'Selangor'],
      );

      // Save demo profile
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userProfile', jsonEncode(demoProfile.toJson()));

      setState(() {
        _isLoggedIn = true;
        _userProfile = demoProfile;
        _addressController.text = demoProfile.address;
        _phoneController.text = demoProfile.phoneNumber;
        for (int i = 0; i < demoProfile.floodRegions.length && i < 5; i++) {
          _regionControllers[i].text = demoProfile.floodRegions[i];
        }
      });

      _showSuccessSnackBar('Demo mode activated!');
    } catch (error) {
      print('Error in demo mode: $error');
      _showErrorSnackBar('Failed to activate demo mode');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithCognito() async {
    try {
      const url = 'https://cognitoedu.org/login';
      final Uri cognitoUri = Uri.parse(url);
      
      if (await canLaunchUrl(cognitoUri)) {
        await launchUrl(cognitoUri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not open Cognito login page');
      }
    } catch (error) {
      print('Error opening Cognito login: $error');
      _showErrorSnackBar('Failed to open Cognito login page');
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signOut(context);

      // Clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      setState(() {
        _isLoggedIn = false;
        _firebaseUser = null;
        _userProfile = null;
        _addressController.clear();
        _phoneController.clear();
        for (var controller in _regionControllers) {
          controller.clear();
        }
      });
    } catch (error) {
      print('Error signing out: $error');
      _showErrorSnackBar('Failed to sign out');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAdditionalInfoForm() {
    if (_firebaseUser != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder:
            (context) => AdditionalInfoForm(
              firebaseUser: _firebaseUser!,
              onSave: _saveUserProfile,
            ),
      );
    }
  }

  Future<void> _saveUserProfile(UserProfile profile) async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userProfile', jsonEncode(profile.toJson()));

      setState(() {
        _userProfile = profile;
        _addressController.text = profile.address;
        _phoneController.text = profile.phoneNumber;
        for (int i = 0; i < profile.floodRegions.length && i < 5; i++) {
          _regionControllers[i].text = profile.floodRegions[i];
        }
      });

      _showSuccessSnackBar('Profile saved successfully!');
    } catch (error) {
      print('Error saving profile: $error');
      _showErrorSnackBar('Failed to save profile');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _editPhoneNumber() {
    final controller = TextEditingController(
      text: _userProfile!.phoneNumberOrEmpty,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Phone Number'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Enter your phone number (e.g., +60 12-345 6789)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updatePhoneNumber(controller.text.trim());
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _editAddress() {
    final controller = TextEditingController(text: _userProfile!.address);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Address'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter your address',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  _updateAddress(controller.text.trim());
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updatePhoneNumber(String newPhoneNumber) async {
    setState(() => _isLoading = true);

    try {
      final updatedProfile = UserProfile(
        id: _userProfile!.id,
        email: _userProfile!.email,
        displayName: _userProfile!.displayName,
        photoUrl: _userProfile!.photoUrl,
        phoneNumber: newPhoneNumber,
        address: _userProfile!.address,
        floodRegions: _userProfile!.floodRegions,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userProfile', jsonEncode(updatedProfile.toJson()));

      // Debug: Verify the data was saved
      final savedData = prefs.getString('userProfile');
      print('Phone number updated and saved to SharedPreferences: $savedData');

      setState(() {
        _userProfile = updatedProfile;
      });

      _showSuccessSnackBar('Phone number updated successfully!');
    } catch (error) {
      print('Error updating phone number: $error');
      _showErrorSnackBar('Failed to update phone number');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAddress(String newAddress) async {
    setState(() => _isLoading = true);

    try {
      final updatedProfile = UserProfile(
        id: _userProfile!.id,
        email: _userProfile!.email,
        displayName: _userProfile!.displayName,
        photoUrl: _userProfile!.photoUrl,
        phoneNumber: _userProfile!.phoneNumber,
        address: newAddress,
        floodRegions: _userProfile!.floodRegions,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userProfile', jsonEncode(updatedProfile.toJson()));

      // Debug: Verify the data was saved
      final savedData = prefs.getString('userProfile');
      print('Address updated and saved to SharedPreferences: $savedData');

      setState(() {
        _userProfile = updatedProfile;
        _addressController.text = newAddress;
      });

      _showSuccessSnackBar('Address updated successfully!');
    } catch (error) {
      print('Error updating address: $error');
      _showErrorSnackBar('Failed to update address');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addNewRegion() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Region'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter region name (e.g., Shah Alam, Selangor)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  _addRegion(controller.text.trim());
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addRegion(String newRegion) async {
    setState(() => _isLoading = true);

    try {
      final updatedRegions = List<String>.from(_userProfile!.floodRegions);
      updatedRegions.add(newRegion);

      final updatedProfile = UserProfile(
        id: _userProfile!.id,
        email: _userProfile!.email,
        displayName: _userProfile!.displayName,
        photoUrl: _userProfile!.photoUrl,
        phoneNumber: _userProfile!.phoneNumber,
        address: _userProfile!.address,
        floodRegions: updatedRegions,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userProfile', jsonEncode(updatedProfile.toJson()));

      // Debug: Verify the data was saved
      final savedData = prefs.getString('userProfile');
      print('Region added and saved to SharedPreferences: $savedData');

      setState(() {
        _userProfile = updatedProfile;
      });

      _showSuccessSnackBar('Region added successfully!');
    } catch (error) {
      print('Error adding region: $error');
      _showErrorSnackBar('Failed to add region');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRegion(int index) async {
    setState(() => _isLoading = true);

    try {
      final updatedRegions = List<String>.from(_userProfile!.floodRegions);
      updatedRegions.removeAt(index);

      final updatedProfile = UserProfile(
        id: _userProfile!.id,
        email: _userProfile!.email,
        displayName: _userProfile!.displayName,
        photoUrl: _userProfile!.photoUrl,
        phoneNumber: _userProfile!.phoneNumber,
        address: _userProfile!.address,
        floodRegions: updatedRegions,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userProfile', jsonEncode(updatedProfile.toJson()));

      // Debug: Verify the data was saved
      final savedData = prefs.getString('userProfile');
      print('Region deleted and saved to SharedPreferences: $savedData');

      setState(() {
        _userProfile = updatedProfile;
      });

      _showSuccessSnackBar('Region deleted successfully!');
    } catch (error) {
      print('Error deleting region: $error');
      _showErrorSnackBar('Failed to delete region');
    } finally {
      setState(() => _isLoading = false);
    }
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
          'Profile',
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2254C5)),
        ),
      );
    }

    if (_isLoggedIn && _userProfile != null) {
      return _buildProfileView();
    }

    return _buildLoginPrompt();
  }

  Widget _buildLoginPrompt() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'Sign in to MySelamat',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Access personalized flood warnings and emergency features',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Firebase Status Indicator
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_done,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Firebase Connected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _signInWithGoogle,
              icon: Image.asset(
                'assets/images/google_logo.png',
                height: 24,
                width: 24,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.login, color: Colors.white);
                },
              ),
              label: const Text(
                'Sign in with Google',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2254C5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _signInWithCognito,
              icon: const Icon(Icons.cloud, color: Color(0xFF2254C5)),
              label: const Text(
                'Sign in with AWS Cognito',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2254C5),
                side: const BorderSide(color: Color(0xFF2254C5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _signInDemo,
              icon: const Icon(Icons.person_add, color: Color(0xFF2254C5)),
              label: const Text(
                'Continue with Demo Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2254C5),
                side: const BorderSide(color: Color(0xFF2254C5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sign in with Google, AWS Cognito, or use Demo Mode for testing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Header - Made Smaller and Centered
          Center( // <--- 1. Center the entire square horizontally in the main column
            child: FractionallySizedBox( // <--- 2. Constrain the size (e.g., 70% of screen width)
              widthFactor: 0.6, // 70% of the parent's width
              child: AspectRatio(
                aspectRatio: 1.0, // Ensures it remains a square
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), // Reduced padding for a smaller square
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, // <--- 3. Center contents vertically
                      crossAxisAlignment: CrossAxisAlignment.center, // Already centered horizontally
                      children: [
                        CircleAvatar(
                          radius: 40, // Reduced radius to fit a smaller square
                          backgroundImage:
                              _userProfile!.photoUrl != null
                                  ? NetworkImage(_userProfile!.photoUrl!)
                                  : null,
                          child:
                              _userProfile!.photoUrl == null
                                  ? const Icon(Icons.person, size: 40) // Reduced icon size
                                  : null,
                        ),
                        const SizedBox(height: 8), // Reduced spacing
                        Text(
                          _userProfile!.displayName,
                          style: const TextStyle(
                            fontSize: 20, // Reduced font size
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _userProfile!.email,
                          style: const TextStyle(fontSize: 14, color: Colors.grey), // Reduced font size
                        ),
                        const SizedBox(height: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _userProfile!.hasPhoneNumber
                                  ? _userProfile!.phoneNumber
                                  : 'No phone number',
                              style: TextStyle(
                                fontSize: 14, // Reduced font size
                                color:
                                    _userProfile!.hasPhoneNumber
                                        ? Colors.grey
                                        : Colors.grey.shade400,
                                fontStyle:
                                    _userProfile!.hasPhoneNumber
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _editPhoneNumber,
                              child: Icon(
                                Icons.edit,
                                size: 12, // Reduced icon size
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          
          const SizedBox(height: 20),

          // Address Section
          _buildInfoSection(
            'Address',
            _userProfile!.address,
            Icons.location_on,
          ),
          const SizedBox(height: 12),

          // Flood Warning Regions
          _buildFloodRegionsSection(),
          const SizedBox(height: 24),

          // Sign Out Button
          // Debug section
          const SizedBox(height: 16),
          const Text(
            'Debug Tools',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TestImageScreen()),
                );
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Generate Test Images'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String value, IconData icon) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(icon, color: const Color(0xFF2254C5)),
                const SizedBox(width: 8),
                Text(
                  title,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _editAddress(),
                  icon: const Icon(
                    Icons.edit,
                    size: 20,
                    color: Color(0xFF2254C5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloodRegionsSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(Icons.warning, color: Color(0xFF2254C5)),
                const SizedBox(width: 10),
                const Text(
                  'Subscribed Flood Warning Region',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._userProfile!.floodRegions.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_city,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteRegion(entry.key),
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (_userProfile!.floodRegions.length < 5)
              ElevatedButton.icon(
                onPressed: _addNewRegion,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Region'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2254C5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 36),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AdditionalInfoForm extends StatefulWidget {
  final User firebaseUser;
  final Function(UserProfile) onSave;

  const AdditionalInfoForm({
    super.key,
    required this.firebaseUser,
    required this.onSave,
  });

  @override
  State<AdditionalInfoForm> createState() => _AdditionalInfoFormState();
}

class _AdditionalInfoFormState extends State<AdditionalInfoForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final List<TextEditingController> _regionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int _regionCount = 1;

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    for (var controller in _regionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addRegion() {
    if (_regionCount < 5) {
      setState(() {
        _regionCount++;
      });
    }
  }

  void _removeRegion(int index) {
    if (_regionCount > 1) {
      setState(() {
        _regionControllers[index].clear();
        _regionCount--;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final regions =
          _regionControllers
              .take(_regionCount)
              .map((controller) => controller.text.trim())
              .where((text) => text.isNotEmpty)
              .toList();

      final profile = UserProfile(
        id: widget.firebaseUser.uid,
        email: widget.firebaseUser.email ?? '',
        displayName: widget.firebaseUser.displayName ?? 'User',
        photoUrl: widget.firebaseUser.photoURL,
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        floodRegions: regions,
      );

      widget.onSave(profile);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      widget.firebaseUser.photoURL != null
                          ? NetworkImage(widget.firebaseUser.photoURL!)
                          : null,
                  child:
                      widget.firebaseUser.photoURL == null
                          ? const Icon(Icons.person, size: 30)
                          : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome, ${widget.firebaseUser.displayName ?? 'User'}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please provide additional information for personalized flood warnings',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Address Field
                    const Text(
                      'Your Address',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      textAlign: TextAlign.center,
                      controller: _addressController,
                      decoration: InputDecoration(
                        hintText: 'Enter your full address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Phone Number Field
                    const Text(
                      'Phone Number',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      textAlign: TextAlign.center,
                      controller: _phoneController,
                      decoration: InputDecoration(
                        hintText: 'Enter your phone number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Flood Warning Regions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Flood Warning Regions',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_regionCount < 5) ...[
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: _addRegion,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Region'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add up to 5 regions to receive flood warnings',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // Region Fields
                    ...List.generate(_regionCount, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextFormField(
                                textAlign: TextAlign.center,
                                controller: _regionControllers[index],
                                decoration: InputDecoration(
                                  hintText:
                                      'Region ${index + 1} (e.g., Shah Alam, Selangor)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.location_city),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter region ${index + 1}';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (_regionCount > 1)
                              IconButton(
                                onPressed: () => _removeRegion(index),
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.red,
                              ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2254C5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String phoneNumber;
  final String address;
  final List<String> floodRegions;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.phoneNumber,
    required this.address,
    required this.floodRegions,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'address': address,
      'floodRegions': floodRegions,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? 'User',
      photoUrl: json['photoUrl'],
      phoneNumber: json['phoneNumber'] ?? '',
      address: json['address'] ?? '',
      floodRegions: List<String>.from(json['floodRegions'] ?? []),
    );
  }

  // Helper method to get phone number safely
  String get phoneNumberOrEmpty => phoneNumber;
  bool get hasPhoneNumber => phoneNumber.isNotEmpty;
}
