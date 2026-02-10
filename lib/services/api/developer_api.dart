import 'package:dio/dio.dart';
import '../dio_client.dart';

class DeveloperApi {
  final DioClient _dioClient = DioClient();

  DeveloperApi() {
    _dioClient.init();
  }

  /// POST /developer/join-developer
  /// Body: { name, address, phoneNumber, numberOfProjects, socialmediaLink, notes? }
  Future<bool> submitJoinDeveloperRequest({
    required String name,
    required String address,
    required String phoneNumber,
    required int numberOfProjects,
    required String socialmediaLink,
    String? notes,
  }) async {
    try {
      await _dioClient.dio.post(
        '/developer/join-developer',
        data: {
          'name': name,
          'address': address,
          'phoneNumber': phoneNumber,
          'numberOfProjects': numberOfProjects,
          'socialmediaLink': socialmediaLink,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
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
        final message = e.response?.data?['message'];
        if (message is List) return message.join('\n');
        return message?.toString() ?? 'An error occurred. Please try again.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

