import 'package:flutter/material.dart';
import '../services/api/auth_api.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';

/// Helper class for authentication checks
class AuthHelper {
  static final AuthApi _authApi = AuthApi();

  /// Check if user is logged in, if not show dialog and navigate to login
  /// Returns true if logged in, false otherwise
  static Future<bool> requireAuth(BuildContext context) async {
    final isLoggedIn = await _authApi.isLoggedIn();
    
    if (!isLoggedIn) {
      // Show dialog message
      if (context.mounted) {
        final shouldLogin = await showDialog<bool>(
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
                          color: const Color(0xFFE50914).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFFE50914),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      const Text(
                        'Login Required',
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
                        'Please log in to access this feature',
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
                                backgroundColor: const Color(0xFFE50914),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Log In',
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
        );

        // If user clicked OK (تسجيل الدخول), navigate to onboarding screen first, then login
        if (shouldLogin == true && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OnboardingScreen(),
            ),
          );
        }
      }
      return false;
    }
    
    return true;
  }

  /// Check if user is logged in (without navigation)
  static Future<bool> isLoggedIn() async {
    return await _authApi.isLoggedIn();
  }
}

