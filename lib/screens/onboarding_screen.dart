import 'package:flutter/material.dart';
import '../widgets/orientation_logo.dart';
import '../widgets/project_image_grid.dart';
import '../widgets/language_selector.dart';
import 'login_screen.dart';
import 'create_account_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background image grid
          const Positioned.fill(
            child: ProjectImageGrid(),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.85),
                    Colors.black,
                    Colors.black,
                  ],
                  stops: const [0.0, 0.3, 0.5, 0.65, 1.0],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Language selector
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: LanguageSelector(),
                  ),
                ),
                const Spacer(),
                // Bottom content
                const OnboardingContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingContent extends StatelessWidget {
  const OnboardingContent({super.key});

  static const Color brandRed = Color(0xFFE50914);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo
          const OrientationLogo(),
          const SizedBox(height: 24),
          // Description text
          const Text(
            'A video platform to showcase developers\' projects in Orientation Ready, making it easy for brokers to view details anytime and quickly choose suitable projects.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          // Login button
          const LoginButton(),
          const SizedBox(height: 20),
          // Create account link
          const CreateAccountLink(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class LoginButton extends StatelessWidget {
  const LoginButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Login',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class CreateAccountLink extends StatelessWidget {
  const CreateAccountLink({super.key});

  static const Color brandRed = Color(0xFFE50914);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateAccountScreen(),
              ),
            );
          },
          child: const Text(
            'Create an account',
            style: TextStyle(
              color: brandRed,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
              decorationColor: brandRed,
            ),
          ),
        ),
      ],
    );
  }
}

