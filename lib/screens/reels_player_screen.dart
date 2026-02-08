import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get/get.dart';
import '../models/clip_model.dart';
import '../services/clip_service.dart';
import '../utils/auth_helper.dart';
import '../utils/performance_monitor.dart';
import 'project_details_screen.dart';

class ReelsPlayerScreen extends StatefulWidget {
  final List<ClipModel> clips;
  final int initialIndex;

  const ReelsPlayerScreen({
    super.key,
    required this.clips,
    this.initialIndex = 0,
  });

  @override
  State<ReelsPlayerScreen> createState() => _ReelsPlayerScreenState();
}

class _ReelsPlayerScreenState extends State<ReelsPlayerScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  ClipService? _clipService;
  final Map<int, VideoPlayerController> _controllers =
      {}; // Direct video controllers
  final Map<int, ClipModel> _clipsCache = {}; // Cache updated clips by index
  final Map<String, bool> _savedReelIds = {}; // Store saved status by reel ID
  final Set<int> _listenersAdded = {}; // Track which controllers have listeners
  final Set<int> _failedVideoIndices = {}; // Track failed videos (4K)
  int _currentIndex = 0;
  bool _isInitialized = false;

  static const Color brandRed = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    try {
      if (Get.isRegistered<ClipService>()) {
        _clipService = Get.find<ClipService>();
      }
    } catch (_) {}
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initialize();
  }

  Future<void> _initialize() async {
    // Mark as initialized immediately so UI can show placeholders
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }

    // Load initial video (non-blocking for UI)
    _initializeCurrentVideo();

    // Load liked and saved status in parallel (non-blocking)
    _loadLikedStatus();
    _loadSavedStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Pause all videos
      for (var controller in _controllers.values) {
        try {
          if (controller.value.isInitialized && controller.value.isPlaying) {
            controller.pause();
          }
        } catch (e) {
          debugPrint('⚠️ Error pausing video: $e');
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      // Resume current video
      final controller = _controllers[_currentIndex];
      if (controller != null &&
          controller.value.isInitialized &&
          !controller.value.isPlaying) {
        controller.play();
      }
    }
  }

  Future<void> _loadLikedStatus() async {
    if (_clipService == null) return;
    PerformanceMonitor.start('Load liked status');
    // Batch all updates and call setState once (eliminates N rebuilds)
    final Map<int, ClipModel> updates = {};
    for (int i = 0; i < widget.clips.length; i++) {
      final clip = widget.clips[i];
      final isLiked = await _clipService!.isClipLiked(clip.id);
      updates[i] = clip.copyWith(isLiked: isLiked);
    }
    if (mounted) {
      setState(() {
        _clipsCache.addAll(updates);
      });
    }
    PerformanceMonitor.end('Load liked status');
  }

  Future<void> _loadSavedStatus() async {
    if (!mounted || _clipService == null) return;
    try {
      // Load all saved reels once instead of checking each one individually
      final savedReels = await _clipService!.getSavedReels();
      if (mounted) {
        setState(() {
          _savedReelIds.clear();
          for (final reel in savedReels) {
            _savedReelIds[reel.id] = true;
          }
        });
      }
    } catch (e) {
      print('❌ Error loading saved reels status: $e');
    }
  }

  Future<void> _initializeCurrentVideo() async {
    if (_currentIndex < 0 || _currentIndex >= widget.clips.length) return;
    if (_failedVideoIndices.contains(_currentIndex)) return;

    if (_controllers.containsKey(_currentIndex)) {
      final controller = _controllers[_currentIndex]!;
      if (controller.value.isInitialized) {
        if (!_listenersAdded.contains(_currentIndex)) {
          controller.addListener(_onVideoStateChanged);
          _listenersAdded.add(_currentIndex);
        }
        controller.play();
        if (mounted) setState(() {});
        return;
      }
    }

    await _initializeVideoAt(_currentIndex);
  }

  Future<void> _initializeVideoAt(int index) async {
    if (index < 0 || index >= widget.clips.length) return;
    if (_failedVideoIndices.contains(index)) return;
    if (_controllers.containsKey(index)) {
      final controller = _controllers[index]!;
      if (controller.value.isInitialized) return;
    }

    final clip = widget.clips[index];
    final videoUrl = clip.videoUrl;
    if (videoUrl.isEmpty) return;

    try {
      debugPrint('🔄 ReelsPlayerScreen: Initializing video at index $index');
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          controller.dispose();
          throw TimeoutException('Video initialization timeout');
        },
      );

      controller.setLooping(true);
      if (index == _currentIndex) {
        controller.play();
      }

      if (!_listenersAdded.contains(index)) {
        controller.addListener(_onVideoStateChanged);
        _listenersAdded.add(index);
      }

      if (mounted) {
        setState(() {
          _controllers[index] = controller;
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing video at $index: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('3840') ||
          errorStr.contains('4k') ||
          errorStr.contains('mediacodec') ||
          errorStr.contains('decoder')) {
        _failedVideoIndices.add(index);
      }
      if (mounted) setState(() {});
    }
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;

    // Pause previous video
    final prevController = _controllers[_currentIndex];
    if (prevController != null &&
        prevController.value.isInitialized &&
        prevController.value.isPlaying) {
      prevController.pause();
    }

    setState(() {
      _currentIndex = index;
    });

    // Initialize video for new index
    _initializeVideoAt(index);
  }

  void _onVideoStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clipService?.flush(); // Persist liked clips before leaving
    // Remove all listeners and dispose controllers
    try {
      for (var entry in _controllers.entries) {
        try {
          if (_listenersAdded.contains(entry.key)) {
            entry.value.removeListener(_onVideoStateChanged);
          }
          entry.value.dispose();
        } catch (e) {
          debugPrint('⚠️ Error disposing controller at ${entry.key}: $e');
        }
      }
      _controllers.clear();
      _listenersAdded.clear();
    } catch (e) {
      debugPrint('⚠️ Error in dispose: $e');
    }

    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= widget.clips.length) return;
    if (!mounted || _clipService == null) return;

    final clip = _clipsCache[index] ?? widget.clips[index];
    final isCurrentlyLiked = clip.isLiked;

    try {
      // Optimistic update - API handles the UI update immediately
      final updatedClip = isCurrentlyLiked
          ? await _clipService!.unlikeClip(clip.id)
          : await _clipService!.likeClip(clip.id);

      if (mounted) {
        setState(() {
          _clipsCache[index] = updatedClip;
        });

        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedClip.isLiked ? '❤️ Liked!' : 'Unliked'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      // Rollback already happened automatically in API
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Unable to update like status'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Get clip for index (uses cache if available)
  ClipModel _getClipForIndex(int index) {
    if (index < 0 || index >= widget.clips.length) {
      return widget.clips[0]; // Fallback
    }
    return _clipsCache[index] ?? widget.clips[index];
  }

  Future<void> _toggleSave(int index) async {
    if (!mounted || _clipService == null) return;
    if (index < 0 || index >= widget.clips.length) return;

    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth || !mounted) return;

    final clip = widget.clips[index];
    final isCurrentlySaved = _savedReelIds[clip.id] ?? false;

    // Optimistic update
    if (mounted) {
      setState(() {
        _savedReelIds[clip.id] = !isCurrentlySaved;
      });
    }

    try {
      if (!isCurrentlySaved) {
        final success = await _clipService!.saveReel(clip.id);
        if (success) {
          if (mounted) _showSnackBar('Saved!', isSuccess: true);
        } else {
          // Revert on failure
          if (mounted) {
            setState(() {
              _savedReelIds[clip.id] = isCurrentlySaved;
            });
            _showSnackBar('Error saving reel', isSuccess: false);
          }
        }
      } else {
        final success = await _clipService!.unsaveReel(clip.id);
        if (success) {
          if (mounted) _showSnackBar('Removed from saved', isSuccess: true);
        } else {
          // Revert on failure
          if (mounted) {
            setState(() {
              _savedReelIds[clip.id] = isCurrentlySaved;
            });
            _showSnackBar('Error removing reel', isSuccess: false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _toggleSave: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _savedReelIds[clip.id] = isCurrentlySaved;
        });
        _showSnackBar('Error saving/removing reel', isSuccess: false);
      }
    }
  }

  Future<void> _openWhatsApp(ClipModel clip) async {
    const phone = '201205403733'; // Default number
    final message = 'مهتم بمشروع ${clip.developerName}';
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open WhatsApp');
    }
  }

  Future<void> _shareClip(ClipModel clip) async {
    final shareText = '''
🎬 ${clip.title}
🏗️ ${clip.developerName}

${clip.description}

شاهد المزيد على تطبيق Orientation!
''';

    try {
      await Share.share(shareText, subject: clip.title);
    } catch (e) {
      _showSnackBar('Error sharing');
    }
  }

  void _openProjectDetails(ClipModel clip) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    // Pause all videos
    for (var controller in _controllers.values) {
      try {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          controller.pause();
        }
      } catch (e) {
        debugPrint('⚠️ Error pausing video: $e');
      }
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsScreen(projectId: clip.projectId),
      ),
    );
  }

  void _openEpisodes(ClipModel clip) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    // Pause all videos
    for (var controller in _controllers.values) {
      try {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          controller.pause();
        }
      } catch (e) {
        debugPrint('⚠️ Error pausing video: $e');
      }
    }
    // Navigate to Project Details on Episodes tab
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsScreen(
          projectId: clip.projectId,
          initialTabIndex: 1, // Episodes tab
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: isSuccess ? Colors.green : brandRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video PageView
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.clips.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return _buildReelItem(index);
            },
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () {
                // Pause all videos
                for (var controller in _controllers.values) {
                  try {
                    if (controller.value.isInitialized &&
                        controller.value.isPlaying) {
                      controller.pause();
                    }
                  } catch (e) {
                    debugPrint('⚠️ Error pausing video: $e');
                  }
                }
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelItem(int index) {
    // Safety check
    if (index < 0 || index >= widget.clips.length) {
      return const SizedBox.shrink();
    }

    final clip = _getClipForIndex(index);
    final controller = _controllers[index];
    final isLiked = clip.isLiked;
    final isSaved = _savedReelIds[clip.id] ?? false;
    final videoFailed = _failedVideoIndices.contains(index);

    // Initialize video if not already loaded
    if (controller == null &&
        _isInitialized &&
        !videoFailed &&
        (index == _currentIndex ||
            index == _currentIndex + 1 ||
            index == _currentIndex - 1)) {
      _initializeVideoAt(index);
    } else if (controller != null &&
        !controller.value.isInitialized &&
        !_listenersAdded.contains(index)) {
      controller.addListener(_onVideoStateChanged);
      _listenersAdded.add(index);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video or Placeholder
        GestureDetector(
          onTap: () async {
            if (controller != null && controller.value.isInitialized) {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
              setState(() {});
            } else if (!_failedVideoIndices.contains(index)) {
              // Initialize if not ready
              await _initializeVideoAt(index);
            }
          },
          child: (controller != null && controller.value.isInitialized)
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                )
              : _buildLoadingState(clip, index),
        ),
        // Play/Pause indicator
        if (controller != null &&
            controller.value.isInitialized &&
            !controller.value.isPlaying)
          Center(
            child: Image.asset(
              'assets/icons_clips/play.png',
              width: 80,
              height: 80,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to icon if image not found
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                );
              },
            ),
          ),
        // Gradient overlay at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.95),
                ],
              ),
            ),
          ),
        ),
        // Action buttons (right side) - positioned higher
        Positioned(
          right: 16,
          bottom: 200,
          child: Column(
            children: [
              if (clip.hasWhatsApp) ...[
                _ActionButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  onTap: () => _openWhatsApp(clip),
                  useImage: true,
                  imagePath: 'assets/icons_clips/whatsapp.png',
                ),
                const SizedBox(height: 18),
              ],
              _ActionButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: '${clip.likes}',
                onTap: () => _toggleLike(index),
                iconColor: isLiked ? brandRed : Colors.white,
                useImage: !isLiked,
                imagePath: 'assets/icons_clips/like.png',
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: isSaved ? 'Saved' : 'Save',
                onTap: () => _toggleSave(index),
                iconColor: isSaved ? brandRed : Colors.white,
                useImage: !isSaved,
                imagePath: 'assets/icons_clips/save.png',
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: Icons.share,
                label: 'Share',
                onTap: () => _shareClip(clip),
                useImage: true,
                imagePath: 'assets/icons_clips/share.png',
              ),
            ],
          ),
        ),
        // Bottom content
        Positioned(
          left: 16,
          right: 80,
          bottom: 30,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Developer info row
                Row(
                  children: [
                    // Avatar - tappable
                    GestureDetector(
                      onTap: () => _openProjectDetails(clip),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: clip.developerLogo.isNotEmpty
                              ? Image.asset(
                                  clip.developerLogo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.business,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                )
                              : const Icon(
                                  Icons.business,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name - tappable, flexible width
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _openProjectDetails(clip),
                        child: Text(
                          clip.developerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Watch button - opens Episodes tab
                    GestureDetector(
                      onTap: () => _openEpisodes(clip),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: brandRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Watch Orientation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Title - tappable
                GestureDetector(
                  onTap: () => _openProjectDetails(clip),
                  child: Text(
                    clip.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Description
                Text(
                  clip.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(ClipModel clip, int index) {
    // Show download indicator while video is loading
    // Show thumbnail in background if available
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail as background (dimmed)
          if (clip.thumbnail.isNotEmpty)
            Opacity(
              opacity: 0.2,
              child: clip.isAsset
                  ? Image.asset(
                      clip.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey[900]),
                    )
                  : Image.network(
                      clip.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey[900]),
                    ),
            )
          else
            Container(color: Colors.grey[900]),
          // Download indicator - prominent with download icon
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Download icon with circular progress
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer circle progress
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        color: brandRed.withOpacity(0.3),
                        strokeWidth: 4,
                        value: 1.0,
                      ),
                    ),
                    // Inner animated progress
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        color: brandRed,
                        strokeWidth: 4,
                      ),
                    ),
                    // Download icon in center
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.download,
                        color: brandRed,
                        size: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Loading video...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: CircularProgressIndicator(
          color: brandRed,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final bool useImage;
  final String imagePath;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
    this.useImage = false,
    this.imagePath = '',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          useImage && imagePath.isNotEmpty
              ? Image.asset(
                  imagePath,
                  width: 32,
                  height: 32,
                  errorBuilder: (_, __, ___) => Icon(
                    icon,
                    color: iconColor,
                    size: 32,
                  ),
                )
              : Icon(
                  icon,
                  color: iconColor,
                  size: 32,
                ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
