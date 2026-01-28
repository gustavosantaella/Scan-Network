import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scan_network/screens/router_info_screen.dart';
import 'package:scan_network/screens/scanner_screen.dart';
import 'package:scan_network/screens/speed_test_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NetScanner Pro',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1), // Indigo 500
          secondary: Color(0xFF06B6D4), // Cyan 500
          surface: Color(0xFF1E293B), // Slate 800
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ScannerScreen(),
    const SpeedTestScreen(),
    const RouterInfoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: MaterialStateProperty.all(
              GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          child: NavigationBar(
            height: 70,
            backgroundColor: const Color(0xFF0F172A).withOpacity(0.95),
            indicatorColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.2),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.radar_outlined),
                selectedIcon: Icon(Icons.radar),
                label: 'Scanner',
              ),
              NavigationDestination(
                icon: Icon(Icons.speed_outlined),
                selectedIcon: Icon(Icons.speed),
                label: 'Speed Test',
              ),
              NavigationDestination(
                icon: Icon(Icons.router_outlined),
                selectedIcon: Icon(Icons.router),
                label: 'Router',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
