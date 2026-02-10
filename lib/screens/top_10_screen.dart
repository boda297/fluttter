import 'package:flutter/material.dart';
import '../services/api/home_api.dart';
import '../models/project_model.dart';
import '../utils/auth_helper.dart';
import 'project_details_screen.dart';

class Top10Screen extends StatefulWidget {
  const Top10Screen({super.key});

  @override
  State<Top10Screen> createState() => _Top10ScreenState();
}

class _Top10ScreenState extends State<Top10Screen> {
  static const Color brandRed = Color(0xFFE50914);
  final HomeApi _homeApi = HomeApi();
  bool _isLoading = true;
  List<ProjectModel> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadTop10Projects();
  }

  Future<void> _loadTop10Projects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projects = await _homeApi.getTop10Projects();
      if (mounted) {
        setState(() {
          _projects = projects;
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

  void _openProjectDetails(ProjectModel project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsScreen(
          projectId: project.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Top 10',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: brandRed,
              ),
            )
          : _projects.isEmpty
              ? Center(
                  child: Text(
                    'No projects found',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    itemCount: _projects.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      return Top10Card(
                        rank: index + 1,
                        project: project,
                        onTap: () => _openProjectDetails(project),
                      );
                    },
                  ),
                ),
    );
  }
}

class Top10Card extends StatelessWidget {
  final int rank;
  final ProjectModel project;
  final VoidCallback? onTap;

  const Top10Card({
    super.key,
    required this.rank,
    required this.project,
    this.onTap,
  });

  String _getImagePath() {
    // Use project image if available, otherwise fallback to default
    if (project.image.isNotEmpty && project.isAsset) {
      return project.image;
    }
    // Default fallback based on rank
    return rank.isEven 
        ? 'assets/top10/masaya.png' 
        : 'assets/top10/the_icon.png';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Outline number (behind - shifted down/right as shadow)
          Positioned(
            left: 0,
            bottom: -15,
            child: Image.asset(
              'assets/top10/${rank}_outline.png',
              height: 85,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
          // Card image
          Positioned(
            top: 0,
            right: 0,
            left: 35,
            bottom: 35,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (project.projectThumbnailUrl.isNotEmpty || project.image.isNotEmpty)
                    ? (project.isAsset
                        ? Image.asset(
                            project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildFallbackImage();
                            },
                          )
                        : Image.network(
                            project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildFallbackImage();
                            },
                          ))
                    : _buildFallbackImage(),
              ),
            ),
          ),
          // Filled number (in front)
          Positioned(
            left: -8,
            bottom: -5,
            child: Image.asset(
              'assets/top10/$rank.png',
              height: 85,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage() {
    final gradientColors = project.gradientColors.map((c) {
      try {
        final hex = c.replaceAll('0x', '').replaceAll('#', '');
        return Color(int.parse(hex, radix: 16));
      } catch (e) {
        return const Color(0xFF4A90A4);
      }
    }).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors.isNotEmpty 
              ? gradientColors 
              : [const Color(0xFF4A90A4), const Color(0xFF2d6a7a)],
        ),
      ),
      child: Center(
        child: Text(
          project.title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
