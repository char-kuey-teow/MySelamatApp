import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  bool _isLoggedIn = false;
  GoogleSignInAccount? _currentUser;
  UserProfile? _userProfile;
  bool _isLoading = false;

  // Form controllers
  final TextEditingController _addressController = TextEditingController();
  final List<TextEditingController> _regionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _addressController.dispose();
    for (var controller in _regionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (isLoggedIn) {
        final userData = prefs.getString('userProfile');
        if (userData != null) {
          final userMap = jsonDecode(userData);
          setState(() {
            _isLoggedIn = true;
            _userProfile = UserProfile.fromJson(userMap);
            _addressController.text = _userProfile!.address;
            for (
              int i = 0;
              i < _userProfile!.floodRegions.length && i < 5;
              i++
            ) {
              _regionControllers[i].text = _userProfile!.floodRegions[i];
            }
          });
        } else {
          // User is logged in but no profile data - try to get current user
          try {
            final currentUser = await _googleSignIn.signInSilently();
            if (currentUser != null) {
              setState(() {
                _currentUser = currentUser;
                _isLoggedIn = true;
              });
              // Show additional info form
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showAdditionalInfoForm();
              });
            } else {
              // No current user, clear login state
              await prefs.clear();
              setState(() {
                _isLoggedIn = false;
                _currentUser = null;
                _userProfile = null;
              });
            }
          } catch (e) {
            print('Error getting current user: $e');
            // Clear login state on error
            await prefs.clear();
            setState(() {
              _isLoggedIn = false;
              _currentUser = null;
              _userProfile = null;
            });
          }
        }
      }
    } catch (e) {
      print('Error checking login status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // First, try to sign out any existing user to ensure clean state
      await _googleSignIn.signOut();

      // Then attempt to sign in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser != null) {
        print('Google Sign-In successful: ${googleUser.email}');

        setState(() {
          _currentUser = googleUser;
          _isLoggedIn = true;
        });

        // Check if user already has profile data
        final prefs = await SharedPreferences.getInstance();
        final userData = prefs.getString('userProfile');

        if (userData != null) {
          // User has existing profile, load it
          final userMap = jsonDecode(userData);
          setState(() {
            _userProfile = UserProfile.fromJson(userMap);
            _addressController.text = _userProfile!.address;
            for (
              int i = 0;
              i < _userProfile!.floodRegions.length && i < 5;
              i++
            ) {
              _regionControllers[i].text = _userProfile!.floodRegions[i];
            }
          });
          _showSuccessSnackBar('Welcome back, ${googleUser.displayName}!');
        } else {
          // User needs to fill additional info
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAdditionalInfoForm();
          });
        }
      } else {
        // User cancelled the sign-in
        _showErrorSnackBar('Sign-in was cancelled');
      }
    } catch (error) {
      print('Error signing in with Google: $error');

      String errorMessage = 'Failed to sign in with Google';

      if (error.toString().contains('network_error') ||
          error.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (error.toString().contains('sign_in_failed') ||
          error.toString().contains('sign_in')) {
        errorMessage = 'Sign-in failed. Please try again.';
      } else if (error.toString().contains('sign_in_canceled') ||
          error.toString().contains('canceled')) {
        errorMessage = 'Sign-in was cancelled.';
      } else if (error.toString().contains('play_services') ||
          error.toString().contains('play')) {
        errorMessage =
            'Google Play Services not available. Please update your device.';
      } else if (error.toString().contains('developer_error') ||
          error.toString().contains('ApiException: 10')) {
        errorMessage =
            'Google Sign-In not configured. Please use Demo Mode for testing.';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() => _isLoading = false);
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
        address: 'Demo Address, Kuala Lumpur',
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

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    try {
      await _googleSignIn.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      setState(() {
        _isLoggedIn = false;
        _currentUser = null;
        _userProfile = null;
        _addressController.clear();
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
    if (_currentUser != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder:
            (context) => AdditionalInfoForm(
              user: _currentUser!,
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

  Future<void> _updateAddress(String newAddress) async {
    setState(() => _isLoading = true);

    try {
      final updatedProfile = UserProfile(
        id: _userProfile!.id,
        email: _userProfile!.email,
        displayName: _userProfile!.displayName,
        photoUrl: _userProfile!.photoUrl,
        address: newAddress,
        floodRegions: _userProfile!.floodRegions,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userProfile', jsonEncode(updatedProfile.toJson()));

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
        address: _userProfile!.address,
        floodRegions: updatedRegions,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userProfile', jsonEncode(updatedProfile.toJson()));

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
        address: _userProfile!.address,
        floodRegions: updatedRegions,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userProfile', jsonEncode(updatedProfile.toJson()));

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
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isLoggedIn && _userProfile != null
              ? _buildProfileView()
              : _buildLoginPrompt(),
    );
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
          const SizedBox(height: 32),
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
            'Sign in with your Google account or use Demo Mode for testing.',
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
          // Profile Header
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        _userProfile!.photoUrl != null
                            ? NetworkImage(_userProfile!.photoUrl!)
                            : null,
                    child:
                        _userProfile!.photoUrl == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userProfile!.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userProfile!.email,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Address Section
          _buildInfoSection(
            'Address',
            _userProfile!.address,
            Icons.location_on,
          ),
          const SizedBox(height: 16),

          // Flood Warning Regions
          _buildFloodRegionsSection(),
          const SizedBox(height: 24),

          // Sign Out Button
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFF2254C5)),
                const SizedBox(width: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
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
            const SizedBox(height: 8),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning, color: Color(0xFF2254C5)),
                const SizedBox(width: 12),
                const Text(
                  'Subscribed Flood Warning Region',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._userProfile!.floodRegions.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_city,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
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
            const SizedBox(height: 8),
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
  final GoogleSignInAccount user;
  final Function(UserProfile) onSave;

  const AdditionalInfoForm({
    super.key,
    required this.user,
    required this.onSave,
  });

  @override
  State<AdditionalInfoForm> createState() => _AdditionalInfoFormState();
}

class _AdditionalInfoFormState extends State<AdditionalInfoForm> {
  final _formKey = GlobalKey<FormState>();
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
        id: widget.user.id,
        email: widget.user.email,
        displayName: widget.user.displayName ?? 'User',
        photoUrl: widget.user.photoUrl,
        address: _addressController.text.trim(),
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
                      widget.user.photoUrl != null
                          ? NetworkImage(widget.user.photoUrl!)
                          : null,
                  child:
                      widget.user.photoUrl == null
                          ? const Icon(Icons.person, size: 30)
                          : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome, ${widget.user.displayName ?? 'User'}!',
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
  final String address;
  final List<String> floodRegions;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.address,
    required this.floodRegions,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'address': address,
      'floodRegions': floodRegions,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      displayName: json['displayName'],
      photoUrl: json['photoUrl'],
      address: json['address'],
      floodRegions: List<String>.from(json['floodRegions']),
    );
  }
}
