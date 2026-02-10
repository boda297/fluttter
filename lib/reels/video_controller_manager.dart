import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Centralized video controller manager for TikTok-style reels.
/// - Max 3 controllers alive (current + adjacent)
/// - Single audio active at a time
/// - Preload next/previous
/// - Proper disposal
class VideoControllerManager {
  static const int _maxControllers = 3;
  static const Duration _initTimeout = Duration(seconds: 15);

  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _failedIndices = {};
  final Set<int> _initializing = {};

  VideoPlayerController? controllerAt(int index) => _controllers[index];
  bool isFailed(int index) => _failedIndices.contains(index);

  bool _isVisible = true;

  void setVisible(bool visible) {
    _isVisible = visible;
    if (!visible) {
      pauseAll();
    }
  }

  Future<void> _waitForFirstFrame(VideoPlayerController c) async {
    const maxWait = Duration(milliseconds: 600);
    const poll = Duration(milliseconds: 50);
    var elapsed = Duration.zero;
    while (elapsed < maxWait) {
      if (c.value.buffered.isNotEmpty) break;
      await Future.delayed(poll);
      elapsed += poll;
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> play(int index, String url, {bool isAsset = false}) async {
    if (url.isEmpty) return;
    if (_failedIndices.contains(index)) return;
    if (_initializing.contains(index)) return;

    final existing = _controllers[index];
    if (existing != null && existing.value.isInitialized) {
      if (!_isVisible) return;
      try {
        pauseAllExcept(index);
        await existing.play();
      } catch (e) {
        debugPrint('VideoControllerManager: play error $e');
      }
      return;
    }

    if (existing != null) {
      _disposeController(index, existing);
      _controllers.remove(index);
    }

    _initializing.add(index);
    try {
      final VideoPlayerController controller = isAsset
          ? VideoPlayerController.asset(url)
          : VideoPlayerController.networkUrl(
              Uri.parse(url),
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            );

      await controller.initialize().timeout(
        _initTimeout,
        onTimeout: () {
          try {
            controller.dispose();
          } catch (_) {}
          throw TimeoutException('Video init timeout');
        },
      );

      controller.setLooping(true);
      controller.setVolume(1.0);
      await _waitForFirstFrame(controller);

      _controllers[index] = controller;
      if (_isVisible) {
        pauseAllExcept(index);
        await controller.play();
      }
    } catch (e) {
      debugPrint('VideoControllerManager: init failed index=$index $e');
      _failedIndices.add(index);
    } finally {
      _initializing.remove(index);
    }
  }

  Future<void> preload(int index, String url, {bool isAsset = false}) async {
    if (url.isEmpty) return;
    if (_failedIndices.contains(index)) return;
    if (_initializing.contains(index)) return;
    if (_controllers.containsKey(index)) return;
    if (_controllers.length >= _maxControllers) return;

    _initializing.add(index);
    try {
      final VideoPlayerController controller = isAsset
          ? VideoPlayerController.asset(url)
          : VideoPlayerController.networkUrl(
              Uri.parse(url),
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            );

      await controller.initialize().timeout(
        _initTimeout,
        onTimeout: () {
          try {
            controller.dispose();
          } catch (_) {}
          throw TimeoutException('Preload timeout');
        },
      );

      controller.setLooping(true);
      controller.setVolume(0.0);
      _controllers[index] = controller;
    } catch (e) {
      debugPrint('VideoControllerManager: preload failed index=$index $e');
      _failedIndices.add(index);
    } finally {
      _initializing.remove(index);
    }
  }

  void pauseAllExcept(int keepIndex) {
    for (final entry in _controllers.entries) {
      if (entry.key == keepIndex) continue;
      try {
        final c = entry.value;
        if (c.value.isInitialized && c.value.isPlaying) {
          c.pause();
        }
      } catch (_) {}
    }
  }

  void pauseAll() {
    for (final c in _controllers.values) {
      try {
        if (c.value.isInitialized && c.value.isPlaying) {
          c.pause();
        }
      } catch (_) {}
    }
  }

  void pause(int index) {
    final c = _controllers[index];
    if (c != null && c.value.isInitialized && c.value.isPlaying) {
      c.pause();
    }
  }

  void disposeFar(int currentIndex, int totalCount) {
    final toRemove = <int>[];
    for (final i in _controllers.keys) {
      if ((i - currentIndex).abs() > 1) {
        toRemove.add(i);
      }
    }
    for (final i in toRemove) {
      final c = _controllers[i];
      if (c != null) {
        _disposeController(i, c);
      }
      _controllers.remove(i);
    }
  }

  void _disposeController(int index, VideoPlayerController c) {
    try {
      if (c.value.isInitialized && c.value.isPlaying) c.pause();
      c.dispose();
    } catch (e) {
      debugPrint('VideoControllerManager: dispose error $e');
    }
  }

  void disposeAll() {
    for (final entry in _controllers.entries) {
      _disposeController(entry.key, entry.value);
    }
    _controllers.clear();
    _failedIndices.clear();
    _initializing.clear();
  }

  void setMuted(int index, bool muted) {
    final c = _controllers[index];
    if (c != null && c.value.isInitialized) {
      c.setVolume(muted ? 0.0 : 1.0);
    }
  }
}
