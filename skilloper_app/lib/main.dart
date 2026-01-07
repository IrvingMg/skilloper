import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

    // Refresh Home when coming from Add tab (newly created/imported quizzes)
    if (previousIndex == 2 && index == 0) {
      _homeKey.currentState?.refresh();
    }

    // Always refresh History when navigating to it
    // Quiz attempts can be completed from Home at any time
    if (index == 1 && previousIndex != 1) {
      _historyKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.primaryContainer,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo from SVG asset
            SvgPicture.asset(
              'assets/images/logo.svg',
              width: 36,
              height: 36,
            ),
            const SizedBox(width: 10),
            // Brand name
            Text(
              'Skilloper',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimaryContainer,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          border: Border(
            top: BorderSide(
              color: AppColors.outline,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(AppIcons.home),
              selectedIcon: Icon(AppIcons.homeSelected),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.history),
              selectedIcon: Icon(AppIcons.historySelected),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.add),
              selectedIcon: Icon(AppIcons.addSelected),
              label: 'Add',
            ),
          ],
        ),
      ),
    );
  }
}
