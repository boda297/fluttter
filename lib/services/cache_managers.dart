import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// CacheManager for Home page media (images and videos)
/// Cache duration: 3 days
class CacheManagerHome {
  static const String key = 'homeCacheKey';
  
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 100,
    ),
  );
}

/// CacheManager for Reels page media (thumbnails and videos)
/// DISABLED: Video caching is disabled (maxNrOfCacheObjects: 0)
class CacheManagerReels {
  static const String key = 'reelsCacheKey';
  
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 0), // No caching
      maxNrOfCacheObjects: 0, // Disable caching completely
    ),
  );
}

/// CacheManager for Project Hero media (hero image or video)
/// Cache duration: 3 days
/// Only caches hero media when user opens a project
class CacheManagerProjectHero {
  static const String key = 'projectHeroCacheKey';
  
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 50,
    ),
  );
}
