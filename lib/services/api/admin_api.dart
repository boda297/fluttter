import 'package:dio/dio.dart';
import '../dio_client.dart';

class JoinRequestModel {
  final String id;
  final String userId;
  final String companyName;
  final String headOffice;
  final String projectName;
  final int orientationsCount;
  final String? notes;
  final String status;
  final DateTime createdAt;

  JoinRequestModel({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.headOffice,
    required this.projectName,
    required this.orientationsCount,
    this.notes,
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'headOffice': headOffice,
      'projectName': projectName,
      'orientationsCount': orientationsCount,
      'notes': notes,
    };
  }

  factory JoinRequestModel.fromJson(Map<String, dynamic> json) {
    return JoinRequestModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      headOffice: json['headOffice']?.toString() ?? '',
      projectName: json['projectName']?.toString() ?? '',
      orientationsCount: (json['orientationsCount'] ?? 0) as int,
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }
}

class AdminApi {
  final DioClient _dioClient = DioClient();

  AdminApi() {
    _dioClient.init();
  }

  /// POST /admin/join-requests — Request: { companyName, headOffice, projectName, orientationsCount, notes? }
  /// Note: Implement when backend adds this route.
  Future<bool> submitJoinRequest(JoinRequestModel request) async {
    try {
      await _dioClient.dio.post('/admin/join-requests', data: request.toJson());
      return true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// GET /admin/join-requests
  /// Note: Implement when backend adds this route. Requires ADMIN.
  Future<List<JoinRequestModel>> getJoinRequests() async {
    try {
      final response = await _dioClient.dio.get('/admin/join-requests');
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list.map((e) => JoinRequestModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST /admin/join-requests/:id/approve
  Future<bool> approveJoinRequest(String requestId) async {
    try {
      await _dioClient.dio.post('/admin/join-requests/$requestId/approve');
      return true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST /admin/join-requests/:id/reject
  Future<bool> rejectJoinRequest(String requestId) async {
    try {
      await _dioClient.dio.post('/admin/join-requests/$requestId/reject');
      return true;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to server. Please check your internet connection.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'];
        if (statusCode == 401) return 'Unauthorized. Please login again.';
        if (statusCode == 403) return 'Access denied. Admin only.';
        return message ?? 'An error occurred. Please try again.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}
