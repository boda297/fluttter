import '../models/clip_model.dart';
import '../models/project_model.dart';
import 'api/improved_clip_api.dart';
import 'api/project_api.dart';

/// Unified service for all clip-related operations.
/// Consolidates ImprovedClipApi and ProjectApi into a single interface.
class ClipService {
  final ImprovedClipApi _clipApi;
  final ProjectApi _projectApi;

  ClipService({
    required ImprovedClipApi clipApi,
    required ProjectApi projectApi,
  })  : _clipApi = clipApi,
        _projectApi = projectApi;

  // ============================================================
  // CLIP OPERATIONS (delegated to ImprovedClipApi)
  // ============================================================

  /// Get paginated clips.
  Future<List<ClipModel>> getClips({
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) =>
      _clipApi.getAllClips(
        page: page,
        limit: limit,
        forceRefresh: forceRefresh,
      );

  /// Get clips for a specific project.
  Future<List<ClipModel>> getProjectClips(
    String projectId, {
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) =>
      _clipApi.getClipsByProject(
        projectId,
        page: page,
        limit: limit,
        forceRefresh: forceRefresh,
      );

  /// Get a single clip by ID.
  Future<ClipModel?> getClipById(String id, {bool forceRefresh = false}) =>
      _clipApi.getClipById(id, forceRefresh: forceRefresh);

  /// Like a clip.
  Future<ClipModel> likeClip(String id) => _clipApi.likeClip(id);

  /// Unlike a clip.
  Future<ClipModel> unlikeClip(String id) => _clipApi.unlikeClip(id);

  /// Check if clip is liked.
  Future<bool> isClipLiked(String id) => _clipApi.isClipLiked(id);

  /// Flush pending saves (call on app pause/dispose).
  Future<void> flush() => _clipApi.flush();

  /// Clear clip caches.
  Future<void> clearClipCache() => _clipApi.clearCache();

  /// Get cache statistics.
  Map<String, dynamic> getCacheStats() => _clipApi.getCacheStats();

  /// Add a new reel with upload progress tracking.
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
  }) =>
      _clipApi.addReel(
        title: title,
        description: description,
        videoPath: videoPath,
        projectId: projectId,
        hasWhatsApp: hasWhatsApp,
        developerId: developerId,
        developerName: developerName,
        developerLogo: developerLogo,
        thumbnailPath: thumbnailPath,
        onUploadProgress: onUploadProgress,
      );

  // ============================================================
  // SAVED REELS (delegated to ProjectApi)
  // ============================================================

  /// Get saved reels.
  Future<List<ClipModel>> getSavedReels() => _projectApi.getSavedReels();

  /// Save a reel.
  Future<bool> saveReel(String reelId) => _projectApi.saveReel(reelId);

  /// Unsave a reel.
  Future<bool> unsaveReel(String reelId) => _projectApi.unsaveReel(reelId);

  /// Clear reels caches (ProjectApi + ImprovedClipApi).
  Future<void> clearReelsCache() async {
    await ProjectApi.clearReelsCache();
    await _clipApi.clearCache();
  }

  // ============================================================
  // PROJECT OPERATIONS (delegated to ProjectApi)
  // ============================================================

  /// Get a specific project.
  Future<ProjectModel?> getProjectById(String id) =>
      _projectApi.getProjectById(id);

  // ============================================================
  // COMBINED OPERATIONS
  // ============================================================

  /// Get project with its clips (optimized - fetches in parallel).
  Future<Map<String, dynamic>> getProjectWithClips(
    String projectId, {
    int clipsPage = 1,
    int clipsLimit = 20,
  }) async {
    final results = await Future.wait([
      _projectApi.getProjectById(projectId),
      getProjectClips(projectId, page: clipsPage, limit: clipsLimit),
    ]);
    return {
      'project': results[0],
      'clips': results[1],
    };
  }
}
