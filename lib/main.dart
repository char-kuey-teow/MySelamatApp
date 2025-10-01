import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'sos-button.dart';
import 'text_chatbot.dart';
import 'report.dart';
import 'profile.dart';

// This is the actual Flood Map content you provided, now a stateless content widget
class _FloodMapContent extends StatelessWidget {
  const _FloodMapContent();

  // Define custom colors (reused from the parent MainNavigator)
  static const dangerColor = Color(0xFFC62828);
  final headerBarColor = const Color(0xFF2254C5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 1. App Bar
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
        backgroundColor: headerBarColor,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10.0),
          child: Container(height: 10.0, color: headerBarColor),
        ),
      ),
      // 2. Main Content
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 12.0, bottom: 4.0),
              child: Text(
                'Flood Risk Map',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _buildRiskStatusCard(),
          ),
          const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: _buildMapPlaceholder(),
          ),
          const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: _buildRiskLegend()),
                const SizedBox(width: 7.0),
                Expanded(flex: 2, child: _buildRouteEta()),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: _buildReportButton(dangerColor, context),
          ),
        ],
      ),
    );
  }

  // --- Widget Builders (from original code) ---

  Widget _buildRiskStatusCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300, width: 1.3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Mukim Badang ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ORANGE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'High risk in 24h.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '1km radius',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Text(
              'Last updated: 9/29/2025, 12:28:19 AM',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return AspectRatio(
      aspectRatio: 1.2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.lightBlue.shade50,
                alignment: Alignment.center,
                child: const Text(
                  'Map View Placeholder (Kota Bharu Area)',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  _buildMapTab('Map', true),
                  const SizedBox(width: 8),
                  _buildMapTab('Satellite', false),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                ),
                child: const Icon(
                  Icons.fullscreen,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 40,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 2),
                      ],
                    ),
                    child: const Icon(
                      Icons.zoom_out_map,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 2),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab(String title, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildRiskLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
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
          _buildLegendItem('Green', Colors.green),
          _buildLegendItem('Yellow', Colors.yellow),
          _buildLegendItem('Orange', Colors.orange),
          _buildLegendItem('Red', Colors.red),
          const SizedBox(height: 7),
          const Text(
            'Tap district for details',
            style: TextStyle(
              fontSize: 8,
              fontStyle: FontStyle.italic,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildRouteEta() {
    return Container(
      padding: const EdgeInsets.all(8),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route ETA & Distance',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 7),
          Text(
            'Tap a safe zone and press "Safe Route".',
            style: TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton(Color dangerColor, BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // Navigate to report screen
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const ReportScreen()));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: dangerColor,
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 3,
        shadowColor: dangerColor.withOpacity(0.3),
      ),
      child: const Text(
        'Crowdsource Report',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
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
  int _selectedIndex = 0;

  static const primaryColor = Color(0xFF2254C5);

  // 2. List of screens corresponding to the bottom navigation items
  static final List<Widget> _widgetOptions = <Widget>[
    const _FloodMapContent(),
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
  await Firebase.initializeApp();
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
