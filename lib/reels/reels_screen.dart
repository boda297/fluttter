import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/clip_model.dart';
import '../services/clip_service.dart';
import '../utils/auth_helper.dart';
import '../screens/main_screen.dart';
import '../screens/project_details_screen.dart';
import 'reels_controller.dart';
import 'reels_video_manager.dart';
import 'reels_item.dart';

/// ReelsScreen - خفيف جدًا (Lightweight)
/// Uses ReelsController and ReelsVideoManager
class ReelsScreen extends StatefulWidget {
  final List<ClipModel> clips;
  final int initialIndex;

  const ReelsScreen({
    super.key,
    required this.clips,
    this.initialIndex = 0,
  });

  @override
  State<ReelsScreen> createState() => ReelsScreenState();
}

class ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  final ReelsController _reelsController = ReelsController();
  final ReelsVideoManager _videoManager = ReelsVideoManager();
  ClipService? _clipService;

  // UI state
  final Map<int, ClipModel> _clipsCache = {}; // Cache updated clips by index
  final Map<String, bool> _savedReelIds = {}; // Store saved status by reel ID
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
    _reelsController.currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initialize();
  }

  Future<void> _initialize() async {
    // Mark as initialized immediately
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }

    // Load initial video
    _onPageChanged(widget.initialIndex);

    // Load saved status
    _loadSavedStatus();
  }

  void setVisible(bool visible) {
    if (visible) {
      final current = _reelsController.currentIndex;
      if (current >= 0 && current < widget.clips.length) {
        _videoManager.play(current, widget.clips[current].videoUrl);
      }
    } else {
      _videoManager.pauseAll();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _videoManager.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      final current = _reelsController.currentIndex;
      final controller = _videoManager.controllerAt(current);
      if (controller != null &&
          controller.value.isInitialized &&
          !controller.value.isPlaying) {
        controller.play();
      }
    }
  }

  Future<void> _loadSavedStatus() async {
    if (!mounted || _clipService == null) return;
    try {
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
      debugPrint('❌ Error loading saved reels status: $e');
    }
  }

  /// عند تغيير الصفحة (onPageChanged)
  void _onPageChanged(int index) {
    if (index < 0 || index >= widget.clips.length) return;
    if (index == _reelsController.currentIndex) return;

    // Update controller index
    _reelsController.updateIndex(index);

    final current = widget.clips[index];

    // Pause all videos
    _videoManager.pauseAll();

    // Dispose far videos first (keep only current, next, previous)
    _videoManager.disposeFar(index);

    // Play current video
    _videoManager.play(index, current.videoUrl).catchError((e) {
      debugPrint('⚠️ Error playing video at $index: $e');
    });

    // Preload next video (with delay to avoid resource exhaustion)
    if (index + 1 < widget.clips.length) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _reelsController.currentIndex == index) {
          _videoManager.preload(index + 1, widget.clips[index + 1].videoUrl);
        }
      });
    }

    // Preload previous video (with delay)
    if (index - 1 >= 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _reelsController.currentIndex == index) {
          _videoManager.preload(index - 1, widget.clips[index - 1].videoUrl);
        }
      });
    }
  }

  void _onVideoTap(int index) async {
    final controller = _videoManager.controllerAt(index);
    if (controller != null && controller.value.isInitialized) {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        await controller.play();
      }
      if (mounted) setState(() {});
    } else if (!_videoManager.isFailed(index)) {
      // Try to play if not ready
      final clip = widget.clips[index];
      await _videoManager.play(index, clip.videoUrl);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clipService?.flush();
    _videoManager.disposeAll();
    _reelsController.dispose();
    _pageController.dispose();
    super.dispose();
  }

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
          if (mounted) {
            setState(() {
              _savedReelIds[clip.id] = isCurrentlySaved;
            });
            _showSnackBar('Error removing reel', isSuccess: false);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _toggleSave: $e');
      if (mounted) {
        setState(() {
          _savedReelIds[clip.id] = isCurrentlySaved;
        });
        _showSnackBar('Error saving/removing reel', isSuccess: false);
      }
    }
  }

  Future<void> _openWhatsApp(ClipModel clip) async {
    const phone = '201205403733';
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

    _videoManager.pauseAll();
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

    _videoManager.pauseAll();
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
          // Back button - navigate to home page
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () {
                _videoManager.pauseAll();
                Get.offAll(const MainScreen());
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
    if (index < 0 || index >= widget.clips.length) {
      return const SizedBox.shrink();
    }

    final clip = _getClipForIndex(index);
    final isSaved = _savedReelIds[clip.id] ?? false;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player (ReelsItem handles display)
        ReelsItem(
          index: index,
          clip: clip,
          videoManager: _videoManager,
          onTap: () => _onVideoTap(index),
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
        // Action buttons (right side)
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
