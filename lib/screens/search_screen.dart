import 'package:flutter/material.dart';
import '../widgets/project_card.dart';
import '../utils/auth_helper.dart';
import '../utils/debouncer.dart';
import '../services/api/home_api.dart';
import '../services/api/project_api.dart';
import '../models/project_model.dart';
import '../models/developer_model.dart';
import 'project_details_screen.dart';
import 'latest_for_us_screen.dart';
import 'projects_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const Color brandRed = Color(0xFFE50914);

  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 500));
  final HomeApi _homeApi = HomeApi();
  final ProjectApi _projectApi = ProjectApi();
  
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Projects', 'Developers', 'Areas'];
  
  // Data from API
  List<ProjectModel> _allProjects = [];
  List<DeveloperModel> _allDevelopers = [];
  List<ProjectModel> _latestProjects = [];
  List<ProjectModel> _continueWatching = [];
  List<ProjectModel> _newCairoProjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('🔄 Loading search screen data...');
      final results = await Future.wait([
        _projectApi.getProjects(limit: 100).catchError((e) {
          print('❌ Error loading projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getDevelopers().catchError((e) {
          print('❌ Error loading developers: $e');
          return <DeveloperModel>[];
        }),
        _homeApi.getLatestProjects().catchError((e) {
          print('❌ Error loading latest projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getContinueWatching().catchError((e) {
          print('❌ Error loading continue watching: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getProjectsByArea('New Cairo').catchError((e) {
          print('❌ Error loading New Cairo projects: $e');
          return <ProjectModel>[];
        }),
      ]);
      
      if (mounted) {
        setState(() {
          _allProjects = results[0] as List<ProjectModel>;
          _allDevelopers = results[1] as List<DeveloperModel>;
          _latestProjects = results[2] as List<ProjectModel>;
          _continueWatching = results[3] as List<ProjectModel>;
          _newCairoProjects = results[4] as List<ProjectModel>;
          _isLoading = false;
        });
        
        print('✅ Search data loaded:');
        print('  - Projects: ${_allProjects.length}');
        print('  - Latest: ${_latestProjects.length}');
        print('  - Continue Watching: ${_continueWatching.length}');
        print('  - New Cairo: ${_newCairoProjects.length}');
        
        // Debug: Check image URLs
        if (_latestProjects.isNotEmpty) {
          final firstProject = _latestProjects[0];
          print('📸 Sample project image URLs:');
          print('  - projectThumbnailUrl: ${firstProject.projectThumbnailUrl}');
          print('  - image: ${firstProject.image}');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error loading search data: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  List<ProjectModel> get _filteredProjects {
    if (_searchQuery.isEmpty) return _allProjects;
    final query = _searchQuery.toLowerCase();
    return _allProjects.where((p) =>
      p.title.toLowerCase().contains(query) ||
      p.location.toLowerCase().contains(query) ||
      p.area.toLowerCase().contains(query) ||
      p.developerName.toLowerCase().contains(query) ||
      p.subtitle.toLowerCase().contains(query)
    ).toList();
  }

  List<DeveloperModel> get _filteredDevelopers {
    if (_searchQuery.isEmpty) return _allDevelopers;
    final query = _searchQuery.toLowerCase();
    return _allDevelopers.where((d) =>
      d.name.toLowerCase().contains(query)
    ).toList();
  }

  // Get unique areas from projects
  List<String> get _allAreas {
    final areas = <String>{};
    for (var project in _allProjects) {
      if (project.area.isNotEmpty) {
        areas.add(project.area);
      }
      if (project.location.isNotEmpty) {
        areas.add(project.location);
      }
    }
    return areas.toList();
  }

  List<String> get _filteredAreas {
    if (_searchQuery.isEmpty) return _allAreas;
    final query = _searchQuery.toLowerCase();
    return _allAreas.where((a) =>
      a.toLowerCase().contains(query)
    ).toList();
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
            // Search bar
            _buildSearchBar(),
            // Filter tabs
            _buildFilterTabs(),
            // Results
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildInitialContent(context)
                  : _buildSearchResults(),
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
                'Search',
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search,
              color: Colors.white.withOpacity(0.5),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search for a project....',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  // Use debouncer to delay search updates
                  _debouncer.call(() {
                    if (mounted) {
                      setState(() {
                        _searchQuery = value;
                      });
                    }
                  });
                },
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.5),
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? brandRed : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? brandRed : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitialContent(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(
            color: brandRed,
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          
          // Show based on filter
          if (_selectedFilter == 'All' || _selectedFilter == 'Projects') ...[
            // The latest for us section
            if (_latestProjects.isNotEmpty)
              _buildSection(
                context,
                'The latest for us',
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LatestForUsScreen(),
                    ),
                  );
                },
                child: _buildLatestList(context),
              ),
            // Continue watching section
            if (_continueWatching.isNotEmpty)
              _buildSection(
                context,
                'Continue watching',
                onViewAll: () {},
                child: _buildContinueWatchingList(),
              ),
            // Projects in New Cairo section
            if (_newCairoProjects.isNotEmpty)
              _buildSection(
                context,
                'Projects in New Cairo',
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProjectsListScreen(
                        title: 'Projects in New Cairo',
                      ),
                    ),
                  );
                },
                child: _buildNewCairoList(context),
              ),
          ],
          
          if (_selectedFilter == 'Developers') ...[
            if (_allDevelopers.isNotEmpty)
              _buildSection(
                context,
                'Top Developers',
                onViewAll: () {},
                child: _buildDevelopersList(),
              ),
          ],
          
          if (_selectedFilter == 'Areas') ...[
            if (_allAreas.isNotEmpty)
              _buildSection(
                context,
                'Popular Areas',
                onViewAll: () {},
                child: _buildAreasList(),
              ),
          ],
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    // Check if there are results based on selected filter
    bool hasResults = false;
    
    if (_selectedFilter == 'All') {
      hasResults = _filteredProjects.isNotEmpty || 
                   _filteredDevelopers.isNotEmpty || 
                   _filteredAreas.isNotEmpty;
    } else if (_selectedFilter == 'Projects') {
      hasResults = _filteredProjects.isNotEmpty;
    } else if (_selectedFilter == 'Developers') {
      hasResults = _filteredDevelopers.isNotEmpty;
    } else if (_selectedFilter == 'Areas') {
      hasResults = _filteredAreas.isNotEmpty;
    }

    if (!hasResults) {
      return _buildNoResults();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Projects results
          if ((_selectedFilter == 'All' || _selectedFilter == 'Projects') && 
              _filteredProjects.isNotEmpty) ...[
            _buildSection(
              context,
              'Projects (${_filteredProjects.length})',
              onViewAll: () {},
              child: _buildProjectResults(),
            ),
          ],
          
          // Developers results
          if ((_selectedFilter == 'All' || _selectedFilter == 'Developers') && 
              _filteredDevelopers.isNotEmpty) ...[
            _buildSection(
              context,
              'Developers (${_filteredDevelopers.length})',
              onViewAll: () {},
              child: _buildDeveloperResults(),
            ),
          ],
          
          // Areas results
          if ((_selectedFilter == 'All' || _selectedFilter == 'Areas') && 
              _filteredAreas.isNotEmpty) ...[
            _buildSection(
              context,
              'Areas (${_filteredAreas.length})',
              onViewAll: () {},
              child: _buildAreaResults(),
            ),
          ],
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 50,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No results found',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"$_searchQuery"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectResults() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredProjects.length,
        itemBuilder: (context, index) {
          final project = _filteredProjects[index];
          final gradientColors = project.gradientColors.map((c) {
            final hex = c.replaceAll('0x', '');
            return Color(int.parse(hex, radix: 16));
          }).toList();
          
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _SearchProjectCard(
              title: project.title,
              subtitle: project.subtitle.isNotEmpty ? project.subtitle : project.location,
              imageUrl: project.isAsset ? null : (project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image),
              imageAsset: project.isAsset ? project.image : null,
              gradientColors: gradientColors,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailsScreen(
                      projectId: project.id,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeveloperResults() {
    return SizedBox(
      height: 115,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredDevelopers.length,
        itemBuilder: (context, index) {
          final developer = _filteredDevelopers[index];
          return _DeveloperCard(
            name: developer.name,
            projectCount: developer.projectsCount,
            logo: developer.logo,
            isAsset: developer.isAsset,
          );
        },
      ),
    );
  }

  Widget _buildAreaResults() {
    return SizedBox(
      height: 115,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredAreas.length,
        itemBuilder: (context, index) {
          final area = _filteredAreas[index];
          final projectCount = _allProjects.where((p) => 
            p.area == area || p.location == area
          ).length;
          return _AreaCard(
            name: area,
            projectCount: projectCount,
          );
        },
      ),
    );
  }

  Widget _buildDevelopersList() {
    return SizedBox(
      height: 115,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _allDevelopers.length,
        itemBuilder: (context, index) {
          final developer = _allDevelopers[index];
          return _DeveloperCard(
            name: developer.name,
            projectCount: developer.projectsCount,
            logo: developer.logo,
            isAsset: developer.isAsset,
          );
        },
      ),
    );
  }

  Widget _buildAreasList() {
    final areas = _allAreas;
    return SizedBox(
      height: 115,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: areas.length,
        itemBuilder: (context, index) {
          final area = areas[index];
          final projectCount = _allProjects.where((p) => 
            p.area == area || p.location == area
          ).length;
          return _AreaCard(
            name: area,
            projectCount: projectCount,
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title, {
    required VoidCallback onViewAll,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: brandRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildLatestList(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _latestProjects.length,
        itemBuilder: (context, index) {
          final project = _latestProjects[index];
          final gradientColors = project.gradientColors.map((c) {
            final hex = c.replaceAll('0x', '');
            return Color(int.parse(hex, radix: 16));
          }).toList();
          
          return Padding(
            padding: EdgeInsets.only(right: index < _latestProjects.length - 1 ? 12 : 0),
            child: _SearchProjectCard(
              title: project.title,
              subtitle: project.subtitle.isNotEmpty ? project.subtitle : project.location,
              imageUrl: project.isAsset ? null : (project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image),
              imageAsset: project.isAsset ? project.image : null,
              gradientColors: gradientColors,
              onTap: () async {
                final isLoggedIn = await AuthHelper.requireAuth(context);
                if (isLoggedIn && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectDetailsScreen(
                        projectId: project.id,
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildContinueWatchingList() {
    return SizedBox(
      height: 145,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _continueWatching.length,
        itemBuilder: (context, index) {
          final project = _continueWatching[index];
          final progress = project.watchProgress ?? 0.0;
          
          return Padding(
            padding: EdgeInsets.only(right: index < _continueWatching.length - 1 ? 12 : 0),
            child: _ContinueWatchingCard(
              title: project.title,
              progress: progress,
              imageUrl: project.isAsset ? null : (project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image),
              imageAsset: project.isAsset ? project.image : null,
              gradientColors: project.gradientColors.map((c) {
                final hex = c.replaceAll('0x', '');
                return Color(int.parse(hex, radix: 16));
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewCairoList(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _newCairoProjects.length,
        itemBuilder: (context, index) {
          final project = _newCairoProjects[index];
          final gradientColors = project.gradientColors.map((c) {
            final hex = c.replaceAll('0x', '');
            return Color(int.parse(hex, radix: 16));
          }).toList();
          
          return Padding(
            padding: EdgeInsets.only(right: index < _newCairoProjects.length - 1 ? 12 : 0),
            child: ProjectCard(
              title: project.title,
              imageUrl: project.isAsset ? null : (project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image),
              imageAsset: project.isAsset ? project.image : null,
              gradientColors: gradientColors,
              width: 150,
              height: 150,
              onTap: () async {
                final isLoggedIn = await AuthHelper.requireAuth(context);
                if (isLoggedIn && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectDetailsScreen(
                        projectId: project.id,
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

}

class _SearchProjectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageAsset;
  final String? imageUrl;
  final List<Color> gradientColors;
  final bool hasPromo;
  final VoidCallback? onTap;

  const _SearchProjectCard({
    required this.title,
    required this.subtitle,
    this.imageAsset,
    this.imageUrl,
    required this.gradientColors,
    this.hasPromo = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        height: 210,
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              if (imageAsset != null)
                Image.asset(
                  imageAsset!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: gradientColors,
                        ),
                      ),
                    );
                  },
                )
              else if (imageUrl != null && imageUrl!.isNotEmpty)
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: gradientColors,
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ Error loading image: $imageUrl - $error');
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: gradientColors,
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradientColors,
                    ),
                  ),
                ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              // Title at top
              Positioned(
                top: 16,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              // Promo badges at bottom
              if (hasPromo)
                Positioned(
                  bottom: 14,
                  left: 12,
                  child: Row(
                    children: [
                      _PromoBadge(text: '5%'),
                      const SizedBox(width: 8),
                      _PromoBadge(text: '8'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoBadge extends StatelessWidget {
  final String text;

  const _PromoBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final String title;
  final double progress;
  final String? imageAsset;
  final String? imageUrl;
  final List<Color> gradientColors;

  const _ContinueWatchingCard({
    required this.title,
    required this.progress,
    this.imageAsset,
    this.imageUrl,
    this.gradientColors = const [Color(0xFFd4c4b0), Color(0xFFc4b4a0)],
  });

  static const Color brandRed = Color(0xFFE50914);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 180,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                if (imageAsset != null)
                  Image.asset(
                    imageAsset!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                          ),
                        ),
                      );
                    },
                  )
                else if (imageUrl != null && imageUrl!.isNotEmpty)
                  Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('❌ Error loading image: $imageUrl - $error');
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                          ),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                      ),
                    ),
                  ),
                // Title overlay
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
                // Progress bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.black.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(brandRed),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 40),
            Text(
              '01:45 H',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  final String name;
  final int projectCount;
  final String logo;
  final bool isAsset;

  const _DeveloperCard({
    required this.name,
    required this.projectCount,
    this.logo = '',
    this.isAsset = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: logo.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isAsset
                        ? Image.asset(
                            logo,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.business,
                                color: Colors.white.withOpacity(0.7),
                                size: 20,
                              );
                            },
                          )
                        : Image.network(
                            logo,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.business,
                                color: Colors.white.withOpacity(0.7),
                                size: 20,
                              );
                            },
                          ),
                  )
                : Icon(
                    Icons.business,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$projectCount projects',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final String name;
  final int projectCount;

  const _AreaCard({
    required this.name,
    required this.projectCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE50914).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFFE50914),
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$projectCount projects',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
