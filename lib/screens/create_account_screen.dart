import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../widgets/auth_header.dart';
import '../widgets/custom_text_field.dart';
import '../services/api/auth_api.dart';
import 'login_screen.dart';
import 'otp_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthApi _authApi = AuthApi();
  
  String _fullPhoneNumber = '';
  bool _isLoading = false;
  String? _errorMessage;

  static const Color brandRed = Color(0xFFE50914);

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email validation regex
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // Phone validation regex (supports international format with country code)
  bool _isValidPhone(String phone) {
    // Remove spaces, dashes, and parentheses
    final cleanedPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // Check if it starts with + and has 10-15 digits after country code
    final phoneRegex = RegExp(r'^\+[1-9]\d{9,14}$');
    return phoneRegex.hasMatch(cleanedPhone);
  }

  Future<void> _handleRegister() async {
    // Validate inputs
    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your username';
      });
      return;
    }

    if (_fullPhoneNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }

    // Validate phone number format
    if (!_isValidPhone(_fullPhoneNumber)) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number with country code';
      });
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email';
      });
      return;
    }

    // Validate email format
    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
      });
      return;
    }

    if (_passwordController.text.length < 8) {
      setState(() {
        _errorMessage = 'Password must be at least 8 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authApi.register(
        username: _usernameController.text.trim(),
        email: email,
        phoneNumber: _fullPhoneNumber, // Use full phone number with country code
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Register returns { success, message, email }
      // Navigate to OTP screen for email verification
      final userEmail = result['email'] as String? ?? email;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            email: userEmail,
            isRegistration: true, // Indicate this is for registration
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
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
          physics: const ClampingScrollPhysics(),
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
                      'Create an account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Description
                    Text(
                      'Create your account to start viewing Orientation projects and access all details easily.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Username field
                    CustomTextField(
                      hintText: 'Username',
                      prefixIcon: Icons.person_outline,
                      controller: _usernameController,
                    ),
                    const SizedBox(height: 16),
                    // Phone number field with country code picker
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IntlPhoneField(
                        controller: _phoneController,
                        initialCountryCode: 'EG',
                        disableLengthCheck: true,
                        dropdownIconPosition: IconPosition.trailing,
                        dropdownIcon: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        flagsButtonPadding: const EdgeInsets.only(left: 12),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        dropdownTextStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Phone number',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (phone) {
                          _fullPhoneNumber = phone.completeNumber;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Email field
                    CustomTextField(
                      hintText: 'Email',
                      prefixIcon: Icons.email_outlined,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    // Password field
                    CustomTextField(
                      hintText: 'Password',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      controller: _passwordController,
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
                    const SizedBox(height: 24),
                    // Create account button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white.withOpacity(0.5),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text(
                                'Create an account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Log in',
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
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
