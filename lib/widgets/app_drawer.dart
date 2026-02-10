import 'package:flutter/material.dart';
import '../widgets/orientation_logo.dart';
import '../widgets/auth_header.dart';
import '../utils/auth_helper.dart';
import '../services/api/auth_api.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/latest_for_us_screen.dart';
import '../screens/continue_watching_screen.dart';
import '../screens/top_10_screen.dart';
import '../screens/projects_list_screen.dart';
import '../screens/developers_screen.dart';
import '../screens/areas_screen.dart';

class AppDrawer extends StatefulWidget {
  final VoidCallback? onScrollToUpcoming;
  
  const AppDrawer({super.key, this.onScrollToUpcoming});

  @override
  AppDrawerState createState() => AppDrawerState();
}

class AppDrawerState extends State<AppDrawer> {
  static const Color brandRed = Color(0xFFE50914);

  void refreshAuthStatus() {
    setState(() {}); // Refresh the FutureBuilder
  }

  void _showLogoutDialog() {
    final context = this.context;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: brandRed.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: brandRed,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  const Text(
                    'Confirm Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Message
                  Text(
                    'Are you sure you want to logout?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Yes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((shouldLogout) async {
      if (shouldLogout == true) {
        final authApi = AuthApi();
        await authApi.logout();
        if (mounted) {
          setState(() {}); // Refresh the FutureBuilder
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
              (route) => false,
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black,
      width: MediaQuery.of(context).size.width * 0.75,
      child: SafeArea(
        child: Column(
          children: [
            // Header with geometric background from AuthHeader and logo
            const DrawerHeader(),
            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  DrawerMenuItem(
                    title: 'The latest for us',
                    onTap: () async {
                      Navigator.pop(context);
                      final isAuth = await AuthHelper.requireAuth(context);
                      if (!isAuth) return;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LatestForUsScreen(),
                        ),
                      );
                    },
                  ),
                  DrawerMenuItem(
                    title: 'Continue watching',
                    onTap: () async {
                      Navigator.pop(context);
                      final isAuth = await AuthHelper.requireAuth(context);
                      if (!isAuth) return;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContinueWatchingScreen(),
                        ),
                      );
                    },
                  ),
                  DrawerMenuItem(
                    title: 'Top 10',
                    onTap: () async {
                      Navigator.pop(context);
                      final isAuth = await AuthHelper.requireAuth(context);
                      if (!isAuth) return;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Top10Screen(),
                        ),
                      );
                    },
                  ),
                  DrawerMenuItem(
                    title: 'Projects in Northcoast',
                    onTap: () async {
                      Navigator.pop(context);
                      final isAuth = await AuthHelper.requireAuth(context);
                      if (!isAuth) return;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectsListScreen(
                            title: 'Projects in Northcoast',
                          ),
                        ),
                      );
                    },
                  ),
                  DrawerMenuItem(
                    title: 'Projects in New Cairo',
                    onTap: () async {
                      Navigator.pop(context);
                      final isAuth = await AuthHelper.requireAuth(context);
                      if (!isAuth) return;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectsListScreen(
                            title: 'Projects in New Cairo',
                          ),
                        ),
                      );
                    },
                  ),
                  DrawerMenuItem(
                    title: 'Projects in October',
                    onTap: () async {
                      Navigator.pop(context);
                      final isAuth = await AuthHelper.requireAuth(context);
                      if (!isAuth) return;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectsListScreen(
                            title: 'Projects in October',
                          ),
                        ),
                      );
                    },
                  ),
                  DrawerMenuItem(
                    title: 'Upcoming events',
                    onTap: () {
                      Navigator.pop(context);
                      // Scroll to upcoming projects section (no auth required)
                      if (widget.onScrollToUpcoming != null) {
                        widget.onScrollToUpcoming!();
                      }
                    },
                  ),
                  DrawerMenuItem(
                    title: 'Courses',
                    onTap: () async {
                      Navigator.pop(context);
                      await AuthHelper.requireAuth(context);
                    },
                  ),
                  DrawerMenuItem(
                    title: 'Developers',
                    onTap: () async {
                      Navigator.pop(context);
                      final isAuth = await AuthHelper.requireAuth(context);
                      if (!isAuth) return;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DevelopersScreen(),
                        ),
                      );
                    },
                  ),
                  DrawerMenuItem(
                    title: 'Areas',
                    onTap: () async {
                      Navigator.pop(context);
                      final isAuth = await AuthHelper.requireAuth(context);
                      if (!isAuth) return;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AreasScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Logout/Login button
            Padding(
              padding: const EdgeInsets.all(24),
              child: FutureBuilder<bool>(
                future: AuthApi().isLoggedIn(),
                builder: (context, snapshot) {
                  final isLoggedIn = snapshot.data ?? false;
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLoggedIn) {
                          _showLogoutDialog();
                        } else {
                          Navigator.pop(context); // Close drawer first
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingScreen(),
                            ),
                          ).then((_) {
                            // Refresh auth status after returning from login
                            refreshAuthStatus();
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isLoggedIn ? 'Logout' : 'Login',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrawerHeader extends StatelessWidget {
  const DrawerHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        children: [
          // Black background
          Container(
            color: Colors.black,
          ),
          // Logo
          const Positioned(
            left: 24,
            bottom: 24,
            child: OrientationLogo(),
          ),
        ],
      ),
    );
  }
}

class DrawerMenuItem extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const DrawerMenuItem({
    super.key,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.white.withOpacity(0.5),
        size: 20,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 2,
      ),
      onTap: onTap ?? () {
        Navigator.pop(context);
      },
    );
  }
}
