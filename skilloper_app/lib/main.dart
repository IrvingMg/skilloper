import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'screens/add_quiz_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_icons.dart';
import 'theme/app_theme.dart';

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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isHandlingSessionExpiry = false;

  @override
  void initState() {
    super.initState();
    _authService.onSessionExpired = _onSessionExpired;
    _checkAuth();
  }

  @override
  void dispose() {
    _authService.onSessionExpired = null;
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await _authService.loadStoredSession();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onSessionExpired() {
    if (!mounted || _isHandlingSessionExpiry) return;

    _isHandlingSessionExpiry = true;
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      _isHandlingSessionExpiry = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surfaceWhite,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_authService.isLoggedIn) {
      return MainScreen(onLogout: _onAuthStateChanged);
    }

    return LoginScreen(onLoginSuccess: _onAuthStateChanged);
  }
}

class MainScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const MainScreen({super.key, this.onLogout});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _homeKey = GlobalKey<HomeScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeKey, onNavigateToAdd: () => _onTabSelected(2)),
      HistoryScreen(key: _historyKey),
      const AddQuizScreen(),
      ProfileScreen(onLogout: () => widget.onLogout?.call()),
    ];
  }

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
            SvgPicture.asset(
              'assets/images/logo.svg',
              width: AppIconSizes.appBarLogo,
              height: AppIconSizes.appBarLogo,
            ),
            const SizedBox(width: 10),
            const Text(
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
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceWhite,
          border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
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
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
