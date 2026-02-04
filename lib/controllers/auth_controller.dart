import 'package:flutter/foundation.dart';
import '../services/api/auth_api.dart';

class AuthController extends ChangeNotifier {
  final AuthApi _authApi;

  bool loading = false;
  String? errorMessage;
  bool _isLoggedIn = false;

  AuthController({AuthApi? authApi}) : _authApi = authApi ?? AuthApi() {
    _checkAuthStatus();
  }

  bool get isLoggedIn => _isLoggedIn;

  /// Check authentication status
  Future<void> _checkAuthStatus() async {
    _isLoggedIn = await _authApi.isLoggedIn();
    notifyListeners();
  }

  /// Refresh authentication status
  Future<void> refreshAuthStatus() async {
    await _checkAuthStatus();
  }

  /// Sets the API base URL
  void setApiBaseUrl(String url) {
    _authApi.setBaseUrl(url);
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    try {
      loading = true;
      errorMessage = null;
      notifyListeners();

      await _authApi.login(email, password);

      _isLoggedIn = true;
      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoggedIn = false;
      loading = false;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _authApi.logout();
    _isLoggedIn = false;
    notifyListeners();
  }

  /// Register with username, email, phone number and password
  /// Returns Map with { success, message, email }
  /// Note: User must verify email via OTP before they can login
  Future<Map<String, dynamic>?> register({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      loading = true;
      errorMessage = null;
      notifyListeners();

      final result = await _authApi.register(
        username: username,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );

      // Register doesn't log user in - they must verify email first
      _isLoggedIn = false;
      loading = false;
      notifyListeners();
      return result;
    } catch (e) {
      loading = false;
      errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }
}
