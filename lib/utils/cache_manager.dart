import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple cache manager for API responses
class CacheManager {
  static const String _cachePrefix = 'api_cache_';
  static const Duration _defaultCacheDuration = Duration(minutes: 5);

  /// Get cached data
  static Future<T?> get<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData == null) return null;
      
      final Map<String, dynamic> data = jsonDecode(cachedData);
      final timestamp = DateTime.parse(data['timestamp'] as String);
      final duration = Duration(seconds: data['duration'] as int);
      
      // Check if cache is expired
      if (DateTime.now().difference(timestamp) > duration) {
        await prefs.remove(cacheKey);
        return null;
      }
      
      return data['data'] as T?;
    } catch (e) {
      return null;
    }
  }

  /// Set cached data
  static Future<void> set<T>(
    String key,
    T data, {
    Duration duration = _defaultCacheDuration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'duration': duration.inSeconds,
      };
      await prefs.setString(cacheKey, jsonEncode(cacheData));
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Clear specific cache
  static Future<void> clear(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$key');
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Clear all cache
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Ignore cache errors
    }
  }
}
