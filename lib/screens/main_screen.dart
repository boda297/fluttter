import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/auth_helper.dart';
import 'home_feed_screen.dart';
import 'clips_screen.dart';
import 'news_screen.dart';
import 'account_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<ClipsScreenState> _clipsKey = GlobalKey<ClipsScreenState>();
  final GlobalKey<State<HomeFeedScreen>> _homeKey =
      GlobalKey<State<HomeFeedScreen>>();
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        // If there are routes in the navigator stack, pop them
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        // If we're not on Home tab, navigate to Home
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // If we're on Home tab, check for double back press
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF1A1A1A),
            ),
          );
          return;
        }

        // Double back press - exit app
        // Use SystemNavigator to exit the app
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeFeedScreen(key: _homeKey),
            ClipsScreen(key: _clipsKey),
            const NewsScreen(),
            AccountScreen(
              onProfileUpdated: () {
                // Refresh user name in HomeFeedScreen
                final homeState = _homeKey.currentState;
                if (homeState != null) {
                  (homeState as dynamic).refreshUserName();
                }
              },
            ),
          ],
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) async {
            // Home tab (index 0) - no auth required
            if (index == 0) {
              // Update clips visibility
              if (_currentIndex == 1) {
                // Leaving clips tab - make invisible
                _clipsKey.currentState?.setVisible(false);
              }

              // Refresh continue watching when returning to Home tab
              if (_currentIndex != 0) {
                final homeState = _homeKey.currentState;
                if (homeState != null) {
                  // Call refresh method using dynamic to avoid type checking issues
                  (homeState as dynamic).refreshContinueWatching();
                  // Resume home videos when returning to Home tab
                  (homeState as dynamic).resumeVideos();
                }
              }

              setState(() {
                _currentIndex = index;
              });
              return;
            }

            // Pause home videos when leaving Home tab
            if (_currentIndex == 0) {
              final homeState = _homeKey.currentState;
              if (homeState != null) {
                (homeState as dynamic).pauseVideos();
              }
            }

            // Clips, News, or Account tabs - require auth
            final isAuth = await AuthHelper.requireAuth(context);
            if (!isAuth) return;

            // Update clips visibility
            if (index == 1) {
              // Going to clips tab - make visible
              _clipsKey.currentState?.setVisible(true);
            } else if (_currentIndex == 1) {
              // Leaving clips tab - make invisible
              _clipsKey.currentState?.setVisible(false);
            }

            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}
