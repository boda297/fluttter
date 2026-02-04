import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'cache_managers.dart';
import '../models/project_model.dart';
import '../models/clip_model.dart';

/// Centralized Cache Service for media caching
/// 
/// This service provides methods to cache media content for:
/// - Home page (images and videos)
/// - Reels page (thumbnails and videos)
/// - Project Details (hero media only)
/// 
/// All caching operations run asynchronously in the background
/// and do not block the UI.
class CacheService {
  // Singleton instance
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  /// Cache all images and videos from Home page content
  /// 
  /// Called in initState() or after data is loaded in Home page
  /// Uses CacheManagerHome with 3-day expiration
  Future<void> cacheHomeContent(List<ProjectModel> items) async {
    debugPrint('🏠 CacheService: Starting to cache ${items.length} home items...');
    
    for (final item in items) {
      // Cache project thumbnail/image
      if (item.projectThumbnailUrl.isNotEmpty && _isValidUrl(item.projectThumbnailUrl)) {
        _cacheFile(item.projectThumbnailUrl, CacheManagerHome.instance, 'Home image');
      } else if (item.image.isNotEmpty && _isValidUrl(item.image)) {
        _cacheFile(item.image, CacheManagerHome.instance, 'Home image');
      }
      
      // Cache advertisement video (hero video)
      if (item.advertisementVideoUrl.isNotEmpty && _isValidUrl(item.advertisementVideoUrl)) {
        _cacheFile(item.advertisementVideoUrl, CacheManagerHome.instance, 'Home video');
      }
    }
    
    debugPrint('✅ CacheService: Home content caching initiated');
  }

  /// Cache all thumbnails and videos from Reels page content
  /// 
  /// DISABLED: Video caching is disabled to save storage space
  /// Called in initState() after clips are loaded in Reels page
  /// Uses CacheManagerReels with 3-day expiration
  Future<void> cacheReelsContent(List<ClipModel> items) async {
    // ❌ DISABLED: Video caching is disabled
    debugPrint('🚫 CacheService: Video caching is DISABLED (${items.length} reel items skipped)');
    return;
    
    // OLD CODE (disabled):
    // for (final item in items) {
    //   // Cache thumbnail
    //   if (item.thumbnail.isNotEmpty && _isValidUrl(item.thumbnail)) {
    //     _cacheFile(item.thumbnail, CacheManagerReels.instance, 'Reel thumbnail');
    //   }
    //   
    //   // Cache video
    //   if (item.videoUrl.isNotEmpty && _isValidUrl(item.videoUrl)) {
    //     _cacheFile(item.videoUrl, CacheManagerReels.instance, 'Reel video');
    //   }
    // }
  }

  /// Cache ONLY the hero media (image or video) for a specific project
  /// 
  /// Called when user opens a project in Project Details page
  /// Uses CacheManagerProjectHero with 3-day expiration
  /// 
  /// Does NOT cache the main project video
  Future<void> cacheProjectHeroImage(String projectId, String heroImageUrl) async {
    if (heroImageUrl.isEmpty || !_isValidUrl(heroImageUrl)) {
      debugPrint('⚠️ CacheService: Invalid hero URL for project $projectId');
      return;
    }
    
    debugPrint('🖼️ CacheService: Caching hero media for project $projectId...');
    await _cacheFile(heroImageUrl, CacheManagerProjectHero.instance, 'Project hero');
    debugPrint('✅ CacheService: Project hero cached for project $projectId');
  }

  /// Get a cached file if it exists and is valid
  /// Returns the File if cached, null otherwise
  Future<FileInfo?> getCachedFile(String url, CacheManager cacheManager) async {
    try {
      final fileInfo = await cacheManager.getFileFromCache(url);
      if (fileInfo != null) {
        debugPrint('📁 CacheService: Found cached file for $url');
        return fileInfo;
      }
    } catch (e) {
      debugPrint('❌ CacheService: Error getting cached file: $e');
    }
    return null;
  }

  /// Get cached file path for a URL from Home cache
  Future<String?> getHomeCachedFilePath(String url) async {
    final fileInfo = await getCachedFile(url, CacheManagerHome.instance);
    return fileInfo?.file.path;
  }

  /// Get cached file path for a URL from Reels cache
  Future<String?> getReelsCachedFilePath(String url) async {
    final fileInfo = await getCachedFile(url, CacheManagerReels.instance);
    return fileInfo?.file.path;
  }

  /// Get cached file path for a URL from Project Hero cache
  Future<String?> getProjectHeroCachedFilePath(String url) async {
    final fileInfo = await getCachedFile(url, CacheManagerProjectHero.instance);
    return fileInfo?.file.path;
  }

  /// Download and get a file, using cache if available
  /// This is the main method to get files with caching support
  Future<String?> getFileWithCache(String url, CacheManager cacheManager) async {
    if (url.isEmpty || !_isValidUrl(url)) {
      return null;
    }
    
    try {
      final file = await cacheManager.getSingleFile(url);
      return file.path;
    } catch (e) {
      debugPrint('❌ CacheService: Error getting file with cache: $e');
      return null;
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await CacheManagerHome.instance.emptyCache();
    await CacheManagerReels.instance.emptyCache();
    await CacheManagerProjectHero.instance.emptyCache();
    debugPrint('🗑️ CacheService: All caches cleared');
  }

  /// Clear specific cache
  Future<void> clearHomeCache() async {
    await CacheManagerHome.instance.emptyCache();
    debugPrint('🗑️ CacheService: Home cache cleared');
  }

  Future<void> clearReelsCache() async {
    try {
      await CacheManagerReels.instance.emptyCache();
      debugPrint('🗑️ CacheService: Reels cache cleared');
    } catch (e) {
      debugPrint('⚠️ CacheService: Error clearing reels cache: $e');
    }
  }
  
  /// Clear all video caches immediately (called on app start or when needed)
  Future<void> clearAllVideoCaches() async {
    try {
      await clearReelsCache();
      debugPrint('🗑️ CacheService: All video caches cleared');
    } catch (e) {
      debugPrint('⚠️ CacheService: Error clearing video caches: $e');
    }
  }

  Future<void> clearProjectHeroCache() async {
    await CacheManagerProjectHero.instance.emptyCache();
    debugPrint('🗑️ CacheService: Project hero cache cleared');
  }

  /// Helper method to cache a file in the background
  Future<void> _cacheFile(String url, CacheManager cacheManager, String type) async {
    try {
      // Check if already cached and valid
      final existingFile = await cacheManager.getFileFromCache(url);
      if (existingFile != null) {
        // Check if cache is still valid (within 3 days)
        final validTill = existingFile.validTill;
        if (validTill.isAfter(DateTime.now())) {
          debugPrint('📦 CacheService: $type already cached and valid: $url');
          return;
        }
      }
      
      // Download and cache in background
      unawaited(
        cacheManager.downloadFile(url).then((_) {
          debugPrint('✅ CacheService: Cached $type: $url');
        }).catchError((e) {
          debugPrint('❌ CacheService: Error caching $type: $e');
        }),
      );
    } catch (e) {
      debugPrint('❌ CacheService: Error in _cacheFile: $e');
    }
  }

  /// Check if URL is valid (not empty, not asset path)
  bool _isValidUrl(String url) {
    return url.isNotEmpty && 
           (url.startsWith('http://') || url.startsWith('https://'));
  }
}
