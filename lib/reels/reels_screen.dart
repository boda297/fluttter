import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../models/clip_model.dart';
import '../services/clip_service.dart';
import '../utils/auth_helper.dart';
import '../screens/main_screen.dart';
import '../screens/project_details_screen.dart';
import 'video_controller_manager.dart';

class ReelsScreen extends StatefulWidget {
  final List<ClipModel> clips;
  final int initialIndex;
  final bool initialVisible;

  const ReelsScreen({
    super.key,
    required this.clips,
    this.initialIndex = 0,
    this.initialVisible = true,
  });

  @override
  State<ReelsScreen> createState() => ReelsScreenState();
}

class ReelsScreenState extends State<ReelsScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  late VideoControllerManager _videoManager;
  ClipService? _clipService;

  int _currentIndex = 0;
  bool _isMuted = true;
  final Map<String, bool> _savedReelIds = {};

  static const Color brandRed = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    _videoManager = VideoControllerManager();
    _videoManager.setVisible(widget.initialVisible);
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentIndex = widget.initialIndex;

    try {
      if (Get.isRegistered<ClipService>()) {
        _clipService = Get.find<ClipService>();
      }
    } catch (_) {}

    WidgetsBinding.instance.addObserver(this);
    _loadSavedStatus();
    _onPageChanged(widget.initialIndex);
  }

  void setVisible(bool visible) {
    _videoManager.setVisible(visible);
    if (visible && mounted && _currentClip != null) {
      final c = _currentClip!;
      if (c.videoUrl.isNotEmpty) {
        _videoManager.play(_currentIndex, c.videoUrl, isAsset: c.isAsset);
      }
      setState(() {});
    }
  }

  ClipModel? get _currentClip {
    if (_currentIndex < 0 || _currentIndex >= widget.clips.length) {
      return null;
    }
    return widget.clips[_currentIndex];
  }

  Future<void> _loadSavedStatus() async {
    if (!mounted || _clipService == null) return;
    try {
      final saved = await _clipService!.getSavedReels();
      if (mounted) {
        setState(() {
          _savedReelIds.clear();
          for (final r in saved) {
            _savedReelIds[r.id] = true;
          }
        });
      }
    } catch (_) {}
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= widget.clips.length) return;

    _videoManager.pauseAll();
    _videoManager.disposeFar(index, widget.clips.length);

    final clip = widget.clips[index];
    if (clip.videoUrl.isNotEmpty) {
      _videoManager.play(index, clip.videoUrl, isAsset: clip.isAsset).then((_) {
        if (mounted && _currentIndex == index) {
          _videoManager.setMuted(index, _isMuted);
        }
        if (mounted) setState(() {});
      });
    }

    if (index + 1 < widget.clips.length) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _currentIndex == index) {
          final next = widget.clips[index + 1];
          if (next.videoUrl.isNotEmpty) {
            _videoManager.preload(index + 1, next.videoUrl,
                isAsset: next.isAsset);
          }
        }
      });
    }
    if (index - 1 >= 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _currentIndex == index) {
          final prev = widget.clips[index - 1];
          if (prev.videoUrl.isNotEmpty) {
            _videoManager.preload(index - 1, prev.videoUrl,
                isAsset: prev.isAsset);
          }
        }
      });
    }

    setState(() => _currentIndex = index);
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _videoManager.setMuted(_currentIndex, _isMuted);
  }

  void _onVideoTap() async {
    final c = _videoManager.controllerAt(_currentIndex);
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _videoManager.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      final c = _videoManager.controllerAt(_currentIndex);
      if (c != null &&
          c.value.isInitialized &&
          !c.value.isPlaying &&
          _videoManager.controllerAt(_currentIndex) != null) {
        c.play();
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleSave(int index) async {
    if (!mounted || _clipService == null) return;
    if (index < 0 || index >= widget.clips.length) return;

    final ok = await AuthHelper.requireAuth(context);
    if (!ok || !mounted) return;

    final clip = widget.clips[index];
    final saved = _savedReelIds[clip.id] ?? false;

    try {
      if (saved) {
        await _clipService!.unsaveReel(clip.id);
        _savedReelIds[clip.id] = false;
      } else {
        await _clipService!.saveReel(clip.id);
        _savedReelIds[clip.id] = true;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _openProject(String? projectId) async {
    if (projectId == null || projectId.isEmpty) return;
    final ok = await AuthHelper.requireAuth(context);
    if (!ok || !mounted) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsScreen(projectId: projectId),
      ),
    );
  }

  Future<void> _openEpisodes(ClipModel clip) async {
    final ok = await AuthHelper.requireAuth(context);
    if (!ok || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsScreen(projectId: clip.projectId),
      ),
    );
  }

  Future<void> _shareClip(ClipModel clip) async {
    final ok = await AuthHelper.requireAuth(context);
    if (!ok || !mounted) return;
    try {
      await Share.share(
        clip.videoUrl,
        subject: clip.title,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clipService?.flush();
    _videoManager.disposeAll();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clips.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No reels available',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: widget.clips.length,
        itemBuilder: (context, index) {
          return _ReelPage(
            clip: widget.clips[index],
            index: index,
            videoManager: _videoManager,
            isMuted: _isMuted,
            isSaved: _savedReelIds[widget.clips[index].id] ?? false,
            onTap: _onVideoTap,
            onMuteTap: _toggleMute,
            onSaveTap: () => _toggleSave(index),
            onProjectTap: () => _openProject(widget.clips[index].projectId),
            onEpisodesTap: () => _openEpisodes(widget.clips[index]),
            onShareTap: () => _shareClip(widget.clips[index]),
            onBack: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainScreen()),
                (_) => false,
              );
            },
          );
        },
      ),
    );
  }
}

class _ReelPage extends StatelessWidget {
  final ClipModel clip;
  final int index;
  final VideoControllerManager videoManager;
  final bool isMuted;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onMuteTap;
  final VoidCallback onSaveTap;
  final VoidCallback onProjectTap;
  final VoidCallback onEpisodesTap;
  final VoidCallback onShareTap;
  final VoidCallback onBack;

  const _ReelPage({
    required this.clip,
    required this.index,
    required this.videoManager,
    required this.isMuted,
    required this.isSaved,
    required this.onTap,
    required this.onMuteTap,
    required this.onSaveTap,
    required this.onProjectTap,
    required this.onEpisodesTap,
    required this.onShareTap,
    required this.onBack,
  });

  static const Color brandRed = Color(0xFFE50914);

  @override
  Widget build(BuildContext context) {
    final controller = videoManager.controllerAt(index);
    final failed = videoManager.isFailed(index);
    final canPop = Navigator.canPop(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (failed)
          _buildErrorPlaceholder()
        else if (controller == null || !controller.value.isInitialized)
          _buildLoading()
        else
          GestureDetector(
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                ListenableBuilder(
                  listenable: controller,
                  builder: (_, __) {
                    if (controller.value.isPlaying) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        if (canPop)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: GestureDetector(
            onTap: onMuteTap,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LabeledActionButton(
                icon: Icons.chat_bubble_outline,
                label: 'WhatsApp',
                onTap: onProjectTap,
              ),
              const SizedBox(height: 16),
              _LabeledActionButton(
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: 'Save',
                onTap: onSaveTap,
              ),
              const SizedBox(height: 16),
              _LabeledActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: onShareTap,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 90,
          bottom: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.business_center_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        clip.title.isNotEmpty
                            ? clip.title
                            : (clip.developerName.isNotEmpty
                                ? clip.developerName
                                : 'Project Units'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onProjectTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: brandRed,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_circle_filled,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Watch Orientation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: brandRed,
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.white54, size: 48),
            SizedBox(height: 12),
            Text(
              'Video unavailable',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LabeledActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
