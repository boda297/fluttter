class Validators {
  /// Checks if the input is a valid email format
  static bool isEmail(String input) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(input);
  }

  /// Checks if the input is a valid password (minimum 6 characters)
  static bool isPassword(String input) {
    final passwordRegex = RegExp(r'^.{6,}$');
    return passwordRegex.hasMatch(input);
  }
}
