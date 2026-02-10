import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// ReelsVideoManager - قلب TikTok ❤️
/// Core video management: create, play, pause, preload, dispose
class ReelsVideoManager {
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _failedIndices = {}; // Track failed videos (4K, etc.)
  final Set<int> _initializing =
      {}; // Track videos being initialized to prevent duplicates

  /// Get controller at index (if exists)
  VideoPlayerController? controllerAt(int index) => _controllers[index];

  /// Check if video failed to load
  bool isFailed(int index) => _failedIndices.contains(index);

  /// Wait for video to be ready (buffer / first frame) before playing.
  /// Prevents audio-only playback when video decoder hasn't rendered yet.
  Future<void> _waitForVideoReady(VideoPlayerController controller) async {
    const maxWait = Duration(milliseconds: 500);
    const pollInterval = Duration(milliseconds: 50);
    var elapsed = Duration.zero;

    while (elapsed < maxWait) {
      if (controller.value.buffered.isNotEmpty) {
        return;
      }
      await Future.delayed(pollInterval);
      elapsed += pollInterval;
    }
    // Give decoder time to prepare first frame (avoids audio-before-video)
    await Future.delayed(const Duration(milliseconds: 350));
  }

  /// Play video at index
  /// Creates controller if not exists, initializes and plays
  Future<void> play(int index, String url) async {
    if (url.isEmpty) return;
    if (_failedIndices.contains(index)) return;

    // Prevent concurrent initialization
    if (_initializing.contains(index)) {
      debugPrint(
          '⏸️ ReelsVideoManager: Already initializing video at $index, skipping');
      return;
    }

    // If controller exists and initialized, just play
    if (_controllers.containsKey(index)) {
      final controller = _controllers[index]!;
      if (controller.value.isInitialized) {
        try {
          await controller.play();
        } catch (e) {
          debugPrint(
              '⚠️ ReelsVideoManager: Error playing existing controller: $e');
        }
        return;
      } else {
        // Dispose uninitialized controller before creating new one
        try {
          controller.dispose();
        } catch (e) {
          debugPrint(
              '⚠️ ReelsVideoManager: Error disposing uninitialized controller: $e');
        }
        _controllers.remove(index);
      }
    }

    // Create and initialize new controller
    _initializing.add(index);
    try {
      debugPrint('🎬 ReelsVideoManager: Playing video at index $index');
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
        ),
      );

      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          try {
            controller.dispose();
          } catch (e) {
            debugPrint('⚠️ ReelsVideoManager: Error disposing on timeout: $e');
          }
          throw TimeoutException('Video initialization timeout');
        },
      );

      controller.setLooping(true);
      await _waitForVideoReady(controller);
      await controller.play();

      _controllers[index] = controller;
    } catch (e) {
      debugPrint('❌ ReelsVideoManager: Error playing video at $index: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('3840') ||
          errorStr.contains('4k') ||
          errorStr.contains('mediacodec') ||
          errorStr.contains('decoder')) {
        _failedIndices.add(index);
      }
      // Don't rethrow - allow graceful degradation
    } finally {
      _initializing.remove(index);
    }
  }

  /// Preload video at index (initialize but don't play)
  Future<void> preload(int index, String url) async {
    if (url.isEmpty) return;
    if (_failedIndices.contains(index)) return;

    // Prevent concurrent initialization
    if (_initializing.contains(index)) {
      return;
    }

    if (_controllers.containsKey(index)) {
      // If exists but not initialized, dispose and recreate
      final existing = _controllers[index]!;
      if (!existing.value.isInitialized) {
        try {
          existing.dispose();
        } catch (e) {
          debugPrint(
              '⚠️ ReelsVideoManager: Error disposing uninitialized in preload: $e');
        }
        _controllers.remove(index);
      } else {
        return; // Already exists and initialized
      }
    }

    // Limit concurrent preloads to prevent resource exhaustion
    if (_controllers.length >= 5) {
      debugPrint(
          '⚠️ ReelsVideoManager: Too many controllers, skipping preload at $index');
      return;
    }

    _initializing.add(index);
    try {
      debugPrint('⏳ ReelsVideoManager: Preloading video at index $index');
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
        ),
      );

      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          try {
            controller.dispose();
          } catch (e) {
            debugPrint(
                '⚠️ ReelsVideoManager: Error disposing on preload timeout: $e');
          }
          throw TimeoutException('Video preload timeout');
        },
      );

      controller.setLooping(true);
      // Don't play, just initialize

      _controllers[index] = controller;
    } catch (e) {
      debugPrint('❌ ReelsVideoManager: Error preloading video at $index: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('3840') ||
          errorStr.contains('4k') ||
          errorStr.contains('mediacodec') ||
          errorStr.contains('decoder')) {
        _failedIndices.add(index);
      }
      // Don't rethrow for preload - it's optional
    } finally {
      _initializing.remove(index);
    }
  }

  /// Pause all playing videos
  void pauseAll() {
    for (final controller in _controllers.values) {
      try {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          controller.pause();
        }
      } catch (e) {
        debugPrint('⚠️ ReelsVideoManager: Error pausing video: $e');
      }
    }
  }

  /// Pause video at specific index
  void pause(int index) {
    final controller = _controllers[index];
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying) {
      controller.pause();
    }
  }

  /// Dispose controllers that are far from current index
  /// Keeps only: current, next, previous (max 3 controllers)
  void disposeFar(int current) {
    final keys = _controllers.keys.toList();
    for (final i in keys) {
      if ((i - current).abs() > 1) {
        try {
          final controller = _controllers[i];
          if (controller != null) {
            // Pause before disposing
            if (controller.value.isInitialized && controller.value.isPlaying) {
              controller.pause();
            }
            controller.dispose();
            _controllers.remove(i);
            debugPrint(
                '🗑️ ReelsVideoManager: Disposed controller at index $i');
          }
        } catch (e) {
          debugPrint(
              '⚠️ ReelsVideoManager: Error disposing controller at $i: $e');
          // Remove from map even if dispose failed
          _controllers.remove(i);
        }
      }
    }
  }

  /// Dispose all controllers
  void disposeAll() {
    for (final entry in _controllers.entries) {
      try {
        final controller = entry.value;
        if (controller.value.isInitialized && controller.value.isPlaying) {
          controller.pause();
        }
        controller.dispose();
      } catch (e) {
        debugPrint(
            '⚠️ ReelsVideoManager: Error disposing controller at ${entry.key}: $e');
      }
    }
    _controllers.clear();
    _failedIndices.clear();
    _initializing.clear();
  }

  /// Get count of active controllers (for debugging)
  int get activeControllersCount => _controllers.length;
}
