import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dio_client.dart';
import '../../models/project_model.dart';
import '../../models/episode_model.dart';
import '../../models/clip_model.dart';
import '../../models/pdf_file_model.dart';
import '../../models/watch_history_model.dart';
import '../../utils/cache_manager.dart';
import 'watch_history_api.dart';

class ProjectApi {
  final DioClient _dioClient = DioClient();
  final WatchHistoryApi _watchHistoryApi = WatchHistoryApi();

  // In-memory cache for reels (fastest access)
  static List<ClipModel>? _reelsMemoryCache;
  static DateTime? _reelsCacheTime;
  static const Duration _reelsCacheDuration = Duration(minutes: 5);

  // In-memory cache for saved reels
  static Set<String>? _savedReelIdsCache;
  static DateTime? _savedReelsCacheTime;
  static const Duration _savedReelsCacheDuration = Duration(minutes: 2);

  ProjectApi() {
    _dioClient.init();
  }

  /// Clear all reels caches (memory + local storage)
  static Future<void> clearReelsCache() async {
    _reelsMemoryCache = null;
    _reelsCacheTime = null;
    _savedReelIdsCache = null;
    _savedReelsCacheTime = null;
    await CacheManager.clear('all_reels');
    print('🗑️ Cleared all reels caches');
  }

  /// GET /projects/:id
  Future<ProjectModel?> getProjectById(String id) async {
    try {
      final response = await _dioClient.dio.get('/projects/$id');
      return ProjectModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// GET /episode, then filter by projectId
  Future<List<EpisodeModel>> getEpisodes(String projectId) async {
    try {
      final response = await _dioClient.dio.get('/episode');
      final list = response.data is List ? response.data as List : <dynamic>[];
      final out = <EpisodeModel>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>?;
        if (m == null) continue;
        final pid = _resolveId(m['projectId']);
        if (pid == projectId) out.add(EpisodeModel.fromJson(m));
      }
      out.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
      return out;
    } on DioException catch (_) {
      return [];
    }
  }

  String? _resolveId(dynamic v) {
    if (v == null) return null;
    if (v is Map) return v['_id']?.toString() ?? v['id']?.toString();
    return v.toString();
  }

  static const String _episodeContentPrefix = 'episode__';

  /// Creates a stable, URL-safe contentId for Watch History that still encodes projectId + episodeId.
  /// Example: episode__<projectId>__<episodeId>
  static String makeEpisodeContentId(String projectId, String episodeId) {
    return '$_episodeContentPrefix$projectId\_\_$episodeId';
  }

  static ({String projectId, String episodeId})? parseEpisodeContentId(
      String contentId) {
    if (!contentId.startsWith(_episodeContentPrefix)) return null;
    final rest = contentId.substring(_episodeContentPrefix.length);
    final parts = rest.split('__');
    if (parts.length != 2) return null;
    return (projectId: parts[0], episodeId: parts[1]);
  }

  Future<bool> _hasAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  /// Uses local cache (updated on save/unsave). PATCH /projects/:id/save-project does not return savedProjects.
  Future<bool> isProjectSaved(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('saved_projects') ?? [];
    return ids.contains(projectId);
  }

  /// PATCH /projects/:id/save-project — no body. On success, add to local cache.
  Future<void> saveProject(String projectId) async {
    await _dioClient.dio.patch('/projects/$projectId/save-project');
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('saved_projects') ?? [];
    if (!ids.contains(projectId)) {
      ids.add(projectId);
      await prefs.setStringList('saved_projects', ids);
    }
  }

  /// PATCH /projects/:id/unsave-project — no body. On success, remove from local cache.
  Future<void> unsaveProject(String projectId) async {
    await _dioClient.dio.patch('/projects/$projectId/unsave-project');
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('saved_projects') ?? [];
    ids.remove(projectId);
    await prefs.setStringList('saved_projects', ids);
  }

  /// Get saved projects (GET /users/saved-projects or GET /projects/saved)
  /// Falls back to local cache if backend unavailable
  Future<List<ProjectModel>> getSavedProjects() async {
    try {
      if (await _hasAuthToken()) {
        // Try GET /users/saved-projects first (returns { message, savedProjects: [...] })
        try {
          print('📡 Fetching saved projects from /users/saved-projects...');
          final response = await _dioClient.dio.get('/users/saved-projects');
          final data = response.data;

          List<dynamic>? projectsList;
          if (data is Map<String, dynamic>) {
            // Handle { message, savedProjects: [...] } format
            projectsList = data['savedProjects'] as List<dynamic>?;
          } else if (data is List) {
            // Handle direct array format
            projectsList = data;
          }

          if (projectsList != null && projectsList.isNotEmpty) {
            final projects = projectsList
                .map((e) {
                  try {
                    // Handle both full project objects and IDs
                    if (e is Map<String, dynamic>) {
                      return ProjectModel.fromJson(e);
                    } else if (e is String) {
                      // If it's just an ID, we'll need to fetch it
                      return null;
                    }
                    return null;
                  } catch (e) {
                    print('⚠️ Error parsing saved project: $e');
                    return null;
                  }
                })
                .whereType<ProjectModel>()
                .toList();

            // If we got IDs instead of full objects, fetch them in parallel
            if (projects.isEmpty && projectsList.isNotEmpty) {
              final ids = projectsList
                  .map((e) => e.toString())
                  .where((id) => id.isNotEmpty)
                  .toList();
              final projectFutures = ids.map((id) => getProjectById(id));
              final fetchedProjects = await Future.wait(projectFutures);
              projects.addAll(fetchedProjects.whereType<ProjectModel>());
            }

            // Update local cache
            final prefs = await SharedPreferences.getInstance();
            final ids = projects.map((p) => p.id).toList();
            await prefs.setStringList('saved_projects', ids);

            print(
                '✅ Loaded ${projects.length} saved projects from /users/saved-projects');
            return projects;
          }
        } catch (e) {
          print(
              '⚠️ /users/saved-projects failed: $e, trying /projects/saved...');
        }

        // Fallback: Try GET /projects/saved (returns array directly)
        try {
          print('📡 Fetching saved projects from /projects/saved...');
          final response = await _dioClient.dio.get('/projects/saved');
          final data = response.data;

          List<dynamic> projectsList;
          if (data is List) {
            projectsList = data;
          } else if (data is Map<String, dynamic> && data['projects'] is List) {
            projectsList = data['projects'] as List;
          } else {
            projectsList = <dynamic>[];
          }

          if (projectsList.isNotEmpty) {
            final projects = projectsList
                .map((e) {
                  try {
                    return ProjectModel.fromJson(e as Map<String, dynamic>);
                  } catch (e) {
                    print('⚠️ Error parsing saved project: $e');
                    return null;
                  }
                })
                .whereType<ProjectModel>()
                .toList();

            // Update local cache
            final prefs = await SharedPreferences.getInstance();
            final ids = projects.map((p) => p.id).toList();
            await prefs.setStringList('saved_projects', ids);

            print(
                '✅ Loaded ${projects.length} saved projects from /projects/saved');
            return projects;
          }
        } catch (e) {
          print('⚠️ /projects/saved also failed: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error fetching saved projects from backend: $e');
    }

    // Fallback to local cache - fetch projects in parallel
    print('📦 Using local cache for saved projects...');
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('saved_projects') ?? [];
    final projectFutures = ids.map((id) => getProjectById(id));
    final projects = await Future.wait(projectFutures);
    final out = projects.whereType<ProjectModel>().toList();
    print('✅ Loaded ${out.length} saved projects from local cache');
    return out;
  }

  /// Progress stored locally; still used as offline fallback.
  Future<void> trackWatching(
      String projectId, String episodeId, double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('watch_progress_${projectId}_$episodeId', progress);
  }

  Future<double> getWatchingProgress(String projectId, String episodeId) async {
    // Try backend watch-history first (if logged in), then fall back to local cache.
    try {
      if (await _hasAuthToken()) {
        final contentId = makeEpisodeContentId(projectId, episodeId);
        final w = await _watchHistoryApi.getContentProgress(contentId);
        if (w != null && w.duration > 0) {
          final frac = (w.currentTime / w.duration).clamp(0.0, 1.0);
          // Cache locally as well (for faster UI + offline fallback)
          await trackWatching(projectId, episodeId, frac);
          return frac;
        }
      }
    } catch (_) {
      // ignore, fallback to local
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('watch_progress_${projectId}_$episodeId') ?? 0.0;
  }

  /// Update watch progress on backend (Watch History) and keep local cache in sync.
  Future<void> updateEpisodeWatchProgress({
    required String projectId,
    required EpisodeModel episode,
    required String projectTitle,
    required double currentTimeSeconds,
    required double durationSeconds,
  }) async {
    final frac = durationSeconds > 0
        ? (currentTimeSeconds / durationSeconds).clamp(0.0, 1.0)
        : 0.0;
    await trackWatching(projectId, episode.id, frac);

    try {
      if (!await _hasAuthToken()) return;
      final contentId = makeEpisodeContentId(projectId, episode.id);
      await _watchHistoryApi.upsertProgress(
        contentId: contentId,
        contentTitle: projectTitle.isNotEmpty
            ? projectTitle
            : (episode.title.isNotEmpty
                ? episode.title
                : 'Episode ${episode.episodeNumber}'),
        contentThumbnail:
            episode.thumbnail.isNotEmpty ? episode.thumbnail : null,
        currentTimeSeconds: currentTimeSeconds,
        durationSeconds: durationSeconds,
        contentType: 'episode',
        episode: episode.episodeNumber,
      );
    } catch (_) {
      // Ignore backend sync errors; local cache still works.
    }
  }

  /// Returns the last watched episodeId for a given project using backend watch-history if available.
  Future<String?> getLastWatchedEpisodeId(String projectId) async {
    try {
      if (!await _hasAuthToken()) return null;
      final items = await _watchHistoryApi.getContinueWatching(limit: 100);
      WatchHistoryModel? best;
      for (final w in items) {
        final parsed = parseEpisodeContentId(w.contentId);
        if (parsed == null) continue;
        if (parsed.projectId != projectId) continue;
        if (best == null || w.lastWatchedAt.isAfter(best.lastWatchedAt)) {
          best = w;
        }
      }
      return best == null
          ? null
          : parseEpisodeContentId(best.contentId)?.episodeId;
    } catch (_) {
      return null;
    }
  }

  /// Continue watching list:
  /// - If logged in: derived from /watch-history/continue-watching
  /// - Otherwise: derived from local progress cache
  Future<List<ProjectModel>> getContinueWatchingProjects() async {
    // Prefer backend watch history if logged in.
    try {
      if (await _hasAuthToken()) {
        print('📺 Fetching continue watching from backend...');
        final items = await _watchHistoryApi.getContinueWatching(limit: 100);
        print('📺 Got ${items.length} items from watch history API');

        final Map<String, ({double progress, DateTime lastWatchedAt})>
            byProject = {};

        for (final w in items) {
          final parsed = parseEpisodeContentId(w.contentId);
          if (parsed == null) {
            print('⚠️ Could not parse contentId: ${w.contentId}');
            continue;
          }
          final pid = parsed.projectId;
          final frac = (w.progressPercentage / 100.0).clamp(0.0, 1.0);
          if (frac <= 0 || frac >= 0.9) {
            print(
                '⏭️ Skipping ${w.contentTitle}: progress=$frac (${w.progressPercentage}%)');
            continue;
          }

          final existing = byProject[pid];
          if (existing == null ||
              w.lastWatchedAt.isAfter(existing.lastWatchedAt)) {
            byProject[pid] = (progress: frac, lastWatchedAt: w.lastWatchedAt);
            print(
                '✅ Added project $pid: progress=${(frac * 100).toStringAsFixed(1)}%');
          }
        }

        print('📊 Found ${byProject.length} unique projects with progress');

        // Fetch all projects in parallel for better performance
        final projectIds = byProject.keys.toList();
        final projectFutures = projectIds.map((id) => getProjectById(id));
        final projects = await Future.wait(projectFutures);

        final out = <ProjectModel>[];
        for (var i = 0; i < projectIds.length; i++) {
          final p = projects[i];
          if (p != null) {
            final e = byProject[projectIds[i]]!;
            // Debug: Print image fields for continue watching projects
            if (out.length < 3) {
              print('📸 Continue watching project ${out.length} image fields:');
              print('   projectThumbnailUrl: "${p.projectThumbnailUrl}"');
              print('   image: "${p.image}"');
              print('   logo: "${p.logo}"');
            }
            out.add(p.copyWith(watchProgress: e.progress));
          } else {
            print('⚠️ Project ${projectIds[i]} not found');
          }
        }

        out.sort((a, b) {
          final aT = byProject[a.id]?.lastWatchedAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bT = byProject[b.id]?.lastWatchedAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bT.compareTo(aT);
        });

        print('✅ Returning ${out.length} continue watching projects');
        return out;
      } else {
        print('ℹ️ User not logged in, using local cache for continue watching');
      }
    } catch (e) {
      print('❌ Error fetching continue watching from backend: $e');
      print('📦 Falling back to local cache...');
      // fallback below
    }

    // Local-only fallback (old behavior)
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('watch_progress_'));
    final Map<String, double> byProject = {};
    for (final k in keys) {
      final rest = k.replaceFirst('watch_progress_', '');
      final i = rest.lastIndexOf('_');
      if (i <= 0 || i >= rest.length - 1) continue;
      final pid = rest.substring(0, i);
      final prog = prefs.getDouble(k) ?? 0.0;
      if (prog > 0 && prog < 0.95) {
        if (!byProject.containsKey(pid) || (byProject[pid] ?? 0) < prog) {
          byProject[pid] = prog;
        }
      }
    }
    // Fetch all projects in parallel for better performance
    final projectIds = byProject.keys.toList();
    final projectFutures = projectIds.map((id) => getProjectById(id));
    final projects = await Future.wait(projectFutures);

    final out = <ProjectModel>[];
    for (var i = 0; i < projectIds.length; i++) {
      final p = projects[i];
      if (p != null)
        out.add(p.copyWith(watchProgress: byProject[projectIds[i]]));
    }
    out.sort((a, b) => (b.watchProgress ?? 0).compareTo(a.watchProgress ?? 0));
    return out;
  }

  /// GET /reels, filter by projectId, map to ClipModel (reels used as clips)
  /// Reuses cached reels from getAllClips for better performance
  Future<List<ClipModel>> getClipsByProject(String projectId) async {
    try {
      // Use getAllClips with cache to avoid duplicate API calls
      final allClips = await getAllClips();
      return allClips.where((clip) => clip.projectId == projectId).toList();
    } catch (_) {
      return [];
    }
  }

  /// GET /reels (with two-layer caching: in-memory + local storage)
  /// Supports optional pagination; omit page/limit to fetch all (backward compatible)
  Future<List<ClipModel>> getAllClips({
    bool useCache = true,
    int? page,
    int? limit,
  }) async {
    final cacheKey =
        'all_reels${page != null ? '_page_${page}_limit_$limit' : ''}';

    // Layer 1: Check in-memory cache first (only for non-paginated "all" request)
    if (page == null &&
        limit == null &&
        useCache &&
        _reelsMemoryCache != null &&
        _reelsCacheTime != null) {
      if (DateTime.now().difference(_reelsCacheTime!) < _reelsCacheDuration) {
        print(
            '⚡ Returning ${_reelsMemoryCache!.length} reels from memory cache');
        return _reelsMemoryCache!;
      }
    }

    // Layer 2: Try local cache
    if (useCache) {
      try {
        final cached = await CacheManager.get<List<dynamic>>(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          print('📦 Returning ${cached.length} reels from local cache');
          final clips = cached
              .map((e) => ClipModel.fromJson(e as Map<String, dynamic>))
              .toList();
          // Update memory cache
          _reelsMemoryCache = clips;
          _reelsCacheTime = DateTime.now();
          return clips;
        }
      } catch (e) {
        print('⚠️ Error reading reels from local cache: $e');
        // Continue to fetch from API
      }
    }

    // Layer 3: Fetch from API
    try {
      print('📡 Fetching reels from API...');
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;
      final response = await _dioClient.dio.get(
        '/reels',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      print('📡 Response status: ${response.statusCode}');
      print('📡 Response data type: ${response.data.runtimeType}');

      // Handle both response formats:
      // 1. Direct array: [...]
      // 2. Object with reels: { reels: [...], Count: 71 }
      List<dynamic> list;
      if (response.data is List) {
        list = response.data as List;
        print('📡 Response is direct array with ${list.length} items');
      } else if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        // Try 'reels' key first, then 'data', then fall back to empty
        list = (map['reels'] as List<dynamic>?) ??
            (map['data'] as List<dynamic>?) ??
            <dynamic>[];
        print(
            '📡 Response is object, found ${list.length} reels in "reels" key');
      } else {
        list = <dynamic>[];
        print('⚠️ Unexpected response format: ${response.data.runtimeType}');
      }

      print('📡 Parsing ${list.length} reels...');
      final clips = <ClipModel>[];
      for (var i = 0; i < list.length; i++) {
        try {
          final clip = ClipModel.fromJson(list[i] as Map<String, dynamic>);
          clips.add(clip);
        } catch (e) {
          print('⚠️ Error parsing reel $i: $e');
          // Skip this reel but continue with others
        }
      }
      print('✅ Successfully parsed ${clips.length} reels');

      // Update caches (memory cache only for non-paginated)
      if (clips.isNotEmpty) {
        if (page == null && limit == null) {
          _reelsMemoryCache = clips;
          _reelsCacheTime = DateTime.now();
        }
        await CacheManager.set(cacheKey, list,
            duration: const Duration(minutes: 10));
        print('💾 Cached ${clips.length} reels');
      }

      return clips;
    } on DioException catch (e) {
      print('❌ DioException in getAllClips: ${e.type} - ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}');
        print('   Data: ${e.response?.data}');
      }
      // Return memory cache if available, even if expired
      if (_reelsMemoryCache != null) {
        print('⚠️ API failed, returning stale memory cache');
        return _reelsMemoryCache!;
      }
      return [];
    } catch (e) {
      print('❌ Unexpected error in getAllClips: $e');
      // Return memory cache if available
      if (_reelsMemoryCache != null) {
        return _reelsMemoryCache!;
      }
      return [];
    }
  }

  /// Check if a reel is saved (optimized - doesn't fetch full list)
  Future<bool> isReelSaved(String reelId) async {
    try {
      if (!await _hasAuthToken()) {
        return false;
      }

      // Quick check: Try to get saved reels from API
      // But don't wait too long - use timeout
      try {
        final response = await _dioClient.dio.get('/reels/saved').timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            throw TimeoutException('Request timeout');
          },
        );

        final data = response.data;
        List<dynamic> reelsList;

        if (data is List) {
          reelsList = data;
        } else if (data is Map<String, dynamic>) {
          reelsList = data['reels'] as List<dynamic>? ??
              data['savedReels'] as List<dynamic>? ??
              <dynamic>[];
        } else {
          reelsList = <dynamic>[];
        }

        // Check if reelId exists in the list
        for (final reel in reelsList) {
          if (reel is Map<String, dynamic>) {
            final id = _resolveId(reel['_id']) ?? _resolveId(reel['id']);
            if (id == reelId) {
              return true;
            }
          } else if (reel is String && reel == reelId) {
            return true;
          }
        }

        return false;
      } catch (e) {
        // If API call fails, return false (not saved)
        print('⚠️ Error checking if reel is saved: $e');
        return false;
      }
    } catch (e) {
      print('⚠️ Error in isReelSaved: $e');
      return false;
    }
  }

  /// POST /reels/:id/save — Save a reel to user's saved reels
  Future<bool> saveReel(String reelId) async {
    try {
      if (reelId.isEmpty) {
        print('⚠️ Cannot save reel: reelId is empty');
        return false;
      }

      final response = await _dioClient.dio.post('/reels/$reelId/save').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Save reel request timeout');
        },
      );

      final success = response.statusCode == 200 || response.statusCode == 201;

      // Update cache on success
      if (success && _savedReelIdsCache != null) {
        _savedReelIdsCache!.add(reelId);
      }

      return success;
    } on TimeoutException catch (e) {
      print('⚠️ Timeout saving reel: $e');
      return false;
    } on DioException catch (e) {
      print('⚠️ Error saving reel: ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}');
        print('   Data: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print('⚠️ Unexpected error saving reel: $e');
      return false;
    }
  }

  /// POST /reels/:id/unsave — Remove a reel from user's saved reels
  Future<bool> unsaveReel(String reelId) async {
    try {
      if (reelId.isEmpty) {
        print('⚠️ Cannot unsave reel: reelId is empty');
        return false;
      }

      final response =
          await _dioClient.dio.post('/reels/$reelId/unsave').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Unsave reel request timeout');
        },
      );

      final success = response.statusCode == 200 || response.statusCode == 201;

      // Update cache on success
      if (success && _savedReelIdsCache != null) {
        _savedReelIdsCache!.remove(reelId);
      }

      return success;
    } on TimeoutException catch (e) {
      print('⚠️ Timeout unsaving reel: $e');
      return false;
    } on DioException catch (e) {
      print('⚠️ Error unsaving reel: ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}');
        print('   Data: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print('⚠️ Unexpected error unsaving reel: $e');
      return false;
    }
  }

  /// Get saved reels (with in-memory caching)
  Future<List<ClipModel>> getSavedReels({bool useCache = true}) async {
    // Check in-memory cache first
    if (useCache &&
        _savedReelIdsCache != null &&
        _savedReelsCacheTime != null) {
      if (DateTime.now().difference(_savedReelsCacheTime!) <
          _savedReelsCacheDuration) {
        // Use cached reels from memory + filter by saved IDs
        if (_reelsMemoryCache != null) {
          final savedReels = _reelsMemoryCache!
              .where((clip) => _savedReelIdsCache!.contains(clip.id))
              .toList();
          print(
              '⚡ Returning ${savedReels.length} saved reels from memory cache');
          return savedReels;
        }
      }
    }

    try {
      if (await _hasAuthToken()) {
        // Try GET /users/saved-reels first (returns { message, savedReels: [...] })
        try {
          print('📡 Fetching saved reels from /users/saved-reels...');
          final response = await _dioClient.dio.get('/users/saved-reels');
          final data = response.data;

          List<dynamic>? reelsList;
          if (data is Map<String, dynamic>) {
            // Handle { message, savedReels: [...] } format
            reelsList = data['savedReels'] as List<dynamic>?;
          } else if (data is List) {
            // Handle direct array format
            reelsList = data;
          }

          if (reelsList != null && reelsList.isNotEmpty) {
            final reels = reelsList
                .map((e) {
                  try {
                    return ClipModel.fromJson(e as Map<String, dynamic>);
                  } catch (e) {
                    print('⚠️ Error parsing saved reel: $e');
                    return null;
                  }
                })
                .whereType<ClipModel>()
                .toList();

            // Update cache
            _savedReelIdsCache = reels.map((r) => r.id).toSet();
            _savedReelsCacheTime = DateTime.now();

            print(
                '✅ Loaded ${reels.length} saved reels from /users/saved-reels');
            return reels;
          }
        } catch (e) {
          print('⚠️ /users/saved-reels failed: $e, trying /reels/saved...');
        }

        // Fallback: Try GET /reels/saved (returns { message, reels: [...] })
        try {
          print('📡 Fetching saved reels from /reels/saved...');
          final response = await _dioClient.dio.get('/reels/saved');
          final data = response.data;

          List<dynamic> reelsList;
          if (data is List) {
            // Handle direct array format
            reelsList = data;
          } else if (data is Map<String, dynamic>) {
            // Handle { message, reels: [...] } format
            reelsList = data['reels'] as List<dynamic>? ?? <dynamic>[];
          } else {
            reelsList = <dynamic>[];
          }

          if (reelsList.isNotEmpty) {
            final reels = reelsList
                .map((e) {
                  try {
                    return ClipModel.fromJson(e as Map<String, dynamic>);
                  } catch (e) {
                    print('⚠️ Error parsing saved reel: $e');
                    return null;
                  }
                })
                .whereType<ClipModel>()
                .toList();

            // Update cache
            _savedReelIdsCache = reels.map((r) => r.id).toSet();
            _savedReelsCacheTime = DateTime.now();

            print('✅ Loaded ${reels.length} saved reels from /reels/saved');
            return reels;
          }
        } catch (e) {
          print('⚠️ /reels/saved also failed: $e');
        }
      }

      // Return empty list if not authenticated or all methods failed
      _savedReelIdsCache = {};
      _savedReelsCacheTime = DateTime.now();
      return [];
    } on DioException catch (e) {
      print('❌ Error getting saved reels: ${e.message}');
      return [];
    } catch (e) {
      print('❌ Unexpected error getting saved reels: $e');
      return [];
    }
  }

  /// Backend reels have no like; always false.
  Future<bool> isClipLiked(String clipId) async => false;

  /// No backend for reel like; no-op.
  Future<void> likeClip(String clipId) async {}

  /// No backend for reel like; no-op.
  Future<void> unlikeClip(String clipId) async {}

  /// POST /reels — multipart: title, description?, projectId?, file (video), thumbnail (required by backend).
  /// thumbnailPath optional; if null, backend may 400.
  Future<bool> addReel({
    required String title,
    required String description,
    required String? videoPath,
    required String? projectId,
    required bool hasWhatsApp,
    String? developerId,
    String? developerName,
    String? developerLogo,
    String? thumbnailPath,
  }) async {
    if (videoPath == null || videoPath.isEmpty) return false;
    try {
      final form = <String, dynamic>{
        'title': title,
        'description': description,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
        'file': await MultipartFile.fromFile(videoPath),
      };
      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        form['thumbnail'] = await MultipartFile.fromFile(thumbnailPath);
      }
      final res =
          await _dioClient.dio.post('/reels', data: FormData.fromMap(form));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// GET /projects/developer?developer=ID — Get projects by developer ID
  /// OR GET /developer/me/projects — Get projects for authenticated developer (if developerId is empty)
  Future<List<ProjectModel>> getDeveloperProjects(String developerId) async {
    try {
      print('═══════════════════════════════════════════════════════════');
      print('📡 GET DEVELOPER PROJECTS - START');
      print('═══════════════════════════════════════════════════════════');
      print('🔍 DeveloperId: "$developerId"');

      Response response;

      if (developerId.isNotEmpty && developerId.trim().isNotEmpty) {
        // Use /projects/developer?developer=ID to get projects for specific developer
        print('📡 Calling: GET /projects/developer?developer=$developerId');
        response = await _dioClient.dio.get(
          '/projects/developer',
          queryParameters: {'developer': developerId.trim()},
        );
      } else {
        // Use /developer/me/projects to get projects for authenticated developer
        print(
            '📡 Calling: GET /developer/me/projects (authenticated developer)');
        response = await _dioClient.dio.get('/developer/me/projects');
      }

      print('✅ Response Status: ${response.statusCode}');
      print('📦 Response Data Type: ${response.data.runtimeType}');
      print('');

      // Print full response with JSON formatting
      print('📋 FULL RESPONSE DATA:');
      print('───────────────────────────────────────────────────────────');
      try {
        // Try to format as JSON if it's a Map or List
        if (response.data is Map || response.data is List) {
          final encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(response.data));
        } else {
          print(response.data.toString());
        }
      } catch (e) {
        print(response.data.toString());
      }
      print('───────────────────────────────────────────────────────────');
      print('');

      // Handle response format:
      // - /projects/developer returns array directly: [...]
      // - /developer/me/projects returns: { message, projects: [...], developer: {...} }
      List<dynamic> projectsList = [];

      if (response.data is List) {
        // /projects/developer returns array directly
        projectsList = response.data as List;
        print('📋 Response is directly a List (from /projects/developer)');
      } else if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('projects')) {
          projectsList =
              data['projects'] is List ? data['projects'] as List : <dynamic>[];
          print(
              '📋 Found "projects" key in response (from /developer/me/projects)');
        } else if (data.containsKey('data')) {
          final dataValue = data['data'];
          if (dataValue is List) {
            projectsList = dataValue;
            print('📋 Found "data" key in response');
          }
        } else {
          // If response is a Map but no 'projects' key, check if it's a list of projects
          print(
              '⚠️ Response is Map but no "projects" key found. Keys: ${data.keys.toList()}');
        }
      }

      print('📊 Parsed Projects List Length: ${projectsList.length}');
      print('');

      if (projectsList.isNotEmpty) {
        print('📋 First Project Structure:');
        print('   Type: ${projectsList[0].runtimeType}');
        if (projectsList[0] is Map) {
          final firstProject = projectsList[0] as Map<String, dynamic>;
          print('   Keys: ${firstProject.keys.toList()}');
          if (firstProject.containsKey('developer')) {
            print('   Developer field: ${firstProject['developer']}');
            print(
                '   Developer type: ${firstProject['developer'].runtimeType}');
          }
          if (firstProject.containsKey('_id')) {
            print('   _id: ${firstProject['_id']}');
          }
          if (firstProject.containsKey('title')) {
            print('   title: ${firstProject['title']}');
          }
        }
        print('');
      }

      // Parse projects
      final projects = <ProjectModel>[];
      for (var i = 0; i < projectsList.length; i++) {
        try {
          final projectData = projectsList[i] as Map<String, dynamic>;
          final project = ProjectModel.fromJson(projectData);
          projects.add(project);
          print(
              '✅ [$i] Parsed: ${project.title} (ID: ${project.id}, DevID: ${project.developerId})');
        } catch (parseError, stackTrace) {
          print('⚠️ Error parsing project at index $i: $parseError');
          print('   Data: ${projectsList[i]}');
          print('   Stack: $stackTrace');
        }
      }

      print('');
      print('✅ Total Parsed Projects: ${projects.length}');
      print('');

      // Print all project titles
      if (projects.isNotEmpty) {
        print('📋 All Projects:');
        for (var i = 0; i < projects.length; i++) {
          final project = projects[i];
          print('   [$i] ${project.title} (DevID: "${project.developerId}")');
        }
        print('');
      }

      print('═══════════════════════════════════════════════════════════');
      print('📡 GET DEVELOPER PROJECTS - END');
      print('═══════════════════════════════════════════════════════════');
      print('');

      return projects;
    } on DioException catch (e) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ ERROR GETTING DEVELOPER PROJECTS');
      print('═══════════════════════════════════════════════════════════');
      print('Error: ${e.message}');
      print('Type: ${e.type}');
      if (e.response != null) {
        print('Status: ${e.response?.statusCode}');
        print('Response Data:');
        print(e.response?.data);

        // Handle specific error cases
        if (e.response?.statusCode == 401) {
          print(
              '⚠️ 401 Unauthorized - User may not be authenticated or not a developer');
        } else if (e.response?.statusCode == 403) {
          print('⚠️ 403 Forbidden - User may not have developer permissions');
        } else if (e.response?.statusCode == 404) {
          print(
              '⚠️ 404 Not Found - Endpoint may not exist or user has no projects');
        }
      }
      print('═══════════════════════════════════════════════════════════');
      print('');
      return [];
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ UNEXPECTED ERROR GETTING DEVELOPER PROJECTS');
      print('═══════════════════════════════════════════════════════════');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      print('');
      return [];
    }
  }

  /// GET /projects/trending?limit= (backend doesn't have general /projects endpoint)
  Future<List<ProjectModel>> getProjects(
      {int limit = 20, String? excludeId}) async {
    try {
      // Backend doesn't have /projects with query params, use trending instead
      final response = await _dioClient.dio.get('/projects/trending',
          queryParameters: {'limit': limit.toString()});
      final list = response.data is List ? response.data as List : <dynamic>[];
      var items = list
          .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (excludeId != null)
        items = items.where((p) => p.id != excludeId).toList();
      return items;
    } on DioException catch (e) {
      print('❌ Error getting projects: ${e.message}');
      return [];
    }
  }

  /// GET /projects/location?location= — for "projects by area"
  Future<List<ProjectModel>> getProjectsByArea(String location) async {
    try {
      // Use correct endpoint: GET /projects/location?location=
      final response = await _dioClient.dio
          .get('/projects/location', queryParameters: {'location': location});
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list
          .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      print('❌ Error getting projects by area ($location): ${e.message}');
      return [];
    }
  }

  /// No direct “set inventory URL” in backend; /files/upload/inventory requires a file. No-op.
  Future<bool> updateInventory(String projectId, String inventoryUrl) async =>
      false;

  /// POST /files/upload/inventory — multipart: projectId, title, inventory (file). Backend requires title. Requires ADMIN.
  Future<bool> uploadInventoryFile(String projectId, String filePath,
      {String? title}) async {
    try {
      final form = FormData.fromMap({
        'projectId': projectId,
        'title': title?.trim().isNotEmpty == true ? title!.trim() : 'Inventory',
        'inventory': await MultipartFile.fromFile(filePath),
      });
      final res =
          await _dioClient.dio.post('/files/upload/inventory', data: form);
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// GET /files/get/inventory (auth) — returns { message, inventories }. Filter by projectId.
  /// Inventory has project (not projectId) and inventoryUrl (not fileUrl).
  Future<String?> getInventoryUrl(String projectId) async {
    try {
      // New route (docs): GET /files/inventory -> List
      Response response;
      try {
        response = await _dioClient.dio.get('/files/inventory');
      } on DioException catch (e) {
        // Backwards-compatible fallback
        if (e.response?.statusCode == 404) {
          response = await _dioClient.dio.get('/files/get/inventory');
        } else {
          rethrow;
        }
      }

      final dynamic raw = response.data;
      final List<dynamic> list = raw is List
          ? raw
          : (raw is Map<String, dynamic>
              ? ((raw['inventories'] as List?) ?? <dynamic>[])
              : <dynamic>[]);

      for (final e in list) {
        final m = e as Map<String, dynamic>?;
        if (m == null) continue;
        final pid = _resolveId(m['project']) ?? _resolveId(m['projectId']);
        if (pid == projectId) {
          final url = m['inventoryUrl']?.toString() ?? m['fileUrl']?.toString();
          if (url != null && url.isNotEmpty) return url;
        }
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  /// GET /files/get/pdf (auth) — returns { message, pdfs }. Filter by projectId.
  /// File has project (not projectId) and pdfUrl (not fileUrl).
  Future<List<PdfFileModel>> getPdfFiles(String projectId) async {
    try {
      // New route (docs): GET /files/pdf -> List
      Response response;
      try {
        response = await _dioClient.dio.get('/files/pdf');
      } on DioException catch (e) {
        // Backwards-compatible fallback
        if (e.response?.statusCode == 404) {
          response = await _dioClient.dio.get('/files/get/pdf');
        } else {
          rethrow;
        }
      }

      final dynamic raw = response.data;
      final List<dynamic> list =
          raw is List ? raw : ((raw as Map?)?['pdfs'] as List? ?? <dynamic>[]);
      return list
          .map((e) => e as Map<String, dynamic>)
          .where((m) =>
              (_resolveId(m['project']) ?? _resolveId(m['projectId'])) ==
              projectId)
          .map(PdfFileModel.fromJson)
          .toList();
    } on DioException catch (_) {
      return [];
    }
  }

  /// PATCH /files/update/inventory/:id — Update an inventory file
  Future<bool> updateInventoryFile(String inventoryId,
      {String? title, String? filePath}) async {
    try {
      final form = <String, dynamic>{};
      if (title != null && title.isNotEmpty) {
        form['title'] = title;
      }
      if (filePath != null && filePath.isNotEmpty) {
        form['inventory'] = await MultipartFile.fromFile(filePath);
      }
      Response res;
      try {
        res = await _dioClient.dio.patch('/files/inventory/$inventoryId',
            data: FormData.fromMap(form));
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          res = await _dioClient.dio.patch(
              '/files/update/inventory/$inventoryId',
              data: FormData.fromMap(form));
        } else {
          rethrow;
        }
      }
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// PATCH /files/update/pdf/:id — Update a PDF file
  Future<bool> updatePdfFile(String pdfId,
      {String? title, String? filePath}) async {
    try {
      final form = <String, dynamic>{};
      if (title != null && title.isNotEmpty) {
        form['title'] = title;
      }
      if (filePath != null && filePath.isNotEmpty) {
        form['PDF'] = await MultipartFile.fromFile(filePath);
      }
      Response res;
      try {
        res = await _dioClient.dio
            .patch('/files/pdf/$pdfId', data: FormData.fromMap(form));
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          res = await _dioClient.dio
              .patch('/files/update/pdf/$pdfId', data: FormData.fromMap(form));
        } else {
          rethrow;
        }
      }
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /files/delete/inventory/:id — Delete an inventory file
  Future<bool> deleteInventoryFile(String inventoryId) async {
    try {
      Response res;
      try {
        res = await _dioClient.dio.delete('/files/inventory/$inventoryId');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          res = await _dioClient.dio
              .delete('/files/delete/inventory/$inventoryId');
        } else {
          rethrow;
        }
      }
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /files/delete/pdf/:id — Delete a PDF file
  Future<bool> deletePdfFile(String pdfId) async {
    try {
      Response res;
      try {
        res = await _dioClient.dio.delete('/files/pdf/$pdfId');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          res = await _dioClient.dio.delete('/files/delete/pdf/$pdfId');
        } else {
          rethrow;
        }
      }
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// PATCH /projects/:id — Update project script
  /// Request: { "script": string }
  Future<bool> updateProjectScript(String projectId, String script) async {
    try {
      final response = await _dioClient.dio.patch(
        '/projects/$projectId',
        data: {'script': script},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      print('⚠️ Error updating project script: ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}');
        print('   Data: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print('⚠️ Unexpected error updating project script: $e');
      return false;
    }
  }
}
