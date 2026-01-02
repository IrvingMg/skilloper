import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/add_quiz_screen.dart';
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

  // Keys to access screen states for refresh
  final _homeKey = GlobalKey<HomeScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();

  late final List<Widget> _screens = [
    HomeScreen(key: _homeKey),
    HistoryScreen(key: _historyKey),
    const AddQuizScreen(),
  ];

  void _onTabSelected(int index) {
    final previousIndex = _currentIndex;

    setState(() {
      _currentIndex = index;
    });

    // Refresh Home or History when coming from Add tab
    // This ensures newly created/imported quizzes appear
    if (previousIndex == 2) {
      if (index == 0) {
        _homeKey.currentState?.refresh();
      } else if (index == 1) {
        _historyKey.currentState?.refresh();
      }
    }
  }

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
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.home),
            selectedIcon: Icon(AppIcons.homeSelected),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Add',
          ),
        ],
      ),
    );
  }
}