import 'package:flutter/material.dart';
import '../widgets/project_card.dart';
import '../services/api/home_api.dart';
import '../services/api/project_api.dart';
import '../models/project_model.dart';
import '../models/episode_model.dart';
import '../utils/auth_helper.dart';
import 'episode_player_screen.dart';
import 'project_details_screen.dart';
import 'package:share_plus/share_plus.dart';

class ContinueWatchingScreen extends StatefulWidget {
  const ContinueWatchingScreen({super.key});

  @override
  State<ContinueWatchingScreen> createState() => _ContinueWatchingScreenState();
}

class _ContinueWatchingScreenState extends State<ContinueWatchingScreen> {
  static const Color brandRed = Color(0xFFE50914);
  final HomeApi _homeApi = HomeApi();
  final ProjectApi _projectApi = ProjectApi();
  bool _isLoading = true;
  List<ProjectModel> _projects = [];
  Map<String, bool> _savedProjects = {};

  @override
  void initState() {
    super.initState();
    _loadContinueWatching();
  }

  Future<void> _loadContinueWatching() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projects = await _homeApi.getContinueWatching();
      // Load saved status for each project
      final savedStatus = <String, bool>{};
      for (final project in projects) {
        savedStatus[project.id] = await _projectApi.isProjectSaved(project.id);
      }
      if (mounted) {
        setState(() {
          _projects = projects;
          _savedProjects = savedStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleWatch(ProjectModel project) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    try {
      // Get episodes for this project
      final episodes = await _projectApi.getEpisodes(project.id);
      
      if (episodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No episodes available for this project'),
              backgroundColor: brandRed,
            ),
          );
        }
        return;
      }

      // Prefer backend watch-history (most recently watched episode), fallback to local progress.
      EpisodeModel? episodeToPlay;
      final lastEpisodeId = await _projectApi.getLastWatchedEpisodeId(project.id);
      if (lastEpisodeId != null && lastEpisodeId.isNotEmpty) {
        try {
          episodeToPlay = episodes.firstWhere((e) => e.id == lastEpisodeId);
        } catch (_) {
          episodeToPlay = null;
        }
      }

      // Fallback: find episode with highest local/remote progress
      if (episodeToPlay == null) {
        double maxProgress = 0.0;
        for (final episode in episodes) {
          final progress = await _projectApi.getWatchingProgress(project.id, episode.id);
          if (progress > maxProgress) {
            maxProgress = progress;
            episodeToPlay = episode;
          }
        }
      }

      episodeToPlay ??= episodes.first;
      
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EpisodePlayerScreen(
              episode: episodeToPlay!,
              projectTitle: project.title,
            ),
          ),
        );
        // Refresh after returning from player
        _loadContinueWatching();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: brandRed,
          ),
        );
      }
    }
  }

  Future<void> _handleBookmark(ProjectModel project) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    try {
      final isSaved = await _projectApi.isProjectSaved(project.id);
      if (isSaved) {
        await _projectApi.unsaveProject(project.id);
        if (mounted) {
          setState(() {
            _savedProjects[project.id] = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from saved'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _projectApi.saveProject(project.id);
        if (mounted) {
          setState(() {
            _savedProjects[project.id] = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: brandRed,
          ),
        );
      }
    }
  }

  Future<void> _handleShare(ProjectModel project) async {
    final shareText = '''
🏗️ ${project.title}
📍 ${project.location}
👷 ${project.developerName}

${project.script ?? 'Check out this amazing project!'}

شاهد المزيد على تطبيق Orientation!
''';

    try {
      await Share.share(shareText, subject: project.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error sharing'),
            backgroundColor: brandRed,
          ),
        );
      }
    }
  }

  void _openProjectDetails(ProjectModel project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsScreen(
          projectId: project.id,
        ),
      ),
    ).then((_) => _loadContinueWatching()); // Refresh after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            _buildAppBar(context),
            // Results header
            _buildResultsHeader(),
            // List
            Expanded(
              child: _buildProjectList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.chevron_left,
              color: Colors.white,
              size: 28,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Continue Watching',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            'Results',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${_projects.length} Orientation)',
            style: const TextStyle(
              color: brandRed,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: brandRed,
        ),
      );
    }

    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              color: Colors.white.withOpacity(0.3),
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              'No Continue Watching',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Projects you watch will appear here for easy access',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContinueWatching,
      color: brandRed,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
          final gradientColors = project.gradientColors.map((c) {
            final hex = c.replaceAll('0x', '');
            return Color(int.parse(hex, radix: 16));
          }).toList();
          
          final isSaved = _savedProjects[project.id] ?? false;
          
          // Use the SAME logic as ProjectsListScreen (View all)
          // Priority: projectThumbnailUrl > logo > image (if not video URL)
          // Check if image is a video URL (ends with .mp4, .mov, .avi, etc. or contains 'video')
          final isImageVideo = project.image.toLowerCase().contains('.mp4') || 
                              project.image.toLowerCase().contains('.mov') || 
                              project.image.toLowerCase().contains('.avi') ||
                              project.image.toLowerCase().contains('video');
          
          final fallbackImage = (!isImageVideo && project.image.isNotEmpty) ? project.image : 
                               (project.logo != null && project.logo!.isNotEmpty) ? project.logo! : null;
          
          final imageUrl = (project.isAsset && project.projectThumbnailUrl.startsWith('assets/')) 
              ? null 
              : (project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : fallbackImage);
          final imageAsset = (project.isAsset && project.projectThumbnailUrl.startsWith('assets/')) 
              ? (project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : 
                 (fallbackImage != null && fallbackImage.startsWith('assets/') ? fallbackImage : null))
              : null;
          
          print('📋 ContinueWatchingScreen: Building item for "${project.title}" (id: ${project.id})');
          print('   projectThumbnailUrl: "${project.projectThumbnailUrl}"');
          print('   image: "${project.image}"');
          print('   isAsset: ${project.isAsset}, startsWith assets/: ${project.projectThumbnailUrl.startsWith('assets/')}');
          print('   Using imageAsset: $imageAsset');
          print('   Using imageUrl: $imageUrl');
          
          return ProjectListItem(
            projectId: project.id,
            developerName: project.developerName,
            projectName: project.title,
            gradientColors: gradientColors,
            isSaved: isSaved,
            imageUrl: imageUrl,
            imageAsset: imageAsset,
            onTap: () => _openProjectDetails(project),
            onWatch: () => _handleWatch(project),
            onBookmark: () => _handleBookmark(project),
            onShare: () => _handleShare(project),
          );
        },
      ),
    );
  }
}

