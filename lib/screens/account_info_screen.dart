import 'package:flutter/material.dart';
import '../services/api/auth_api.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authApi = AuthApi();
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      final profile = await _authApi.getUserProfile();

      if (mounted) {
        // Get email from stored user info to ensure it has @
        final userInfo = await _authApi.getStoredUserInfo();
        final storedEmail = userInfo['email'] ?? '';
        final profileEmail = profile['email'] ?? '';

        // Prioritize email with @ symbol
        String emailToUse = '';
        if (storedEmail.isNotEmpty && storedEmail.contains('@')) {
          emailToUse = storedEmail;
        } else if (profileEmail.isNotEmpty && profileEmail.contains('@')) {
          emailToUse = profileEmail;
        } else if (storedEmail.isNotEmpty) {
          emailToUse = storedEmail;
        } else if (profileEmail.isNotEmpty) {
          emailToUse = profileEmail;
        }

        // If email doesn't contain @, try to reconstruct it
        if (emailToUse.isNotEmpty && !emailToUse.contains('@')) {
          // Try to add @ if it's missing (e.g., "mohmed gmail.com" -> "mohmed@gmail.com")
          final parts = emailToUse.split(' ');
          if (parts.length >= 2) {
            // If there's a space, assume format is "username domain.com"
            emailToUse = '${parts[0]}@${parts.sublist(1).join('')}';
          }
        }

        setState(() {
          _firstNameController.text = profile['firstName'] ?? '';
          _lastNameController.text = profile['lastName'] ?? '';
          _emailController.text = emailToUse;
          _phoneController.text = profile['phoneNumber'] ?? '';
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Error loading profile: $e';
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    // Validation for personal info
    if (_firstNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your first name', isError: true);
      return;
    }

    if (_lastNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your last name', isError: true);
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Please enter your email', isError: true);
      return;
    }

    // Email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showSnackBar('Please enter a valid email address', isError: true);
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('Please enter your phone number', isError: true);
      return;
    }

    // Validation for password (if provided)
    if (_newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty) {
      if (_newPasswordController.text.isEmpty) {
        _showSnackBar('Please enter a new password', isError: true);
        return;
      }

      if (_newPasswordController.text != _confirmPasswordController.text) {
        _showSnackBar('Passwords do not match', isError: true);
        return;
      }

      if (_newPasswordController.text.length < 6) {
        _showSnackBar('Password must be at least 6 characters', isError: true);
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Update profile - ensure email is preserved with @
      final emailText = _emailController.text.trim();
      if (!emailText.contains('@')) {
        _showSnackBar('Please enter a valid email address with @',
            isError: true);
        return;
      }

      await _authApi.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: emailText,
        phoneNumber: _phoneController.text.trim(),
      );

      // Update password if provided
      if (_newPasswordController.text.isNotEmpty) {
        await _authApi.updatePassword(
          newPassword: _newPasswordController.text,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _showSnackBar('Profile updated successfully!', isSuccess: true);

        // Clear password fields
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        // Navigate back after a short delay with result to refresh AccountScreen
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(
                context, true); // Pass true to indicate profile was updated
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : isSuccess
                ? Colors.green
                : Colors.grey[800],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            _buildAppBar(context),
            // Form
            Expanded(
              child: _isLoadingData
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE50914),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                          // Edit Personal Info section
                          const Text(
                            'Edit Personal Info',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _firstNameController,
                            hint: 'First Name*',
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _lastNameController,
                            hint: 'Last Name*',
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'Email*',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _phoneController,
                            hint: 'Phone Number*',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 32),
                          // Edit Password section
                          const Text(
                            'Edit Password',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _newPasswordController,
                            hint: 'New Password',
                            isPassword: true,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            hint: 'Confirm Password',
                            isPassword: true,
                          ),
                        ],
                      ),
                    ),
            ),
            // Save button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A2A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.chevron_left,
              color: Colors.white,
              size: 28,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Account Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
