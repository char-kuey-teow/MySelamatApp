import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'sos-button.dart';
import 'text_chatbot.dart';
import 'profile.dart';
import 'flood-map.dart';
import 'services/sos_state_service.dart';

// -------------------------------------------------------------
// Home Screen with AppBar wrapper for FloodMapWidget
// -------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _showSOSNotification = false;
  LocalSOSState? _activeSOSState;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize slide animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0), // Start above screen
      end: const Offset(0.0, 0.0),    // End at normal position
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    _checkActiveSOSOnStartup();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  /// Check for active SOS on app startup and show notification
  Future<void> _checkActiveSOSOnStartup() async {
    try {
      final sosState = await SOSStateService.loadActiveSOS();
      if (sosState != null && sosState.isActive) {
        setState(() {
          _activeSOSState = sosState;
          _showSOSNotification = true;
        });
        
        // Slide down animation
        _slideController.forward();
        
        // Hide notification after 5 seconds with slide up animation
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _hideNotification();
          }
        });
      }
    } catch (e) {
      print('Error checking active SOS on startup: $e');
    }
  }

  /// Hide notification with slide up animation
  void _hideNotification() {
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showSOSNotification = false;
        });
      }
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
          'MySelamat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF2254C5),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10.0),
          child: Container(height: 10.0, color: const Color(0xFF2254C5)),
        ),
      ),
      body: Stack(
        children: [
          const FloodMapWidget(),
          
          // SOS Notification Banner
          if (_showSOSNotification) _buildSOSNotificationBanner(),
        ],
      ),
    );
  }

  /// Build SOS notification banner that appears at the top
  Widget _buildSOSNotificationBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          height: 60,
          color: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.warning,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'SOS ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_activeSOSState?.category != null)
                      Text(
                        'Emergency: ${_activeSOSState!.category}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _hideNotification,
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// The Main Navigator (Stateful Widget to handle tab switching)
// -------------------------------------------------------------

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0; // Start with Home page (index 0)

  static const primaryColor = Color(0xFF2254C5);

  // 2. List of screens corresponding to the bottom navigation items
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(),
    const SosScreen(),
    const Center(
      child: Text(
        'Shelter Screen',
        style: TextStyle(fontSize: 24, color: primaryColor),
      ),
    ), // Index 2: Shelter
    const TextChatbotScreen(), // Index 3: Chatbot
    const ProfileScreen(), // Index 4: Profile
  ];

  // 3. Function to update the index when a tab is tapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 4. Bottom Navigation Bar Builder
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white, // White background
      selectedItemColor: primaryColor, // Red for SOS, blue for others
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      currentIndex: _selectedIndex,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.sos_outlined), label: 'SOS'),
        BottomNavigationBarItem(icon: Icon(Icons.home_work), label: 'Shelter'),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'Chat',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      onTap: _onItemTapped,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      // The body changes dynamically based on the selected index
      body: _widgetOptions.elementAt(_selectedIndex),

      // The bottom navigation bar is consistent across tabs
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
}

// --- Example `main` function to run the app ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization error: $e');
    // Continue without Firebase for now
  }

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
        scaffoldBackgroundColor: Colors.white, // White background
      ),
      // Start the app with the MainNavigator
      home: const MainNavigator(),
    );
  }
}