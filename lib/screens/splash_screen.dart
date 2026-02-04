import 'package:flutter/material.dart';
import '../widgets/orientation_logo.dart';
import '../widgets/loading_indicator.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();

    // Navigate to main screen after loading completes (allow browsing without login)
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainScreen(),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;
            final logoScale = isSmallScreen ? 0.8 : 1.0;

            return Column(
              children: [
                // Main content area with logo centered
                Expanded(
                  child: Center(
                    child: Transform.scale(
                      scale: logoScale,
                      child: const OrientationLogo(),
                    ),
                  ),
                ),
                // Loading section at bottom
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth * 0.15,
                    vertical: 40,
                  ),
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return LoadingIndicator(
                        progress: _progressAnimation.value,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

