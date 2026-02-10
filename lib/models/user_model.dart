class UserModel {
  final String id;
  final String username;
  final String email;
  final String? phoneNumber;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.phoneNumber,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      username: (json['username'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phoneNumber: json['phoneNumber']?.toString(),
      role: (json['role'] ?? 'user') as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class AuthResponse {
  final UserModel user;
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Support both old format (token) and new format (accessToken + refreshToken)
    final accessToken = json['accessToken']?.toString() ?? json['token']?.toString() ?? '';
    final refreshToken = json['refreshToken']?.toString() ?? '';
    
    return AuthResponse(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
  
  // Backward compatibility: get token (returns accessToken)
  String get token => accessToken;
}
