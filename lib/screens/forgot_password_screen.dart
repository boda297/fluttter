import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/auth_header.dart';
import '../widgets/custom_text_field.dart';
import '../services/api/auth_api.dart';
import 'otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final AuthApi _authApi = AuthApi();
  
  int _resendSeconds = 3;
  Timer? _timer;
  bool _canResend = false;
  bool _isLoading = false;
  String? _errorMessage;

  static const Color brandRed = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _resendSeconds = 3;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() {
          _resendSeconds--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = (_resendSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_resendSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Email validation regex
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email';
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authApi.forgotPassword(email);

      if (!mounted) return;

      // Navigate to OTP screen for password reset
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            email: email,
            isRegistration: false, // This is for password reset
          ),
        ),
      );
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
      // Handle specific error messages
      if (errorMessage.contains('not found') || errorMessage.contains('User not found')) {
        errorMessage = 'No account found with this email. Please check and try again.';
      } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
        errorMessage = 'Please check your internet connection and try again.';
      }
      
      setState(() {
        _errorMessage = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendCode() async {
    if (!_canResend || _emailController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authApi.forgotPassword(_emailController.text.trim());
      _startTimer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset code sent to your email'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
      if (errorMessage.contains('not found') || errorMessage.contains('User not found')) {
        errorMessage = 'No account found with this email.';
      }
      
      setState(() {
        _errorMessage = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: isKeyboardVisible 
              ? const ClampingScrollPhysics() 
              : const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: keyboardHeight > 0 ? 20 : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with geometric background and logo
                const AuthHeader(),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // Title
                      const Text(
                        'Forgot password',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Description
                      Text(
                        'Enter the email you used to log in when you first used the app!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Email field
                      CustomTextField(
                        hintText: 'Email',
                        prefixIcon: Icons.email_outlined,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      // Error message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: brandRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: brandRed.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: brandRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: brandRed, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 150),
                      // Send code button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSendCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A2A2A),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF2A2A2A).withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Send code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Resend code timer
                      Center(
                        child: GestureDetector(
                          onTap: _canResend ? _handleResendCode : null,
                          child: RichText(
                            text: TextSpan(
                              text: 'Resend code ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: _formattedTime,
                                  style: const TextStyle(
                                    color: brandRed,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

