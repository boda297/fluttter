import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/auth_header.dart';
import '../widgets/custom_text_field.dart';
import '../services/api/auth_api.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final bool isRegistration; // true for registration, false for password reset

  const OtpScreen({
    super.key,
    required this.email,
    this.isRegistration = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    4,
    (index) => FocusNode(),
  );
  final AuthApi _authApi = AuthApi();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  Timer? _timer;
  int _remainingSeconds = 120; // 2 minutes

  static const Color brandRed = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _remainingSeconds = 120; // 2 minutes
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _isExpired => _remainingSeconds <= 0;

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {}); // Update UI
  }

  String get _otpCode {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpCode.length != 4) {
      setState(() {
        _errorMessage = 'Please enter the 4-digit code';
      });
      return;
    }

    if (_isExpired) {
      setState(() {
        _errorMessage = 'Code has expired. Please click "Resend Code"';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.isRegistration) {
        // For registration: verify email
        await _authApi.verifyEmail(widget.email, _otpCode);
        
        if (!mounted) return;
        
        // Show success message and navigate to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully! You can now login.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Navigate to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      } else {
        // For password reset: verify reset OTP (optional step)
        // Then navigate to change password screen
        try {
          await _authApi.verifyResetOTP(widget.email, _otpCode);
        } catch (e) {
          // If verify-reset-otp fails, still allow password reset
          print('Verify reset OTP failed: $e');
        }
        
        if (!mounted) return;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChangePasswordScreen(
              email: widget.email,
              otp: _otpCode,
            ),
          ),
        );
      }
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
      // Handle specific error messages
      if (errorMessage.contains('Invalid') || errorMessage.contains('invalid')) {
        errorMessage = 'Invalid verification code. Please try again.';
      } else if (errorMessage.contains('expired') || errorMessage.contains('Expired')) {
        errorMessage = 'Verification code has expired. Please click "Resend Code".';
      } else if (errorMessage.contains('already verified')) {
        errorMessage = 'Email already verified. You can login now.';
        // Navigate to login if already verified
        if (mounted && widget.isRegistration) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
            (route) => false,
          );
          return;
        }
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
    if (_isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      if (widget.isRegistration) {
        await _authApi.resendVerification(widget.email);
      } else {
        await _authApi.forgotPassword(widget.email);
      }
      
      // Restart timer
      _startTimer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your email'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                      'Check your email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Description
                    RichText(
                      text: TextSpan(
                        text: 'We have sent the code to:\n',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              color: brandRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // OTP input fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(4, (index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < 3 ? 16 : 0,
                          ),
                          child: OtpInputField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            isFilled: _controllers[index].text.isNotEmpty,
                            onChanged: (value) => _onOtpChanged(value, index),
                          ),
                        );
                      }),
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
                    // Timer and resend code
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Timer
                        Text(
                          _isExpired ? 'Code expired' : 'Code expires in: $_formattedTime',
                          style: TextStyle(
                            color: _isExpired ? brandRed : Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        // Resend button
                        GestureDetector(
                          onTap: _isResending ? null : _handleResendCode,
                          child: Text(
                            _isResending ? 'Sending...' : 'Resend Code',
                            style: TextStyle(
                              color: _isResending 
                                  ? Colors.white.withOpacity(0.3)
                                  : brandRed,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: _isResending ? null : TextDecoration.underline,
                              decorationColor: brandRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 100),
                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerifyOtp,
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
                                'Verify',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Back link
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Back',
                          style: TextStyle(
                            color: brandRed,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: brandRed,
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
    );
  }
}

