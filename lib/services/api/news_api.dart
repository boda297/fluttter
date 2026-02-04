import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dio_client.dart';
import '../../models/news_model.dart';

class NewsApi {
  final DioClient _dioClient = DioClient();

  NewsApi() {
    _dioClient.init();
  }

  /// GET /news
  Future<List<NewsModel>> getAllNews() async {
    try {
      final response = await _dioClient.dio.get('/news');
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list.map((e) => NewsModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// No backend for remind; uses local prefs.
  Future<bool> isNewsReminded(String newsId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('reminded_news') ?? [];
    return ids.contains(newsId);
  }

  /// No backend for remind; updates local prefs.
  Future<void> remindNews(String newsId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('reminded_news') ?? [];
    if (!ids.contains(newsId)) {
      ids.add(newsId);
      await prefs.setStringList('reminded_news', ids);
    }
  }

  /// No backend for remind; updates local prefs.
  Future<void> unremindNews(String newsId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('reminded_news') ?? [];
    ids.remove(newsId);
    await prefs.setStringList('reminded_news', ids);
  }

  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to server.';
      case DioExceptionType.badResponse:
        return e.response?.data?['message'] ?? 'An error occurred. Please try again.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}
