import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dio_client.dart';
import '../../models/clip_model.dart';
import '../../utils/lru_cache.dart';

/// Improved Clip API with smart caching, pagination, optimistic updates, and offline support
class ImprovedClipApi {
  final DioClient _dioClient = DioClient();

  // LRU caches with size limits (prevents unbounded memory growth)
  static const int _clipCacheMaxSize = 500;
  static const int _pageCacheMaxSize = 20;
  static const int _likedCacheMaxSize = 1000;
  final LRUCache<String, ClipModel> _clipCache = LRUCache(_clipCacheMaxSize);
  final Map<String, bool> _likedCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  final LRUCache<String, List<ClipModel>> _pageCache =
      LRUCache(_pageCacheMaxSize);
  final Map<String, DateTime> _pageCacheTimestamps = {};

  // SharedPreferences keys
  static const String _likedClipsKey = 'liked_clips';
  static const String _cachedClipsKey = 'cached_clips';

  // Debounced save for liked clips (batches rapid likes into one write)
  Timer? _saveTimer;
  bool _needsSave = false;
  static const Duration _saveDebounce = Duration(seconds: 2);

  ImprovedClipApi() {
    _dioClient.init();
    _loadLikedClipsFromCache();
  }

  /// Load liked clips from SharedPreferences on initialization
  Future<void> _loadLikedClipsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedIds = prefs.getStringList(_likedClipsKey) ?? [];
      for (var id in likedIds) {
        _likedCache[id] = true;
      }
      debugPrint(
          '✅ ImprovedClipApi: Loaded ${likedIds.length} liked clips from cache');
    } catch (e) {
      debugPrint('⚠️ ImprovedClipApi: Error loading liked clips: $e');
    }
  }

  /// Schedule a debounced save (batches multiple likes into one write)
  void _scheduleSaveLikedClipsToCache() {
    _needsSave = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () async {
      if (!_needsSave) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final likedIds = _likedCache.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList();
        await prefs.setStringList(_likedClipsKey, likedIds);
        _needsSave = false;
        debugPrint(
            '💾 ImprovedClipApi: Saved ${likedIds.length} liked clips to cache');
      } catch (e) {
        debugPrint('⚠️ ImprovedClipApi: Error saving liked clips: $e');
      }
    });
  }

  /// Force immediate save (call on app pause/dispose)
  Future<void> flush() async {
    _saveTimer?.cancel();
    if (!_needsSave) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedIds =
          _likedCache.entries.where((e) => e.value).map((e) => e.key).toList();
      await prefs.setStringList(_likedClipsKey, likedIds);
      _needsSave = false;
      debugPrint('💾 ImprovedClipApi: Flushed liked clips cache');
    } catch (e) {
      debugPrint('⚠️ ImprovedClipApi: Error flushing liked clips: $e');
    }
  }

  /// Check if cache entry is valid (not expired)
  bool _isCacheValid(String key) {
    if (!_cacheTimestamps.containsKey(key)) return false;
    final timestamp = _cacheTimestamps[key]!;
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Check if page cache entry is valid
  bool _isPageCacheValid(String key) {
    if (!_pageCacheTimestamps.containsKey(key)) return false;
    final timestamp = _pageCacheTimestamps[key]!;
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Update cache timestamp
  void _updateCacheTimestamp(String key) {
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Update page cache timestamp
  void _updatePageCacheTimestamp(String key) {
    _pageCacheTimestamps[key] = DateTime.now();
  }

  /// Get all clips with pagination support
  /// If backend doesn't support pagination, it will handle pagination in memory
  Future<List<ClipModel>> getAllClips({
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'all_clips_page_${page}_limit_$limit';

    // Check page cache first
    if (!forceRefresh &&
        _isPageCacheValid(cacheKey) &&
        _pageCache.containsKey(cacheKey)) {
      final cached = _pageCache.get(cacheKey)!;
      debugPrint(
          '⚡ ImprovedClipApi: Returning ${cached.length} clips from page cache (page $page)');
      return cached;
    }

    try {
      // Try to fetch with pagination parameters
      final response = await _dioClient.dio.get(
        '/reels',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      // Handle response format
      List<dynamic> list;
      if (response.data is List) {
        list = response.data as List;
      } else if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        list = (map['reels'] as List<dynamic>?) ??
            (map['data'] as List<dynamic>?) ??
            (map['clips'] as List<dynamic>?) ??
            <dynamic>[];
      } else {
        list = <dynamic>[];
      }

      // If backend doesn't support pagination, handle it in memory
      List<ClipModel> clips;
      if (list.length > limit && page > 1) {
        // Backend returned all clips, need to paginate in memory
        final allClips = list
            .map((e) => ClipModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final skip = (page - 1) * limit;
        clips = allClips.skip(skip).take(limit).toList();
      } else {
        clips = list
            .map((e) => ClipModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Update individual clip cache
      for (var clip in clips) {
        _clipCache.put(clip.id, clip);
        _updateCacheTimestamp(clip.id);
      }

      // Update page cache
      _pageCache.put(cacheKey, clips);
      _updatePageCacheTimestamp(cacheKey);

      // Sync liked status
      await _syncLikedStatus(clips);

      debugPrint(
          '✅ ImprovedClipApi: Loaded ${clips.length} clips (page $page, limit $limit)');
      return clips;
    } on DioException catch (e) {
      debugPrint('❌ ImprovedClipApi: Error fetching clips: ${e.message}');

      // Fallback to cache if available
      if (_pageCache.containsKey(cacheKey)) {
        debugPrint('⚠️ ImprovedClipApi: Returning stale cache due to error');
        return _pageCache.get(cacheKey)!;
      }

      // Try to return any cached clips
      if (_clipCache.length > 0) {
        final allCached = _clipCache.values.toList();
        final skip = (page - 1) * limit;
        final cachedPage = allCached.skip(skip).take(limit).toList();
        if (cachedPage.isNotEmpty) {
          debugPrint('⚠️ ImprovedClipApi: Returning cached clips as fallback');
          return cachedPage;
        }
      }

      return [];
    } catch (e) {
      debugPrint('❌ ImprovedClipApi: Unexpected error: $e');
      return [];
    }
  }

  /// Get clips by project ID with pagination
  Future<List<ClipModel>> getClipsByProject(
    String projectId, {
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'clips_by_project_${projectId}_page_${page}_limit_$limit';

    // Check cache first
    if (!forceRefresh &&
        _isPageCacheValid(cacheKey) &&
        _pageCache.containsKey(cacheKey)) {
      return _pageCache.get(cacheKey)!;
    }

    try {
      // Try server-side filtering first (if backend supports projectId param)
      try {
        final response = await _dioClient.dio.get(
          '/reels',
          queryParameters: {
            'projectId': projectId,
            'page': page,
            'limit': limit,
          },
        );
        List<dynamic> list;
        if (response.data is List) {
          list = response.data as List;
        } else if (response.data is Map<String, dynamic>) {
          final map = response.data as Map<String, dynamic>;
          list = (map['reels'] as List<dynamic>?) ??
              (map['data'] as List<dynamic>?) ??
              (map['clips'] as List<dynamic>?) ??
              <dynamic>[];
        } else {
          list = <dynamic>[];
        }
        if (list.isNotEmpty) {
          final clips = list
              .map((e) => ClipModel.fromJson(e as Map<String, dynamic>))
              .toList();
          for (var clip in clips) {
            _clipCache.put(clip.id, clip);
            _updateCacheTimestamp(clip.id);
          }
          _pageCache.put(cacheKey, clips);
          _updatePageCacheTimestamp(cacheKey);
          await _syncLikedStatus(clips);
          debugPrint(
              '✅ ImprovedClipApi: Fetched ${clips.length} clips for project $projectId (server-side)');
          return clips;
        }
      } on DioException catch (_) {
        // Backend may not support projectId - fall through to local filter
      }

      // Fallback: fetch and filter locally (when backend has no projectId support)
      final allClips =
          await getAllClips(page: 1, limit: 1000, forceRefresh: forceRefresh);
      final filtered =
          allClips.where((clip) => clip.projectId == projectId).toList();

      // Apply pagination
      final skip = (page - 1) * limit;
      final paginated = filtered.skip(skip).take(limit).toList();

      // Cache the result
      _pageCache.put(cacheKey, paginated);
      _updatePageCacheTimestamp(cacheKey);

      return paginated;
    } catch (e) {
      debugPrint('❌ ImprovedClipApi: Error getting clips by project: $e');

      // Fallback to cache
      if (_pageCache.containsKey(cacheKey)) {
        return _pageCache.get(cacheKey)!;
      }

      // Try to filter from individual cache
      final cached = _clipCache.values
          .where((clip) => clip.projectId == projectId)
          .toList();
      final skip = (page - 1) * limit;
      return cached.skip(skip).take(limit).toList();
    }
  }

  /// Get a single clip by ID
  Future<ClipModel?> getClipById(String clipId,
      {bool forceRefresh = false}) async {
    // Check cache first
    if (!forceRefresh &&
        _isCacheValid(clipId) &&
        _clipCache.containsKey(clipId)) {
      debugPrint('⚡ ImprovedClipApi: Returning clip $clipId from cache');
      return _clipCache.get(clipId);
    }

    try {
      final response = await _dioClient.dio.get('/reels/$clipId');
      final clip = ClipModel.fromJson(response.data as Map<String, dynamic>);

      // Update cache
      _clipCache.put(clipId, clip);
      _updateCacheTimestamp(clipId);

      // Sync liked status
      await _syncLikedStatus([clip]);

      return clip;
    } catch (e) {
      debugPrint('❌ ImprovedClipApi: Error fetching clip $clipId: $e');

      // Return from cache if available (even if expired)
      if (_clipCache.containsKey(clipId)) {
        return _clipCache.get(clipId);
      }

      return null;
    }
  }

  /// Check if a clip is liked (uses cache first)
  Future<bool> isClipLiked(String clipId) async {
    // Check local cache first (instant!)
    if (_likedCache.containsKey(clipId)) {
      return _likedCache[clipId]!;
    }

    // Check clip cache
    if (_clipCache.containsKey(clipId)) {
      return _clipCache.get(clipId)!.isLiked;
    }

    // If not in cache, assume not liked (backend doesn't support this yet)
    return false;
  }

  /// Prevent liked cache from growing unbounded
  void _cleanupLikedCache() {
    if (_likedCache.length > _likedCacheMaxSize) {
      final entries = _likedCache.entries.toList();
      final toKeep = entries.sublist(entries.length - 500);
      _likedCache.clear();
      for (var e in toKeep) {
        _likedCache[e.key] = e.value;
      }
      debugPrint(
          '🧹 ImprovedClipApi: Cleaned liked cache, kept 500 most recent');
    }
  }

  /// Like a clip with optimistic update
  Future<ClipModel> likeClip(String clipId) async {
    // IMMEDIATELY update cache (optimistic)
    _likedCache[clipId] = true;
    _cleanupLikedCache();
    _scheduleSaveLikedClipsToCache();

    ClipModel? originalClip;
    if (_clipCache.containsKey(clipId)) {
      originalClip = _clipCache.get(clipId)!;
      final updatedClip = originalClip.copyWith(
        likes: originalClip.likes + 1,
        isLiked: true,
      );
      _clipCache.put(clipId, updatedClip);
      _updateCacheTimestamp(clipId);
    }

    try {
      // Call API (if backend supports it)
      // Note: Backend doesn't support like endpoint yet, so this is a no-op
      // When backend is ready, uncomment:
      // await _dioClient.dio.post('/reels/$clipId/like');

      // Return updated clip
      if (_clipCache.containsKey(clipId)) {
        return _clipCache.get(clipId)!;
      }

      // If clip not in cache, fetch it
      final clip = await getClipById(clipId);
      if (clip != null) {
        return clip.copyWith(
          likes: clip.likes + 1,
          isLiked: true,
        );
      }

      // Fallback: create a minimal clip
      return ClipModel(
        id: clipId,
        projectId: '',
        likes: 1,
        isLiked: true,
      );
    } catch (e) {
      debugPrint('❌ ImprovedClipApi: Error liking clip: $e');

      // ROLLBACK on error (persist immediately)
      _likedCache[clipId] = false;
      await flush();

      if (originalClip != null) {
        _clipCache.put(clipId, originalClip);
        _updateCacheTimestamp(clipId);
      }

      rethrow;
    }
  }

  /// Unlike a clip with optimistic update
  Future<ClipModel> unlikeClip(String clipId) async {
    // IMMEDIATELY update cache (optimistic)
    _likedCache[clipId] = false;
    _scheduleSaveLikedClipsToCache();

    ClipModel? originalClip;
    if (_clipCache.containsKey(clipId)) {
      originalClip = _clipCache.get(clipId)!;
      final updatedClip = originalClip.copyWith(
        likes: (originalClip.likes - 1).clamp(0, double.infinity).toInt(),
        isLiked: false,
      );
      _clipCache.put(clipId, updatedClip);
      _updateCacheTimestamp(clipId);
    }

    try {
      // Call API (if backend supports it)
      // Note: Backend doesn't support unlike endpoint yet, so this is a no-op
      // When backend is ready, uncomment:
      // await _dioClient.dio.post('/reels/$clipId/unlike');

      // Return updated clip
      if (_clipCache.containsKey(clipId)) {
        return _clipCache.get(clipId)!;
      }

      // If clip not in cache, fetch it
      final clip = await getClipById(clipId);
      if (clip != null) {
        return clip.copyWith(
          likes: (clip.likes - 1).clamp(0, double.infinity).toInt(),
          isLiked: false,
        );
      }

      // Fallback: create a minimal clip
      return ClipModel(
        id: clipId,
        projectId: '',
        likes: 0,
        isLiked: false,
      );
    } catch (e) {
      debugPrint('❌ ImprovedClipApi: Error unliking clip: $e');

      // ROLLBACK on error (persist immediately)
      if (originalClip != null && originalClip.isLiked) {
        _likedCache[clipId] = true;
        await flush();
        _clipCache.put(clipId, originalClip);
        _updateCacheTimestamp(clipId);
      }

      rethrow;
    }
  }

  /// Add a new reel with upload progress tracking
  Future<ClipModel?> addReel({
    required String title,
    required String description,
    required String? videoPath,
    String? projectId,
    required bool hasWhatsApp,
    String? developerId,
    String? developerName,
    String? developerLogo,
    String? thumbnailPath,
    Function(int sent, int total)? onUploadProgress,
  }) async {
    if (videoPath == null || videoPath.isEmpty) {
      throw Exception('Video path is required');
    }

    // Validate file exists
    final file = File(videoPath);
    if (!await file.exists()) {
      throw Exception('Video file not found: $videoPath');
    }

    try {
      final form = <String, dynamic>{
        'title': title,
        'description': description,
        'file': await MultipartFile.fromFile(videoPath),
      };

      if (projectId != null && projectId.isNotEmpty) {
        form['projectId'] = projectId;
      }

      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        form['thumbnail'] = await MultipartFile.fromFile(thumbnailPath);
      }

      final response = await _dioClient.dio.post(
        '/reels',
        data: FormData.fromMap(form),
        onSendProgress: (sent, total) {
          onUploadProgress?.call(sent, total);
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final clip = ClipModel.fromJson(response.data as Map<String, dynamic>);

        // Update cache
        _clipCache.put(clip.id, clip);
        _updateCacheTimestamp(clip.id);

        // Clear page cache to force refresh
        _pageCache.clear();
        _pageCacheTimestamps.clear();

        debugPrint('✅ ImprovedClipApi: Reel uploaded successfully: ${clip.id}');
        return clip;
      }

      return null;
    } catch (e) {
      debugPrint('❌ ImprovedClipApi: Error uploading reel: $e');
      rethrow;
    }
  }

  /// Sync liked status for clips (loads from SharedPreferences)
  Future<void> _syncLikedStatus(List<ClipModel> clips) async {
    for (var clip in clips) {
      if (_likedCache.containsKey(clip.id)) {
        // Update clip with cached liked status
        final updatedClip = clip.copyWith(isLiked: _likedCache[clip.id]!);
        _clipCache.put(clip.id, updatedClip);
      }
    }
  }

  /// Load cached clips from local storage (offline support)
  Future<List<ClipModel>> loadCachedClipsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cachedClipsKey);

      if (cachedJson != null) {
        final List<dynamic> list = jsonDecode(cachedJson);
        final clips = list
            .map((e) => ClipModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Update cache
        for (var clip in clips) {
          _clipCache.put(clip.id, clip);
          _updateCacheTimestamp(clip.id);
        }

        // Sync liked status
        await _syncLikedStatus(clips);

        debugPrint(
            '✅ ImprovedClipApi: Loaded ${clips.length} clips from local storage');
        return clips;
      }
    } catch (e) {
      debugPrint('⚠️ ImprovedClipApi: Error loading cached clips: $e');
    }

    // Fallback to in-memory cache
    if (_clipCache.length > 0) {
      return _clipCache.values.toList();
    }

    return [];
  }

  /// Cache clips locally for offline access
  Future<void> cacheClipsLocally(List<ClipModel> clips) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(clips.map((c) => c.toJson()).toList());
      await prefs.setString(_cachedClipsKey, json);

      // Also update in-memory cache
      for (var clip in clips) {
        _clipCache.put(clip.id, clip);
        _updateCacheTimestamp(clip.id);
      }

      debugPrint('✅ ImprovedClipApi: Cached ${clips.length} clips locally');
    } catch (e) {
      debugPrint('⚠️ ImprovedClipApi: Error caching clips: $e');
    }
  }

  /// Clear all caches
  Future<void> clearCache() async {
    _clipCache.clear();
    _likedCache.clear();
    _cacheTimestamps.clear();
    _pageCache.clear();
    _pageCacheTimestamps.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_likedClipsKey);
      await prefs.remove(_cachedClipsKey);
      debugPrint('✅ ImprovedClipApi: Cleared all caches');
    } catch (e) {
      debugPrint('⚠️ ImprovedClipApi: Error clearing SharedPreferences: $e');
    }
  }

  /// Get cache statistics (includes LRU stats for debugging)
  Map<String, dynamic> getCacheStats() {
    return {
      'clipCache': _clipCache.stats,
      'pageCache': _pageCache.stats,
      'likedCacheSize': _likedCache.length,
      'likedCacheMaxSize': _likedCacheMaxSize,
      'cacheExpiryMinutes': _cacheExpiry.inMinutes,
    };
  }
}
