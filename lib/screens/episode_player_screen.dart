import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:async';
import '../models/episode_model.dart';
import '../services/api/project_api.dart';

class EpisodePlayerScreen extends StatefulWidget {
  final EpisodeModel episode;
  final String projectTitle;

  const EpisodePlayerScreen({
    super.key,
    required this.episode,
    this.projectTitle = '',
  });

  @override
  State<EpisodePlayerScreen> createState() => _EpisodePlayerScreenState();
}

class _EpisodePlayerScreenState extends State<EpisodePlayerScreen> with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;
  final ProjectApi _projectApi = ProjectApi();
  Timer? _progressTimer;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set landscape orientation for video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _initializeVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive) {
      _videoController?.pause();
      _saveCurrentProgress();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _projectId = widget.episode.projectId;
      print('🎬 Initializing video for project: $_projectId, episode: ${widget.episode.id}');
      if (_projectId == null || _projectId!.isEmpty) {
        print('❌ ERROR: projectId is null or empty!');
        return;
      }
      
      // For demo, use a sample video URL
      // In production, use: widget.episode.videoUrl
      final videoUrl = widget.episode.videoUrl.isNotEmpty &&
              !widget.episode.videoUrl.contains('example.com')
          ? widget.episode.videoUrl
          : 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await _videoController!.initialize();

      // Load saved progress
      if (_projectId != null) {
        final savedProgress = await _projectApi.getWatchingProgress(
          _projectId!,
          widget.episode.id,
        );
        if (savedProgress > 0 && savedProgress < 1.0) {
          final position = Duration(
            milliseconds: (savedProgress * _videoController!.value.duration.inMilliseconds).toInt(),
          );
          await _videoController!.seekTo(position);
        }
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        showOptions: false,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFE50914),
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading video',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFE50914),
          handleColor: const Color(0xFFE50914),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Add listener to track progress changes
        _videoController!.addListener(_onVideoPositionChanged);
        // Start tracking progress
        _startProgressTracking();
        // Save initial progress immediately
        _saveCurrentProgress();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onVideoPositionChanged() {
    if (_videoController != null && 
        _projectId != null && 
        _projectId!.isNotEmpty &&
        _videoController!.value.isInitialized) {
      final duration = _videoController!.value.duration;
      final position = _videoController!.value.position;
      
      if (duration.inMilliseconds > 0) {
        final progress = position.inMilliseconds / duration.inMilliseconds;
        // Save progress every 2% change (debounce)
        if (_lastSavedProgress == null || 
            (progress - _lastSavedProgress!).abs() > 0.02) { // 2% change
          _lastSavedProgress = progress;
          print('💾 Saving progress: projectId=$_projectId, episodeId=${widget.episode.id}, progress=${(progress * 100).toStringAsFixed(1)}%');
          _projectApi.updateEpisodeWatchProgress(
            projectId: _projectId!,
            episode: widget.episode,
            projectTitle: widget.projectTitle,
            currentTimeSeconds: position.inMilliseconds / 1000.0,
            durationSeconds: duration.inMilliseconds / 1000.0,
          );
        }
      }
    } else {
      if (_projectId == null || _projectId!.isEmpty) {
        print('❌ Cannot save progress: projectId is null or empty');
      }
    }
  }

  double? _lastSavedProgress;

  void _startProgressTracking() {
    // Track progress every 2 seconds (for short videos)
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _saveCurrentProgress();
    });
  }

  Future<void> _saveCurrentProgress() async {
    if (_videoController != null && 
        _projectId != null && 
        _projectId!.isNotEmpty &&
        _videoController!.value.isInitialized) {
      final duration = _videoController!.value.duration;
      final position = _videoController!.value.position;
      
      if (duration.inMilliseconds > 0) {
        final progress = position.inMilliseconds / duration.inMilliseconds;
        print('💾 Timer: Saving progress: projectId=$_projectId, episodeId=${widget.episode.id}, progress=${(progress * 100).toStringAsFixed(1)}%');
        await _projectApi.updateEpisodeWatchProgress(
          projectId: _projectId!,
          episode: widget.episode,
          projectTitle: widget.projectTitle,
          currentTimeSeconds: position.inMilliseconds / 1000.0,
          durationSeconds: duration.inMilliseconds / 1000.0,
        );
      }
    } else {
      print('❌ Cannot save progress: projectId=${_projectId}, controller=${_videoController != null}, initialized=${_videoController?.value.isInitialized}');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    // Remove listener
    _videoController?.removeListener(_onVideoPositionChanged);
    // Save progress before disposing (force save)
    print('🔄 Disposing - saving final progress...');
    if (_projectId != null && _projectId!.isNotEmpty && _videoController != null && _videoController!.value.isInitialized) {
      final duration = _videoController!.value.duration;
      final position = _videoController!.value.position;
      if (duration.inMilliseconds > 0) {
        final progress = position.inMilliseconds / duration.inMilliseconds;
        print('💾 Force saving on dispose: projectId=$_projectId, episodeId=${widget.episode.id}, progress=${(progress * 100).toStringAsFixed(1)}%');
        // Don't await - dispose can't be async
        _projectApi.updateEpisodeWatchProgress(
          projectId: _projectId!,
          episode: widget.episode,
          projectTitle: widget.projectTitle,
          currentTimeSeconds: position.inMilliseconds / 1000.0,
          durationSeconds: duration.inMilliseconds / 1000.0,
        );
      }
    }
    _videoController?.pause();
    // Reset to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Video Player
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE50914),
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorWidget()
                      : _chewieController != null
                          ? Chewie(controller: _chewieController!)
                          : _buildErrorWidget(),
            ),
            // Episode Info
            _buildEpisodeInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white54,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load video',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true), // Return true to indicate progress was updated
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context, true), // Return true to indicate progress was updated
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.episode.title.isNotEmpty
                      ? widget.episode.title
                      : 'Episode ${widget.episode.episodeNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (widget.projectTitle.isNotEmpty) ...[
                      Text(
                        widget.projectTitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                    Text(
                      widget.episode.duration,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

