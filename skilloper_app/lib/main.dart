import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'theme/app_icons.dart';

void main() {
  runApp(const SkiloperApp());
}

class SkiloperApp extends StatelessWidget {
  const SkiloperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skilloper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
    const HomeScreen(),
    const ImportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // Center the title
        title: Row(
          mainAxisSize: MainAxisSize.min, // Take minimum space to center properly
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.psychology, // Brain with gear icon for learning app
                color: Colors.white,
                size: AppIconSizes.large,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Skilloper'),
          ],
        ),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.home),
            selectedIcon: Icon(AppIcons.homeSelected),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.upload),
            selectedIcon: Icon(AppIcons.uploadSelected),
            label: 'Import',
          ),
        ],
      ),
    );
  }
}