import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'amplifyconfiguration.dart';
import 'sos-button.dart';
import 'text_chatbot.dart';
import 'profile.dart';
import 'flood-map.dart';
import 'config.dart';

// -------------------------------------------------------------
// Home Screen with AppBar wrapper for FloodMapWidget
// -------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      body: const FloodMapWidget(),
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
  int _selectedIndex = 4; // Start with Profile page (index 4)

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
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
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
  
  // Initialize Firebase (only if not running on web without proper config)
  try {
    await Firebase.initializeApp();
    safePrint('Firebase initialized successfully');
  } catch (e) {
    safePrint('Firebase initialization failed: $e');
    safePrint('Continuing without Firebase...');
    // Continue without Firebase - app will work with demo mode
  }
  
  // Initialize AWS Amplify if configured
  if (Config.useAmplify) {
    try {
      if (!Amplify.isConfigured) {
        await Amplify.addPlugin(AmplifyAuthCognito());
        await Amplify.configure(amplifyconfig);
        safePrint('AWS Amplify initialized successfully');
      } else {
        safePrint('AWS Amplify already configured');
      }
    } catch (e) {
      safePrint('Error initializing AWS Amplify: $e');
      // Continue without Amplify - will fall back to demo mode
    }
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
