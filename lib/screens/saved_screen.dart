import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/project_model.dart';
import '../models/clip_model.dart';
import '../services/api/project_api.dart';
import '../services/clip_service.dart';
import '../utils/auth_helper.dart';
import 'project_details_screen.dart';
import 'login_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with SingleTickerProviderStateMixin {
  final ProjectApi _projectApi = Get.find<ProjectApi>();
  late final ClipService _clipService;
  late TabController _tabController;

  List<ProjectModel> _savedProjects = [];
  List<ClipModel> _savedReels = [];
  bool _isLoadingProjects = true;
  bool _isLoadingReels = true;
  bool _isRefreshing = false; // Prevent multiple simultaneous refreshes

  @override
  void initState() {
    super.initState();
    _clipService = Get.find<ClipService>();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedProjects();
    _loadSavedReels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProjects() async {
    if (!mounted) return;

    setState(() {
      _isLoadingProjects = true;
    });

    try {
      final projects = await _projectApi.getSavedProjects();
      if (mounted) {
        setState(() {
          _savedProjects = projects;
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      print('⚠️ Error loading saved projects: $e');
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
        });
      }
    }
  }

  Future<void> _loadSavedReels() async {
    if (!mounted) return;

    setState(() {
      _isLoadingReels = true;
    });

    try {
      // 1. Get saved reels (might have missing fields from some endpoints)
      final savedReels = await _clipService.getSavedReels();

      // 2. Hydrate only the clips we need (parallel getClipById - no loading all clips)
      final hydratedReels = await Future.wait(
        savedReels.map((saved) async {
          final full = await _clipService.getClipById(saved.id);
          if (full != null &&
              (saved.thumbnail.isEmpty && full.thumbnail.isNotEmpty)) {
            return full;
          }
          return full ?? saved;
        }),
      );

      if (mounted) {
        setState(() {
          _savedReels = hydratedReels;
          _isLoadingReels = false;
        });
      }
    } catch (e) {
      print('⚠️ Error loading saved reels: $e');
      if (mounted) {
        setState(() {
          _isLoadingReels = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    if (!mounted || _isRefreshing) return;

    _isRefreshing = true;
    try {
      await Future.wait([
        _loadSavedProjects(),
        _loadSavedReels(),
      ]);
    } finally {
      if (mounted) {
        _isRefreshing = false;
      }
    }
  }

  Future<void> _removeFromSaved(ProjectModel project) async {
    if (!mounted) return;

    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth || !mounted) return;

    // Optimistic update
    if (mounted) {
      setState(() {
        _savedProjects.removeWhere((p) => p.id == project.id);
      });
    }

    try {
      await _projectApi.unsaveProject(project.id);
      if (mounted) {
        _showSnackBar('Removed from saved');
      }
    } catch (e) {
      print('⚠️ Error removing project: $e');
      // Revert on error
      if (mounted) {
        _loadSavedProjects();
        _showSnackBar('Error removing project', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
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
            // Tabs
            _buildTabs(),
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Projects Tab
                  _isLoadingProjects
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE50914),
                          ),
                        )
                      : _savedProjects.isEmpty
                          ? _buildEmptyState('No Saved Projects',
                              'Projects you save will appear here for easy access')
                          : _buildSavedProjectsList(),
                  // Reels Tab
                  _isLoadingReels
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE50914),
                          ),
                        )
                      : _savedReels.isEmpty
                          ? _buildEmptyState('No Saved Reels',
                              'Reels you save will appear here for easy access')
                          : _buildSavedReelsList(),
                ],
              ),
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
                'Saved',
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

  Widget _buildTabs() {
    return Container(
      color: Colors.black,
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent, // Remove the white line
        indicatorColor: const Color(0xFFE50914),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: 'Projects'),
          Tab(text: 'Reels'),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: const Color(0xFFE50914),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_outline,
                  color: Colors.white.withOpacity(0.3),
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
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
                    message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedProjectsList() {
    return RefreshIndicator(
      onRefresh: _loadSavedProjects,
      color: const Color(0xFFE50914),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _savedProjects.length,
        itemBuilder: (context, index) {
          final project = _savedProjects[index];
          return _SavedProjectItem(
            project: project,
            onTap: () async {
              final isAuth = await AuthHelper.requireAuth(context);
              if (!isAuth) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailsScreen(
                    projectId: project.id,
                  ),
                ),
              ).then((_) {
                if (mounted) {
                  _refreshAll();
                }
              }); // Refresh on return
            },
            onRemove: () => _removeFromSaved(project),
          );
        },
      ),
    );
  }

  Widget _buildSavedReelsList() {
    return RefreshIndicator(
      onRefresh: _loadSavedReels,
      color: const Color(0xFFE50914),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: _savedReels.length,
        itemBuilder: (context, index) {
          final reel = _savedReels[index];
          return _SavedReelItem(
            reel: reel,
            onTap: () async {
              final isAuth = await AuthHelper.requireAuth(context);
              if (!isAuth) return;

              // Navigate to project details or reel player
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailsScreen(
                    projectId: reel.projectId,
                  ),
                ),
              ).then((_) {
                if (mounted) {
                  _refreshAll();
                }
              });
            },
            onRemove: () => _removeFromSavedReel(reel),
          );
        },
      ),
    );
  }

  Future<void> _removeFromSavedReel(ClipModel reel) async {
    if (!mounted) return;

    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth || !mounted) return;

    // Optimistic update
    if (mounted) {
      setState(() {
        _savedReels.removeWhere((r) => r.id == reel.id);
      });
    }

    try {
      await _clipService.unsaveReel(reel.id);
      if (mounted) {
        _showSnackBar('Removed from saved');
      }
    } catch (e) {
      print('⚠️ Error removing reel: $e');
      // Revert on error
      if (mounted) {
        _loadSavedReels();
        _showSnackBar('Error removing reel', isError: true);
      }
    }
  }
}

class _SavedProjectItem extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _SavedProjectItem({
    required this.project,
    this.onTap,
    this.onRemove,
  });

  List<Color> _parseGradientColors() {
    try {
      return project.gradientColors.map((colorStr) {
        final hexColor = colorStr.replaceAll('0x', '').replaceAll('#', '');
        return Color(int.parse(hexColor, radix: 16));
      }).toList();
    } catch (e) {
      return [const Color(0xFF4A90A4), const Color(0xFF2d6a7a)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _parseGradientColors();

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (project.projectThumbnailUrl.isNotEmpty ||
                        project.image.isNotEmpty)
                    ? (project.isAsset
                        ? Image.asset(
                            project.projectThumbnailUrl.isNotEmpty
                                ? project.projectThumbnailUrl
                                : project.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : Image.network(
                            project.projectThumbnailUrl.isNotEmpty
                                ? project.projectThumbnailUrl
                                : project.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          ))
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.developerName.isNotEmpty
                        ? project.developerName
                        : project.area,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (project.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      project.location,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Watch button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Watch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Remove button
            IconButton(
              icon: const Icon(
                Icons.favorite,
                color: Color(0xFFE50914),
                size: 24,
              ),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        project.title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SavedReelItem extends StatelessWidget {
  final ClipModel reel;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _SavedReelItem({
    required this.reel,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Thumbnail
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade900,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: reel.thumbnail.isNotEmpty
                  ? ((reel.isAsset || reel.thumbnail.startsWith('assets/'))
                      ? Image.asset(
                          reel.thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : Image.network(
                          reel.thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        ))
                  : _buildPlaceholder(),
            ),
          ),
          // Play icon overlay
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          // Remove button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFFE50914),
                  size: 20,
                ),
              ),
            ),
          ),
          // Title overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Text(
                reel.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Icon(
          Icons.video_library_outlined,
          color: Colors.white.withOpacity(0.3),
          size: 40,
        ),
      ),
    );
  }
}
