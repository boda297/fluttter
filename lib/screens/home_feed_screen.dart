import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../widgets/project_card.dart';
import '../widgets/app_drawer.dart';
import '../widgets/skeleton_loader.dart';
import '../services/api/home_api.dart';
import '../services/api/auth_api.dart';
import '../services/cache_service.dart';
import '../models/project_model.dart';
import '../models/developer_model.dart';
import '../models/area_model.dart';
import '../utils/auth_helper.dart';
import 'project_details_screen.dart';
import 'latest_for_us_screen.dart';
import 'top_10_screen.dart';
import 'saved_screen.dart';
import 'developers_screen.dart';
import 'areas_screen.dart';
import 'projects_list_screen.dart';
import 'search_screen.dart';
import 'continue_watching_screen.dart';
import 'account_screen.dart';
import 'login_screen.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with WidgetsBindingObserver {
  final PageController _featuredController = PageController();
  final ScrollController _scrollController = ScrollController();
  final HomeApi _homeApi = HomeApi();
  final AuthApi _authApi = AuthApi();
  final CacheService _cacheService = CacheService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<AppDrawerState> _drawerKey = GlobalKey<AppDrawerState>();
  final GlobalKey _upcomingSectionKey = GlobalKey();
  
  int _currentFeaturedPage = 0;
  String _selectedFilter = 'Medical';
  bool _isLoading = true;
  String _userName = 'User';
  DateTime? _lastRefreshTime;

  final List<String> _filters = ['Medical', 'Commercial', 'Residential', 'Hotel'];

  // Video players for featured section - use Map to cache controllers
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Map<int, ChewieController> _chewieControllers = {};
  int _currentVideoIndex = -1; // Track which card's video is currently playing
  bool _isSwipingFeatured = false;
  int _swipeFromIndex = 0;
  int _swipeToIndex = 0;
  bool _isHeroVisible = true; // Track hero section visibility for pause/resume

  static const Color brandRed = Color(0xFFE50914);

  // Data from API
  List<ProjectModel> _featuredProjects = [];
  List<ProjectModel> _latestProjects = [];
  List<ProjectModel> _continueWatching = [];
  List<ProjectModel> _top10Projects = [];
  List<ProjectModel> _northCoastProjects = [];
  List<ProjectModel> _newCairoProjects = [];
  List<ProjectModel> _octoberProjects = [];
  List<ProjectModel> _upcomingProjects = [];
  List<DeveloperModel> _developers = [];
  List<AreaModel> _areas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _featuredController.addListener(_onFeaturedScroll);
    _scrollController.addListener(_onScroll);
    // Load data asynchronously to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadUserName();
    });
    // Video will be initialized after loading data (in _loadData)
  }

  void _onScroll() {
    // Lazy load area projects when user scrolls near those sections
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    
    // Calculate approximate scroll position for area sections
    // This is a simple heuristic - adjust based on your actual layout
    final scrollOffset = position.pixels;
    
    // Load North Coast projects when scrolling past ~2000px
    if (scrollOffset > 2000 && _northCoastProjects.isEmpty) {
      _loadAreaProjectsIfNeeded('North Coast');
    }
    // Load New Cairo projects when scrolling past ~3000px
    if (scrollOffset > 3000 && _newCairoProjects.isEmpty) {
      _loadAreaProjectsIfNeeded('New Cairo');
    }
    // Load October projects when scrolling past ~4000px
    if (scrollOffset > 4000 && _octoberProjects.isEmpty) {
      _loadAreaProjectsIfNeeded('October');
    }
  }

  void _onFeaturedScroll() {
    if (_featuredProjects.isEmpty) return;
    final page = _featuredController.page;
    if (page == null) return;

    final int floorIdx = page.floor();
    final int ceilIdx = page.ceil();
    final int maxIdx = _featuredProjects.length - 1;
    final int from = floorIdx.clamp(0, maxIdx);
    final int to = ceilIdx.clamp(0, maxIdx);

    final double frac = page - floorIdx;
    final bool isSwiping = frac > 0.001 && frac < 0.999 && from != to;

    if (isSwiping) {
      // Preload the two visible pages during swipe (current + neighbor)
      if (!_videoControllers.containsKey(from)) {
        _loadVideoForPage(from);
      }
      if (!_videoControllers.containsKey(to)) {
        _loadVideoForPage(to);
      }

      // Switch "active" video to the one user is swiping towards (after halfway)
      final int active = (frac >= 0.5) ? to : from;
      if (active != _currentVideoIndex) {
        _currentVideoIndex = active;
        _playVideoForPage(active);
      }
    }

    // Update swipe state used by UI to decide what to render
    if (mounted &&
        (isSwiping != _isSwipingFeatured ||
            from != _swipeFromIndex ||
            to != _swipeToIndex)) {
      setState(() {
        _isSwipingFeatured = isSwiping;
        _swipeFromIndex = from;
        _swipeToIndex = to;
      });
    }
  }

  Future<void> _initializeVideo() async {
    // Initialize video for first page (index 0) and preload adjacent ones
    await _loadVideoForPage(0);
    // Play first video after loading
    if (_videoControllers.containsKey(0) && mounted) {
      _currentVideoIndex = 0;
      _playVideoForPage(0);
    }
    // Preload all adjacent videos for smooth transitions
    if (_featuredProjects.length > 1) {
      _loadVideoForPage(1); // Preload next video
    }
    if (_featuredProjects.length > 2) {
      _loadVideoForPage(2); // Preload third video
    }
  }

  Future<void> _loadVideoForPage(int index) async {
    if (index < 0 || index >= _featuredProjects.length) {
      return;
    }

    // If video is already loaded, just return
    if (_videoControllers.containsKey(index)) {
      return;
    }

    try {
      final project = _featuredProjects[index];
      final heroVideoUrl = project.advertisementVideoUrl;

      if (heroVideoUrl.isEmpty) {
        print('⚠️ No hero video URL for project at index $index: ${project.title}');
        return;
      }

      print('🎥 Loading hero video for page $index: $heroVideoUrl');

      // Initialize video controller based on source
      final isNetworkVideo = !heroVideoUrl.startsWith('assets/');
      VideoPlayerController controller;
      
      if (isNetworkVideo) {
        controller = VideoPlayerController.networkUrl(Uri.parse(heroVideoUrl));
      } else {
        controller = VideoPlayerController.asset(heroVideoUrl);
      }

      await controller.initialize();
      
      if (!mounted) {
        await controller.dispose();
        return;
      }
      
      // Mute the video
      await controller.setVolume(0.0);
      
      // Calculate aspect ratio
      final screenWidth = MediaQuery.of(context).size.width;
      final containerHeight = MediaQuery.of(context).size.height * 0.65;
      final targetAspectRatio = screenWidth / containerHeight;
      
      final chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false, // Don't auto-play, we'll control it
        looping: false,
        aspectRatio: targetAspectRatio,
        showControls: false,
        allowFullScreen: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: false,
        errorBuilder: (context, errorMessage) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF4A90A4).withOpacity(0.3),
                  const Color(0xFF2d6a7a).withOpacity(0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.5],
              ),
            ),
          );
        },
      );

      // Add listener for video completion
      controller.addListener(() => _videoListenerForIndex(index, controller));

      if (mounted) {
        setState(() {
          _videoControllers[index] = controller;
          _chewieControllers[index] = chewieController;
          // If this is the current page, update video index to show it immediately
          if (_currentFeaturedPage == index) {
            _currentVideoIndex = index;
          }
        });
        print('✅ Video loaded for page $index');
        
        // If this is the current page, play it immediately
        if (_currentFeaturedPage == index && mounted) {
          controller.play();
          setState(() {
            _currentVideoIndex = index;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading video for page $index: $e');
    }
  }

  void _videoListenerForIndex(int index, VideoPlayerController controller) {
    if (!controller.value.isInitialized ||
        controller.value.duration.inMilliseconds == 0) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    
    // Check if video has ended
    if (position.inMilliseconds >= (duration.inMilliseconds - 100)) {
      // Video ended, move to next project if we're on this page
      if (_currentFeaturedPage == index && 
          _featuredProjects.length > 1 && 
          mounted) {
        final nextIndex = (index + 1) % _featuredProjects.length;
        _featuredController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _playVideoForPage(int index) {
    // Store previous index
    final previousIndex = _currentVideoIndex;
    
    // Pause previous video first
    if (previousIndex >= 0 && 
        previousIndex != index && 
        _videoControllers.containsKey(previousIndex)) {
      _videoControllers[previousIndex]?.pause();
    }

    // Play current video if it's loaded
    if (_videoControllers.containsKey(index)) {
      final controller = _videoControllers[index]!;
      if (!controller.value.isPlaying) {
        controller.play();
      }
      print('▶️ Playing video for page $index');
    } else {
      // Video not loaded yet, load it first
      _loadVideoForPage(index).then((_) {
        if (_videoControllers.containsKey(index) && mounted) {
          final controller = _videoControllers[index]!;
          controller.seekTo(Duration.zero);
          controller.play();
          if (mounted) {
            setState(() {
              _currentVideoIndex = index;
            });
          }
        }
      });
    }

    // Dispose old videos (keep only current and adjacent)
    _disposeOldVideoControllers(index);
  }

  void _disposeOldVideoControllers(int currentIndex) {
    final keysToRemove = <int>[];
    for (var key in _videoControllers.keys) {
      if ((key - currentIndex).abs() > 2) {
        keysToRemove.add(key);
      }
    }
    for (var key in keysToRemove) {
      _videoControllers[key]?.removeListener(() {});
      _chewieControllers[key]?.dispose();
      _videoControllers[key]?.dispose();
      _videoControllers.remove(key);
      _chewieControllers.remove(key);
      print('🗑️ Disposed video for page $key');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh continue watching when screen becomes visible again (with debounce)
    final now = DateTime.now();
    if (_lastRefreshTime == null || 
        now.difference(_lastRefreshTime!).inSeconds > 2) {
      _lastRefreshTime = now;
      _refreshContinueWatching();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh continue watching when app comes back to foreground
      _refreshContinueWatching();
    }
  }

  Future<void> _refreshContinueWatching() async {
    try {
      print('🔄 Refreshing continue watching...');
      final continueWatching = await _homeApi.getContinueWatching();
      print('📊 Got ${continueWatching.length} continue watching projects');
      if (mounted) {
        setState(() {
          _continueWatching = continueWatching;
          _lastRefreshTime = DateTime.now();
        });
        print('✅ Continue watching updated in UI: ${_continueWatching.length} projects');
      } else {
        print('⚠️ Widget not mounted, skipping setState');
      }
    } catch (e, stackTrace) {
      print('❌ Error refreshing continue watching: $e');
      print('Stack trace: $stackTrace');
      // Silently fail - don't show error for background refresh
    }
  }

  // Public method to refresh continue watching (can be called from MainScreen)
  void refreshContinueWatching() {
    _refreshContinueWatching();
  }

  // Test method to add sample progress (for debugging)
  Future<void> _loadUserName() async {
    final isLoggedIn = await _authApi.isLoggedIn();
    if (!mounted) return;
    
    if (!isLoggedIn) {
      setState(() {
        _userName = 'Guest';
      });
      return;
    }
    
    // User is logged in, load user info
    final userInfo = await _authApi.getStoredUserInfo();
    if (!mounted) return;
    
    setState(() {
      // Use firstName + lastName if available, otherwise fallback to username
      final firstName = userInfo['firstName'] ?? '';
      final lastName = userInfo['lastName'] ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        _userName = '$firstName $lastName'.trim();
      } else {
        _userName = userInfo['username'] ?? 'User';
      }
    });
  }

  // Public method to refresh user name (called from MainScreen)
  void refreshUserName() {
    _loadUserName();
  }

  Future<void> _loadData() async {
    print('🔄 Starting _loadData()...');
    try {
      // Priority 1: Load essential data first (visible immediately)
      print('📡 Loading essential data (Priority 1)...');
      final essentialResults = await Future.wait([
        _homeApi.getFeaturedProjects(useCache: true).catchError((e) {
          print('Error loading featured projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getLatestProjects(useCache: true).catchError((e) {
          print('Error loading latest projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getContinueWatching().catchError((e) {
          print('Error loading continue watching: $e');
          return <ProjectModel>[];
        }),
      ]);

      // Update UI with essential data first
      if (mounted) {
        final allFeatured = essentialResults[0] as List<ProjectModel>;
        final featuredOnly = allFeatured.where((p) => p.isFeatured).toList();
        final latest = essentialResults[1] as List<ProjectModel>;
        final continueWatching = essentialResults[2] as List<ProjectModel>;
        
        print('📊 Data received:');
        print('   Featured (all): ${allFeatured.length}, Featured (filtered): ${featuredOnly.length}');
        print('   Latest: ${latest.length}');
        print('   Continue Watching: ${continueWatching.length}');
        
        setState(() {
          _featuredProjects = featuredOnly;
          _latestProjects = latest;
          _continueWatching = continueWatching;
          _isLoading = false; // Show UI immediately
        });
        print('✅ Essential data loaded and UI updated. Featured: ${_featuredProjects.length}, Latest: ${_latestProjects.length}, Continue: ${_continueWatching.length}');
        _initializeVideo(); // Initialize video with featured projects
        
        // Cache home content in background (non-blocking)
        // Combines all project lists for caching
        final allProjects = <ProjectModel>[
          ...featuredOnly,
          ...latest,
          ...continueWatching,
        ];
        _cacheService.cacheHomeContent(allProjects);
      } else {
        print('⚠️ Widget not mounted, skipping setState');
      }

      // Priority 2: Load secondary data in background (lazy load)
      print('📡 Loading secondary data (Priority 2 - background)...');
      _loadSecondaryData();
      
    } catch (e) {
      print('❌ Unexpected error in _loadData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSecondaryData() async {
    try {
      // Load secondary data in background (not blocking UI)
      final results = await Future.wait([
        _homeApi.getTop10Projects(useCache: true).catchError((e) {
          print('Error loading top 10 projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getUpcomingProjects(useCache: true).catchError((e) {
          print('Error loading upcoming projects: $e');
          return <ProjectModel>[];
        }),
        _homeApi.getDevelopers().catchError((e) {
          print('Error loading developers: $e');
          return <DeveloperModel>[];
        }),
        _homeApi.getAreas().catchError((e) {
          print('Error loading areas: $e');
          return <AreaModel>[];
        }),
      ]);

      if (mounted) {
        setState(() {
          _top10Projects = results[0] as List<ProjectModel>;
          _upcomingProjects = results[1] as List<ProjectModel>;
          _developers = results[2] as List<DeveloperModel>;
          _areas = results[3] as List<AreaModel>;
        });
        print('✅ Secondary data loaded');
      }

      // Priority 3: Load area-specific projects immediately (not lazy)
      print('📡 Loading area projects...');
      await Future.wait([
        _loadAreaProjectsIfNeeded('North Coast'),
        _loadAreaProjectsIfNeeded('New Cairo'),
        _loadAreaProjectsIfNeeded('October'),
      ]);
      print('✅ Area projects loaded');
      
    } catch (e) {
      print('❌ Error loading secondary data: $e');
    }
  }

  // Lazy load area projects when user scrolls to that section
  Future<void> _loadAreaProjectsIfNeeded(String area) async {
    // Check if already loaded
    if (area == 'North Coast' && _northCoastProjects.isNotEmpty) return;
    if (area == 'New Cairo' && _newCairoProjects.isNotEmpty) return;
    if (area == 'October' && _octoberProjects.isNotEmpty) return;

    try {
      print('📡 Lazy loading projects for area: $area');
      final projects = await _homeApi.getProjectsByArea(area, useCache: true);
      if (mounted) {
        setState(() {
          if (area == 'North Coast') {
            _northCoastProjects = projects;
          } else if (area == 'New Cairo') {
            _newCairoProjects = projects;
          } else if (area == 'October') {
            _octoberProjects = projects;
          }
        });
        print('✅ Loaded ${projects.length} projects for $area');
      }
    } catch (e) {
      print('❌ Error loading projects for $area: $e');
    }
  }

  // _videoListener is now handled by _videoListenerForIndex

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _featuredController.removeListener(_onFeaturedScroll);
    _featuredController.dispose();
    _scrollController.dispose();
    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    for (var controller in _chewieControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    _chewieControllers.clear();
    super.dispose();
  }

  /// Pause all videos (called when switching away from Home tab)
  void pauseVideos() {
    for (var controller in _videoControllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  /// Resume video playback (called when switching back to Home tab)
  void resumeVideos() {
    if (_isHeroVisible && _videoControllers.containsKey(_currentVideoIndex)) {
      _videoControllers[_currentVideoIndex]?.play();
    }
  }

  void scrollToUpcomingProjects() {
    // Scroll to upcoming projects section using the key
    Future.delayed(const Duration(milliseconds: 100), () {
      final context = _upcomingSectionKey.currentContext;
      if (context != null && mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1, // Scroll to show the section near the top with some padding
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      drawer: AppDrawer(
        key: _drawerKey,
        onScrollToUpcoming: scrollToUpcomingProjects,
      ),
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          // Refresh auth status when drawer is opened
          _drawerKey.currentState?.refreshAuthStatus();
          // Also refresh user name
          _loadUserName();
        }
      },
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Hero section with AppBar, Filters, and Carousel
          SliverToBoxAdapter(
            child: _buildHeroSection(),
          ),
          // Page indicator
          SliverToBoxAdapter(
            child: _buildPageIndicator(),
          ),
          // Sections
          SliverToBoxAdapter(
            child: _buildSection(
              'The latest for us',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LatestForUsScreen(),
                  ),
                );
              },
              child: _buildHorizontalProjectList(),
            ),
          ),
          // Only show "Continue watching" section if there are videos or still loading
          if (_continueWatching.isNotEmpty || _isLoading)
            SliverToBoxAdapter(
              child: _buildSection(
                'Continue watching',
                onViewAll: () async {
                  final isAuth = await AuthHelper.requireAuth(context);
                  if (!isAuth) return;
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContinueWatchingScreen(),
                    ),
                  );
                },
                child: _buildContinueWatchingList(),
              ),
            ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Top 10',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Top10Screen(),
                  ),
                );
              },
              child: _buildTop10List(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Projects in Northcoast',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProjectsListScreen(
                      title: 'Projects in Northcoast',
                    ),
                  ),
                );
              },
              child: _buildNorthcoastProjects(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Projects in New Cairo',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProjectsListScreen(
                      title: 'Projects in New Cairo',
                    ),
                  ),
                );
              },
              child: _buildNewCairoProjects(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSection(
              'Projects in October',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProjectsListScreen(
                      title: 'Projects in October',
                    ),
                  ),
                );
              },
              child: _buildOctoberProjects(),
            ),
          ),
          SliverToBoxAdapter(
            key: _upcomingSectionKey,
            child: _buildSection(
              'Upcoming Projects',
              onViewAll: null,
              child: _buildUpcomingProjectsList(),
            ),
          ),

          SliverToBoxAdapter(
            child: _buildSection(
              'Discover Areas',
              onViewAll: () async {
                final isAuth = await AuthHelper.requireAuth(context);
                if (!isAuth) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AreasScreen(),
                  ),
                );
              },
              child: _buildAreaChips(),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }

  // Hero section with overlaying AppBar and Filters on Carousel
  Widget _buildHeroSection() {
    return VisibilityDetector(
      key: const Key('home_hero_video'),
      onVisibilityChanged: (info) {
        final isVisible = info.visibleFraction >= 0.5;
        if (isVisible != _isHeroVisible) {
          _isHeroVisible = isVisible;
          if (isVisible) {
            // Resume video from current position
            if (_videoControllers.containsKey(_currentVideoIndex)) {
              _videoControllers[_currentVideoIndex]?.play();
            }
          } else {
            // Pause video (position is preserved automatically)
            if (_videoControllers.containsKey(_currentVideoIndex)) {
              _videoControllers[_currentVideoIndex]?.pause();
            }
          }
        }
      },
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65, // 65% of screen height
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Carousel - full width and height
          PageView.builder(
            controller: _featuredController,
            onPageChanged: (index) {
              // Update indices IMMEDIATELY before setState to show video during swipe
              _currentVideoIndex = index;
              _currentFeaturedPage = index;
              
              // Force immediate rebuild to show video during transition
              if (mounted) {
                setState(() {
                  _currentFeaturedPage = index;
                  _currentVideoIndex = index;
                });
              }
              
              // Play video immediately
              _playVideoForPage(index);
              
              // Preload adjacent videos for next swipe
              if (index + 1 < _featuredProjects.length && !_videoControllers.containsKey(index + 1)) {
                _loadVideoForPage(index + 1);
              }
              if (index + 2 < _featuredProjects.length && !_videoControllers.containsKey(index + 2)) {
                _loadVideoForPage(index + 2);
              }
              if (index - 1 >= 0 && !_videoControllers.containsKey(index - 1)) {
                _loadVideoForPage(index - 1);
              }
            },
            itemCount: _featuredProjects.length,
            itemBuilder: (context, index) {
              final project = _featuredProjects[index];
              return _buildFeaturedCard(context, project, index);
            },
            // Performance optimization: add keys for better widget reuse
            key: const PageStorageKey<String>('featured_projects'),
          ),
          // AppBar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _buildAppBar(),
            ),
          ),
          // Logo above Watch button (dynamic from API)
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Center(
              child: _featuredProjects.isNotEmpty
                  ? _buildProjectLogo(_featuredProjects[_currentFeaturedPage])
                  : const SizedBox.shrink(),
            ),
          ),
          // Watch button at bottom
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: _buildWatchButton(),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildProjectLogo(ProjectModel project) {
    // Use logo from API if available, otherwise show nothing
    // Only use network images from API, don't use assets
    if (project.logo == null || project.logo!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Only display if logo is a network URL (from API)
    // Don't use assets - all logos should come from API
    if (project.logo!.startsWith('http') || project.logo!.startsWith('https')) {
      return Image.network(
        project.logo!,
        height: 100,
        width: 200,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: 200,
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // If logo fails to load, don't show anything (no fallback to assets)
          return const SizedBox.shrink();
        },
      );
    }
    
    // If logo is not a network URL, don't display it (don't use assets)
    return const SizedBox.shrink();
  }

  Widget _buildWatchButton() {
    // Use current page project
    final projectToOpen = _featuredProjects.isNotEmpty 
        ? _featuredProjects[_currentFeaturedPage] 
        : null;
    
    return GestureDetector(
      onTap: () async {
        if (projectToOpen != null) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetailsScreen(
                projectId: projectToOpen.id,
                initialTabIndex: 1, // Open on Episodes tab
              ),
            ),
          );
          // Refresh continue watching if episode was watched
          if (result == true) {
            print('🔄 Episode was watched, refreshing continue watching...');
            await _refreshContinueWatching();
            print('✅ Continue watching refreshed after watching episode');
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_filled,
              color: Colors.white.withOpacity(0.9),
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              'Watch',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, ProjectModel project, int index) {
    final gradientColors = project.gradientColors.map((c) {
      final hex = c.replaceAll('0x', '');
      return Color(int.parse(hex, radix: 16));
    }).toList();
    
    // Use hero video (advertisementVideoUrl) for all featured cards in hero section
    // Check if project has video URL and if it's a video file
    final bool hasVideoUrl = project.advertisementVideoUrl.isNotEmpty;
    final bool isVideoFile = hasVideoUrl && (
      project.advertisementVideoUrl.contains('.mp4') || 
      project.advertisementVideoUrl.contains('.mov') ||
      project.advertisementVideoUrl.contains('.webm') ||
      project.hasVideo == true
    );
    
    // Use video player for current card if video is loaded and available
    final bool isCurrentPage = _currentFeaturedPage == index;
    final bool hasVideoLoaded = _videoControllers.containsKey(index) &&
        _chewieControllers.containsKey(index) &&
        _videoControllers[index]!.value.isInitialized;
    
    // During swipe: ONLY show videos (current + neighbor), never images for video projects.
    // Not swiping: show ONLY current page video when loaded.
    final bool isSwipeVisiblePage = _isSwipingFeatured && (index == _swipeFromIndex || index == _swipeToIndex);
    final bool useVideo = isVideoFile && hasVideoLoaded && (isSwipeVisiblePage || (!_isSwipingFeatured && isCurrentPage));
    
    print('🎬 Hero Card $index: hasVideoUrl=$hasVideoUrl, isVideoFile=$isVideoFile, useVideo=$useVideo, currentPage=$_currentFeaturedPage, currentVideoIndex=$_currentVideoIndex, hasVideoLoaded=$hasVideoLoaded, videoUrl=${project.advertisementVideoUrl}');
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background video (for current card with video) - show video when loaded
        if (useVideo && _videoControllers.containsKey(index))
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.65,
                child: VideoPlayer(_videoControllers[index]!),
              ),
            ),
          )
        // If video exists but not loaded yet:
        // - If NOT swiping: show image placeholder (user wants this on initial load)
        // - If swiping: show NOTHING (user wants only videos during swipe)
        else if (!_isSwipingFeatured && isCurrentPage && isVideoFile && !hasVideoLoaded)
          // Video is loading - show image as placeholder
          Positioned.fill(
            child: project.projectThumbnailUrl.isNotEmpty
                ? Image.network(
                    project.projectThumbnailUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
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
                : project.image.isNotEmpty
                    ? Image.network(
                        project.image,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
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
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: gradientColors,
                          ),
                        ),
                      ),
          )
        // Show image if there's NO video file at all (projects without video)
        else if (!isVideoFile && project.projectThumbnailUrl.isNotEmpty)
          Positioned.fill(
            child: Image.network(
              project.projectThumbnailUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
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
            ),
          )
        else if (!isVideoFile && project.image.isNotEmpty)
          Positioned.fill(
            child: Image.network(
              project.image,
              fit: BoxFit.cover,
              alignment: Alignment.center,
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
            ),
          ),
        // Color tint overlay (light at top)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                gradientColors[0].withOpacity(0.3),
                gradientColors[1].withOpacity(0.2),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.5],
            ),
          ),
        ),
        // Dark gradient at bottom - blends into black section below
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.95),
                Colors.black,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 0.85, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Menu icon
          GestureDetector(
            onTap: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Profile avatar
          GestureDetector(
            onTap: () async {
              final isLoggedIn = await _authApi.isLoggedIn();
              if (!isLoggedIn) {
                // If user is not logged in, show login dialog (same as menu items)
                await AuthHelper.requireAuth(context);
                // Refresh user name after returning from login (if user logged in)
                _loadUserName();
              } else {
                // If user is logged in, navigate to account screen
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountScreen(),
                    ),
                  );
                }
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Greeting
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello,',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                _userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Search icon
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () async {
              final isAuth = await AuthHelper.requireAuth(context);
              if (!isAuth) return;
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
          // Bookmark icon
          IconButton(
            icon: const Icon(
              Icons.bookmark_border,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () async {
              final isAuth = await AuthHelper.requireAuth(context);
              if (!isAuth) return;
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: _filters.map((filter) {
            final bool isSelected = _selectedFilter == filter;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                child: Container(
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_featuredProjects.length, (index) {
          final isActive = index == _currentFeaturedPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isActive ? brandRed : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSection(
    String title, {
    VoidCallback? onViewAll,
    required Widget child,
  }) {
    // Hide section completely if child is empty (SizedBox.shrink)
    if (child is SizedBox && (child as SizedBox).width == 0 && (child as SizedBox).height == 0) {
      return const SizedBox.shrink();
    }
    
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
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onViewAll != null)
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

  Widget _buildHorizontalProjectList() {
    if (_latestProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 200,
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
            child: _buildLatestCard(
              project: project,
              gradientColors: gradientColors,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLatestCard({
    required ProjectModel project,
    required List<Color> gradientColors,
  }) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailsScreen(
              projectId: project.id,
              initialTabIndex: 1, // Open on Episodes tab
            ),
          ),
        );
        // Refresh continue watching if episode was watched
        if (result == true) {
          print('🔄 Episode was watched, refreshing continue watching...');
          await _refreshContinueWatching();
          print('✅ Continue watching refreshed after watching episode');
        }
      },
      child: Container(
        width: 160,
        height: 200,
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
              // Background Image - Use projectThumbnailUrl for other sections
              _buildCardImage(
                project: project,
                gradientColors: gradientColors,
                cardType: 'latest',
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
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              // Text content
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.subtitle.isNotEmpty ? project.subtitle : project.location,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueWatchingList() {
    if (_isLoading) {
      return SizedBox(
        height: 110,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: const SkeletonProjectCard(),
            );
          },
        ),
      );
    }
    
    if (_continueWatching.isEmpty) {
      // Return empty container when no videos in progress
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _continueWatching.length,
        itemBuilder: (context, index) {
          final project = _continueWatching[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _continueWatching.length - 1 ? 12 : 0),
            child: _buildContinueWatchingItem(
              project: project,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContinueWatchingItem({
    required ProjectModel project,
  }) {
    final gradientColors = project.gradientColors.map((c) {
      final hex = c.replaceAll('0x', '');
      return Color(int.parse(hex, radix: 16));
    }).toList();
    final progress = project.watchProgress ?? 0.0;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailsScreen(
              projectId: project.id,
            ),
          ),
        );
        // Refresh continue watching if episode was watched
        if (result == true) {
          print('🔄 Episode was watched, refreshing continue watching...');
          await _refreshContinueWatching();
          print('✅ Continue watching refreshed after watching episode');
        }
      },
      child: Container(
        width: 160,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image - Use projectThumbnailUrl for continue watching
              _buildCardImage(
                project: project,
                gradientColors: gradientColors,
                cardType: 'continue',
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
                  ),
                ),
              ),
              // Title
              Center(
                child: Text(
                  project.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
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
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(brandRed),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardImage({
    required ProjectModel project,
    required List<Color> gradientColors,
    required String cardType,
  }) {
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
    
    print('🖼️ [$cardType] Building image for: ${project.title} (id: ${project.id})');
    print('   projectThumbnailUrl: "${project.projectThumbnailUrl}"');
    print('   image: "${project.image}"');
    print('   isAsset: ${project.isAsset}, startsWith assets/: ${project.projectThumbnailUrl.startsWith('assets/')}');
    print('   Using imageAsset: $imageAsset');
    print('   Using imageUrl: $imageUrl');
    
    if (imageAsset != null) {
      return Image.asset(
        imageAsset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('⚠️ Error loading asset image: $imageAsset - $error');
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
          );
        },
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ Image loaded successfully: $imageUrl');
            return child;
          }
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
          print('⚠️ Error loading network image: $imageUrl - $error');
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
          );
        },
      );
    } else {
      print('⚠️ No image URL available, using gradient fallback');
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
      );
    }
  }

  Widget _buildTop10List() {
    if (_top10Projects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final displayProjects = _top10Projects.take(10).toList();

    return SizedBox(
      height: 175,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayProjects.length,
        itemBuilder: (context, index) {
          final project = displayProjects[index];
          final gradientColors = project.gradientColors.map((c) {
            final hex = c.replaceAll('0x', '');
            return Color(int.parse(hex, radix: 16));
          }).toList();
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: RankedProjectCard(
              rank: index + 1,
              title: project.title,
              imageAsset: (project.isAsset && project.projectThumbnailUrl.startsWith('assets/')) 
                  ? (project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image) 
                  : null,
              imageUrl: (project.isAsset && project.projectThumbnailUrl.startsWith('assets/')) 
                  ? null 
                  : (project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image),
              gradientColors: gradientColors,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailsScreen(
                      projectId: project.id,
                    ),
                  ),
                );
                // Refresh continue watching if episode was watched
                if (result == true) {
                  print('🔄 Episode was watched, refreshing continue watching...');
                  await _refreshContinueWatching();
                  print('✅ Continue watching refreshed after watching episode');
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNorthcoastProjects() {
    // Show loading indicator if data is being loaded
    if (_isLoading && _northCoastProjects.isEmpty) {
      return SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: const SkeletonProjectCard(),
            );
          },
        ),
      );
    }
    
    if (_northCoastProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _northCoastProjects.length,
        itemBuilder: (context, index) {
          final project = _northCoastProjects[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _northCoastProjects.length - 1 ? 12 : 0),
            child: _buildLargeProjectCard(
              project: project,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewCairoProjects() {
    // Show loading indicator if data is being loaded
    if (_isLoading && _newCairoProjects.isEmpty) {
      return SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: const SkeletonProjectCard(),
            );
          },
        ),
      );
    }
    
    if (_newCairoProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _newCairoProjects.length,
        itemBuilder: (context, index) {
          final project = _newCairoProjects[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _newCairoProjects.length - 1 ? 12 : 0),
            child: _buildLargeProjectCard(
              project: project,
            ),
          );
        },
      ),
    );
  }

  Widget _buildOctoberProjects() {
    // Show loading indicator if data is being loaded
    if (_isLoading && _octoberProjects.isEmpty) {
      return SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: const SkeletonProjectCard(),
            );
          },
        ),
      );
    }
    
    if (_octoberProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _octoberProjects.length,
        itemBuilder: (context, index) {
          final project = _octoberProjects[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _octoberProjects.length - 1 ? 12 : 0),
            child: _buildLargeProjectCard(
              project: project,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLargeProjectCard({
    required ProjectModel project,
  }) {
    final gradientColors = project.gradientColors.map((c) {
      final hex = c.replaceAll('0x', '');
      return Color(int.parse(hex, radix: 16));
    }).toList();
    
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailsScreen(
              projectId: project.id,
              initialTabIndex: 1, // Open on Episodes tab
            ),
          ),
        );
        // Refresh continue watching if episode was watched
        if (result == true) {
          print('🔄 Episode was watched, refreshing continue watching...');
          await _refreshContinueWatching();
          print('✅ Continue watching refreshed after watching episode');
        }
      },
      child: Container(
        width: 200,
        height: 170,
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
              // Background image - Use projectThumbnailUrl for area projects
              project.isAsset && project.projectThumbnailUrl.startsWith('assets/')
                  ? Image.asset(
                      project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image,
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
                  : Image.network(
                      project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image,
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
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                      ),
                    ),
                  );
                },
              ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              // Content
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.subtitle.isNotEmpty ? project.subtitle : project.location,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingProjectsList() {
    if (_isLoading) {
      return SizedBox(
        height: 240,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: const SkeletonProjectCard(),
            );
          },
        ),
      );
    }
    
    if (_upcomingProjects.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No upcoming projects',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }
    
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _upcomingProjects.length,
        itemBuilder: (context, index) {
          final project = _upcomingProjects[index];
          final gradientColors = project.gradientColors.map((c) {
            final hex = c.replaceAll('0x', '').replaceAll('#', '');
            return Color(int.parse(hex, radix: 16));
          }).toList();
          
          return Padding(
            padding: EdgeInsets.only(right: index < _upcomingProjects.length - 1 ? 12 : 0),
            child: ProjectCard(
              title: project.title,
              subtitle: project.subtitle.isNotEmpty ? project.subtitle : project.location,
              gradientColors: gradientColors,
              imageUrl: (project.isAsset && project.projectThumbnailUrl.startsWith('assets/')) 
                  ? null 
                  : (project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image),
              imageAsset: (project.isAsset && project.projectThumbnailUrl.startsWith('assets/')) 
                  ? (project.projectThumbnailUrl.isNotEmpty ? project.projectThumbnailUrl : project.image)
                  : null,
              // onTap disabled for upcoming projects

            ),
          );
        },
      ),
    );
  }

  Widget _buildUpcomingItem({
    required String title,
    required String subtitle,
    required String imageAsset,
    required List<Color> gradientColors,
    bool hasLogo = false,
  }) {
    // Try to find project by title
    ProjectModel? project;
    if (_upcomingProjects.isNotEmpty) {
      try {
        project = _upcomingProjects.firstWhere(
          (p) => p.title.toLowerCase() == title.toLowerCase(),
        );
      } catch (e) {
        project = _upcomingProjects.first;
      }
    }
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailsScreen(
              projectId: project?.id,
              initialTabIndex: 1, // Open on Episodes tab
            ),
          ),
        );
        // Refresh continue watching if episode was watched
        if (result == true) {
          print('🔄 Episode was watched, refreshing continue watching...');
          await _refreshContinueWatching();
          print('✅ Continue watching refreshed after watching episode');
        }
      },
      child: SizedBox(
        width: 180,
        height: 230,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image from assets - fills entire card
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                      ),
                    ),
                  );
                },
              ),
              // Color gradient overlay on image
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        gradientColors[0].withOpacity(0.6),
                        gradientColors[1].withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Dark gradient at bottom for text
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                        Colors.black.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // Logo in center (for THE ICON)
              if (hasLogo)
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Title and subtitle at bottom
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevelopersList() {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildDeveloperItem(
            name: 'HE',
            subtitle: 'HORIZON',
          ),
          const SizedBox(width: 12),
          _buildDeveloperItem(
            name: 'EGYPTIAN',
            subtitle: 'DEVELOPERS',
            hasIcon: true,
          ),
          const SizedBox(width: 12),
          _buildDeveloperItem(
            name: 'PAL',
            subtitle: '',
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperItem({
    required String name,
    required String subtitle,
    bool hasIcon = false,
  }) {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasIcon)
            const Icon(
              Icons.account_balance,
              color: Color(0xFFB8860B),
              size: 20,
            ),
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF8B7355),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle.isNotEmpty) ...[
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF8B7355),
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAreaChips() {
    final List<String> areas = [
      'Madinaty',
      'Sheraton',
      'New Cairo',
      'North Coast',
      'New Capital',
      'Sidi Abdelrhman',
      'October',
      'Ras Alhekma',
      'Mostakbal City',
      'Maadi',
      '6th Settlement',
    ];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: areas.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final area = areas[index];
          return _buildAreaChip(area, onTap: () => _navigateToAreaProjects(area));
        },
      ),
    );
  }

  void _navigateToAreaProjects(String areaName) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectsListScreen(
            title: 'Projects in $areaName',
            areaName: areaName,
          ),
        ),
      );
    }
  }

  Widget _buildAreaChip(String name, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

}
