import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/clip_model.dart';
import 'reels_video_manager.dart';

/// ReelsItem - عرض فقط ❌ مفيش initialize ❌ مفيش logic
/// Display-only widget, no initialization or logic
class ReelsItem extends StatelessWidget {
  final int index;
  final ClipModel clip;
  final ReelsVideoManager videoManager;
  final VoidCallback? onTap;

  const ReelsItem({
    super.key,
    required this.index,
    required this.clip,
    required this.videoManager,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = videoManager.controllerAt(index);
    final isFailed = videoManager.isFailed(index);

    // Show loading state if controller not ready
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoadingState(clip, isFailed);
    }

    // Show video player at original dimensions
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          // Play indicator - hide when playing (ListenableBuilder ensures rebuild on play/pause)
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.value.isPlaying) return const SizedBox.shrink();
              return Center(
                child: Image.asset(
                  'assets/icons_clips/play.png',
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) {
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ClipModel clip, bool isFailed) {
    if (isFailed) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Video unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: const CircularProgressIndicator(
            color: Color(0xFFE50914),
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }
}
