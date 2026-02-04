import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'clips_screen.dart';
import 'projects_list_screen.dart';
import 'episode_player_screen.dart';
import '../reels/reels_screen.dart';
import '../models/project_model.dart';
import '../models/episode_model.dart';
import '../models/clip_model.dart';
import '../models/pdf_file_model.dart';
import '../services/api/project_api.dart';
import '../services/api/auth_api.dart';
import '../services/clip_service.dart';
import '../services/cache_service.dart';
import '../utils/auth_helper.dart';
import '../widgets/skeleton_loader.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final String? projectId;
  final int initialTabIndex;

  const ProjectDetailsScreen({
    super.key,
    this.projectId,
    this.initialTabIndex =
        0, // 0: Project, 1: Episodes, 2: Inventory, 3: Reels, 4: PDF
  });

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final ProjectApi _projectApi = Get.find<ProjectApi>();
  late final ClipService _clipService;
  final AuthApi _authApi = AuthApi();
  final CacheService _cacheService = CacheService();

  static const Color brandRed = Color(0xFFE50914);
  static const Color brandGreen = Color(0xFF00C853);

  ProjectModel? _project;
  List<EpisodeModel> _episodes = [];
  List<ClipModel> _clips = [];
  List<PdfFileModel> _pdfFiles = [];
  List<ProjectModel> _relatedProjects = [];
  String? _inventoryUrl; // from /files/get/inventory, not on project
  bool _isLoading = true;
  bool _isSaved = false;
  bool _isScriptExpanded = false;
  VideoPlayerController? _adVideoController;
  bool _isVideoMuted = true; // Start muted by default
  bool _isAdVideoVisible = true; // Track ad video visibility for pause/resume
  String _userRole = 'user';
  String _userDeveloperId = '';
  bool _canEditScript = false;

  @override
  void initState() {
    super.initState();
    _clipService = Get.find<ClipService>();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(
      length: 5, // Project, Episodes, Inventory, Reels, MB
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadUserInfo();
    _loadProjectData();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userInfo = await _authApi.getStoredUserInfo();
      final role = userInfo['role'] ?? 'user';

      print('👤 Loading user info:');
      print('   Role: $role');
      print('   User info keys: ${userInfo.keys.toList()}');
      print('   Full user info: $userInfo');

      if (mounted) {
        setState(() {
          _userRole = role;
        });
        print('   ✅ _userRole set to: $_userRole');
        print(
            '   ✅ Can show edit button: ${_userRole.toLowerCase() == 'developer' || _userRole.toLowerCase() == 'admin'}');
      }
    } catch (e) {
      print('⚠️ Error loading user info: $e');
      if (mounted) {
        setState(() {
          _userRole = 'user';
        });
      }
    }
  }

  Future<void> _checkCanEditScript() async {
    print('🔍 _checkCanEditScript called');
    print('   Project: ${_project?.id ?? "null"}');
    print('   User role: $_userRole');

    if (_project == null) {
      print('   ❌ No project, setting _canEditScript = false');
      setState(() {
        _canEditScript = false;
      });
      return;
    }

    // Check if user is developer or admin
    final isDeveloper = _userRole.toLowerCase() == 'developer' ||
        _userRole.toLowerCase() == 'admin';
    print('   Is developer/admin: $isDeveloper');

    if (!isDeveloper) {
      print('   ❌ User is not developer/admin, setting _canEditScript = false');
      setState(() {
        _canEditScript = false;
      });
      return;
    }

    // Admins can edit any project
    if (_userRole.toLowerCase() == 'admin') {
      print('   ✅ User is admin, setting _canEditScript = true');
      setState(() {
        _canEditScript = true;
      });
      return;
    }

    // For developers: Check if project belongs to current developer
    // Use /developer/me/projects to get developer's projects
    print('   🔍 Checking developer projects...');
    try {
      final developerProjects = await _projectApi.getDeveloperProjects('');
      final ownsProject = developerProjects.any((p) => p.id == _project!.id);

      print('   ✅ Developer projects check:');
      print('      Project ID: ${_project!.id}');
      print('      Developer projects count: ${developerProjects.length}');
      print(
          '      Developer project IDs: ${developerProjects.map((p) => p.id).toList()}');
      print('      Owns project: $ownsProject');

      setState(() {
        _canEditScript = ownsProject;
      });

      print('   ✅ Final _canEditScript: $_canEditScript');
    } catch (e) {
      print('   ⚠️ Error checking developer projects: $e');
      // Fallback: Try to match developerId if available
      try {
        final userInfo = await _authApi.getStoredUserInfo();
        final profile = await _authApi.getUserProfile();
        final developerId = profile['developerId']?.toString() ??
            userInfo['developerId']?.toString() ??
            '';

        print('   🔍 Fallback: Checking developerId match');
        print('      Project developerId: ${_project!.developerId}');
        print('      User developerId: $developerId');

        final ownsProject = _project!.developerId.isNotEmpty &&
            developerId.isNotEmpty &&
            _project!.developerId == developerId;

        setState(() {
          _canEditScript = ownsProject;
        });

        print('   ✅ Fallback check result: $ownsProject');
        print('   ✅ Final _canEditScript: $_canEditScript');
      } catch (e2) {
        print('   ❌ Error in fallback check: $e2');
        setState(() {
          _canEditScript = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop and dispose video before disposing
    if (_adVideoController != null) {
      _adVideoController!.removeListener(_onAdVideoStateChanged);
      _adVideoController!.pause();
      _adVideoController!.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if screen is active and video needs to be reinitialized
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
    if (isCurrentRoute &&
        _project != null &&
        (_adVideoController == null ||
            !_adVideoController!.value.isInitialized)) {
      // Screen is active but video is not initialized, reload it
      _initializeAdVideo();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _adVideoController?.pause();
    } else if (state == AppLifecycleState.resumed) {
      // When app resumes, restart video if it was initialized
      if (_adVideoController != null &&
          _adVideoController!.value.isInitialized) {
        // Restore volume state when resuming
        _adVideoController!.setVolume(_isVideoMuted ? 0.0 : 1.0);
        _adVideoController!.play();
      } else if (_project != null) {
        // Reinitialize video if needed
        _initializeAdVideo();
      }
    }
  }

  Future<void> _loadProjectData() async {
    if (widget.projectId == null) {
      _adVideoController?.pause();
      setState(() {
        _project = null;
        _episodes = [];
        _clips = [];
        _pdfFiles = [];
        _relatedProjects = [];
        _inventoryUrl = null;
        _isLoading = false;
      });
      _checkIfSaved();
      _initializeAdVideo();
      return;
    }

    try {
      // 1. Fetch main project data
      final project = await _projectApi.getProjectById(widget.projectId!);

      // 2. Fetch all other data sequentially
      final episodes = await _projectApi.getEpisodes(widget.projectId!);
      final clips = await _clipService.getProjectClips(widget.projectId!);
      final pdfFiles = await _projectApi.getPdfFiles(widget.projectId!);
      final isSaved = await _projectApi.isProjectSaved(widget.projectId!);
      final inventoryUrl = await _projectApi.getInventoryUrl(widget.projectId!);

      // 3. Handle Developer Projects separately
      List<ProjectModel> relatedProjects = [];
      if (project != null && project.developerId.isNotEmpty) {
        try {
          final devProjects =
              await _projectApi.getDeveloperProjects(project.developerId);
          for (final devProject in devProjects) {
            if (devProject.id != project.id &&
                !relatedProjects.any((p) => p.id == devProject.id)) {
              relatedProjects.add(devProject);
              if (relatedProjects.length >= 3) break;
            }
          }
        } catch (e) {
          print('⚠️ Error loading developer projects: $e');
          relatedProjects = [];
        }
      }

      _adVideoController?.pause();

      if (mounted) {
        setState(() {
          _project = project;
          _episodes = episodes;
          _clips = clips;
          _pdfFiles = pdfFiles;
          _relatedProjects = relatedProjects;
          _inventoryUrl = inventoryUrl;
          _isSaved = isSaved;
          _isLoading = false;
        });
        await _checkCanEditScript();
        _initializeAdVideo();

        if (project != null && project.image.isNotEmpty) {
          _cacheService.cacheProjectHeroImage(project.id, project.image);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeAdVideo() async {
    if (_project == null) return;

    // Stop and dispose previous controller if exists
    if (_adVideoController != null) {
      _adVideoController!.removeListener(_onAdVideoStateChanged);
      _adVideoController!.pause();
      await _adVideoController!.dispose();
    }

    // Backend determines if project has video or image
    // If hasVideo is false or null, show image instead
    if (_project!.hasVideo == false) {
      if (mounted) {
        setState(() {
          _adVideoController = null;
        });
      }
      return;
    }

    // Get advertisement video URL from project model
    String videoUrl = _project!.advertisementVideoUrl;

    // If advertisementVideoUrl is empty, don't load video - show image instead
    if (videoUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _adVideoController = null;
        });
      }
      return;
    }

    try {
      debugPrint('Initializing video with URL: $videoUrl');

      // Check if it's a network URL or asset path
      if (videoUrl.startsWith('http') || videoUrl.startsWith('https')) {
        _adVideoController =
            VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      } else {
        // Asset video
        _adVideoController = VideoPlayerController.asset(videoUrl);
      }

      // Add listener to update UI and handle video state changes
      _adVideoController!.addListener(_onAdVideoStateChanged);

      await _adVideoController!.initialize();

      if (!mounted) {
        _adVideoController!.removeListener(_onAdVideoStateChanged);
        await _adVideoController!.dispose();
        _adVideoController = null;
        return;
      }

      _adVideoController!.setLooping(true);
      _adVideoController!.setVolume(_isVideoMuted ? 0.0 : 1.0);
      await _adVideoController!.play();

      debugPrint(
          'Video initialized and playing: ${_adVideoController!.value.isInitialized}');

      setState(() {});
    } catch (e) {
      debugPrint('Error initializing advertisement video: $e');
      // If video fails, set controller to null to show image instead
      if (mounted) {
        setState(() {
          _adVideoController = null;
        });
      }
    }
  }

  void _onAdVideoStateChanged() {
    if (!mounted || _adVideoController == null) return;

    final controller = _adVideoController!;

    // Update UI when video state changes
    if (controller.value.isInitialized) {
      setState(() {});

      // Check if video ended and restart if looping is enabled
      final duration = controller.value.duration;
      final position = controller.value.position;

      if (duration.inMilliseconds > 0) {
        // Check if video reached the end (within 100ms tolerance)
        final timeRemaining = duration.inMilliseconds - position.inMilliseconds;
        if (timeRemaining <= 100 && timeRemaining >= 0) {
          // Video ended - restart it
          if (_isAdVideoVisible && !controller.value.isPlaying) {
            Future.microtask(() {
              if (mounted &&
                  _adVideoController != null &&
                  _adVideoController!.value.isInitialized) {
                _adVideoController!.seekTo(Duration.zero);
                _adVideoController!.play();
                debugPrint('🔄 Ad video ended, restarting...');
              }
            });
          }
        }
      }

      // If video stopped playing unexpectedly (not paused by user and not buffering), restart it
      if (!controller.value.isPlaying &&
          !controller.value.isBuffering &&
          _isAdVideoVisible &&
          duration.inMilliseconds > 0 &&
          position.inMilliseconds < (duration.inMilliseconds - 100)) {
        // Video stopped unexpectedly - restart it after a short delay
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted &&
              _adVideoController != null &&
              _adVideoController!.value.isInitialized &&
              !_adVideoController!.value.isPlaying &&
              _isAdVideoVisible) {
            _adVideoController!.play();
            debugPrint('▶️ Ad video stopped unexpectedly, restarting...');
          }
        });
      }
    }
  }

  void _toggleVideoMute() {
    if (_adVideoController != null && _adVideoController!.value.isInitialized) {
      setState(() {
        _isVideoMuted = !_isVideoMuted;
      });
      // Set volume after state update to ensure it's applied correctly
      _adVideoController!.setVolume(_isVideoMuted ? 0.0 : 1.0);
      print(
          '🔊 Volume changed: ${_isVideoMuted ? "Muted" : "Unmuted"} (${_isVideoMuted ? 0.0 : 1.0})');
    }
  }

  void _toggleVideoPlayPause() {
    if (_adVideoController != null && _adVideoController!.value.isInitialized) {
      setState(() {
        if (_adVideoController!.value.isPlaying) {
          _adVideoController!.pause();
        } else {
          _adVideoController!.play();
        }
      });
    }
  }

  void _openVideoFullscreen() {
    if (_adVideoController != null && _adVideoController!.value.isInitialized) {
      // Create a fullscreen dialog with the video
      showDialog(
        context: context,
        barrierColor: Colors.black,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Fullscreen video
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _adVideoController!.value.size.width,
                    height: _adVideoController!.value.size.height,
                    child: VideoPlayer(_adVideoController!),
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _checkIfSaved() async {
    if (_project == null) return;
    final isSaved = await _projectApi.isProjectSaved(_project!.id);
    if (mounted) {
      setState(() {
        _isSaved = isSaved;
      });
    }
  }

  Future<void> _toggleSave() async {
    if (_project == null) return;

    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !_isSaved;
    });

    try {
      if (_isSaved) {
        await _projectApi.saveProject(_project!.id);
        _showSnackBar('Saved! ❤️', isError: false);
      } else {
        await _projectApi.unsaveProject(_project!.id);
        _showSnackBar('Removed from saved', isError: false);
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isSaved = wasSaved;
      });
      _showSnackBar('Error saving project', isError: true);
    }
  }

  Future<void> _openWhatsApp() async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    if (_project == null ||
        _project!.whatsappNumber.isEmpty ||
        _project!.whatsappNumber.trim().isEmpty) {
      _showSnackBar('WhatsApp number not available', isError: true);
      return;
    }

    // Clean phone number - remove spaces, dashes, and + sign
    String phone = _project!.whatsappNumber
        .replaceAll('+', '')
        .replaceAll(' ', '')
        .replaceAll('-', '');

    final message = 'مهتم بمشروع ${_project!.title}';
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';

    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open WhatsApp', isError: true);
    }
  }

  Future<void> _openLocation() async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    if (_project == null || _project!.locationUrl.isEmpty) {
      _showSnackBar('Location not available', isError: true);
      return;
    }

    try {
      final uri = Uri.parse(_project!.locationUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open location', isError: true);
    }
  }

  Future<void> _copyScript() async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    if (_project == null || _project!.script.isEmpty) {
      _showSnackBar('Script not available', isError: true);
      return;
    }

    await Clipboard.setData(ClipboardData(text: _project!.script));
    _showSnackBar('Copied! ✓', isError: false);
  }

  void _showEditScriptDialog() {
    if (_project == null) return;

    final TextEditingController scriptController =
        TextEditingController(text: _project!.script);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Script',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Text field
              Expanded(
                child: TextField(
                  controller: scriptController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'write your script',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final newScript = scriptController.text.trim();
                      Navigator.pop(context);
                      await _saveScript(newScript);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveScript(String newScript) async {
    if (_project == null) return;

    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    // Check if user is developer or admin
    final userInfo = await _authApi.getStoredUserInfo();
    final role = userInfo['role'] ?? 'user';

    if (role.toLowerCase() != 'developer' && role.toLowerCase() != 'admin') {
      _showSnackBar('You do not have permission to edit this script',
          isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success =
          await _projectApi.updateProjectScript(_project!.id, newScript);

      if (success) {
        // Update local project model
        setState(() {
          _project = _project!.copyWith(script: newScript);
          _isLoading = false;
        });
        _showSnackBar('Script updated successfully! ✓', isError: false);
      } else {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Failed to update script. You may not own this project.',
            isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error updating script: $e', isError: true);
    }
  }

  Future<void> _shareProject() async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    if (_project == null) {
      _showSnackBar('Nothing to share', isError: true);
      return;
    }

    final shareText = '''
🏠 ${_project!.title}
📍 ${_project!.location.isNotEmpty ? _project!.location : _project!.area}
🏗️ ${_project!.developerName}

${_project!.script.isNotEmpty ? _project!.script : _project!.description}

📞 WhatsApp: ${_project!.whatsappNumber}
📍 Location: ${_project!.locationUrl}
''';

    try {
      await Share.share(shareText, subject: _project!.title);
    } catch (e) {
      _showSnackBar('Error sharing', isError: true);
    }
  }

  Future<void> _openInventory() async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    final url = _inventoryUrl;
    if (url == null || url.isEmpty) {
      _showSnackBar('Inventory not available', isError: true);
      return;
    }

    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnackBar('Could not open inventory', isError: true);
      }
    } catch (e) {
      debugPrint('Error opening inventory: $e');
      _showSnackBar('Error opening inventory', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
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

  void _showScriptBottomSheet(String script) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Script',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _copyScript();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: brandRed,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.copy, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Script content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(
                  script,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ProjectDetailsLoadingPlaceholder();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Hero section
          _buildHeroSection(),
          // Content section
          Expanded(
            child: _buildContentSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final projectTitle = _project?.title ?? 'Project';
    final projectArea = _project?.area ?? _project?.location ?? '';
    final projectImage = _project?.image ?? '';
    final isAsset = _project?.isAsset ?? false;

    return VisibilityDetector(
      key: const Key('project_details_ad_video'),
      onVisibilityChanged: (info) {
        final isVisible = info.visibleFraction >= 0.5;
        if (isVisible != _isAdVideoVisible) {
          _isAdVideoVisible = isVisible;
          if (_adVideoController != null &&
              _adVideoController!.value.isInitialized) {
            if (isVisible) {
              // Resume video from current position
              _adVideoController!.play();
            } else {
              // Pause video (position is preserved automatically)
              _adVideoController!.pause();
            }
          }
        }
      },
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            // Background video with tap detector
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleVideoPlayPause,
                child: _adVideoController != null &&
                        _adVideoController!.value.isInitialized
                    ? SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _adVideoController!.value.size.width,
                            height: _adVideoController!.value.size.height,
                            child: VideoPlayer(_adVideoController!),
                          ),
                        ),
                      )
                    : (projectImage.isNotEmpty
                        ? (isAsset
                            ? Image.asset(
                                projectImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildGradientBackground(),
                              )
                            : Image.network(
                                projectImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildGradientBackground(),
                              ))
                        : _buildGradientBackground()),
              ),
            ),
            // Dark overlay gradient - darker towards bottom to blend with black section
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.9),
                        Colors
                            .black, // Fully black at bottom to blend with section below
                      ],
                      stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Red line at bottom - very subtle and thin
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: brandRed.withOpacity(0.3),
              ),
            ),
            // Status bar area with time and icons
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '0:12',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.signal_cellular_alt,
                          color: Colors.white.withOpacity(0.8), size: 14),
                      const SizedBox(width: 4),
                      Icon(Icons.wifi,
                          color: Colors.white.withOpacity(0.8), size: 14),
                      const SizedBox(width: 4),
                      Icon(Icons.battery_full,
                          color: Colors.white.withOpacity(0.8), size: 14),
                    ],
                  ),
                ],
              ),
            ),
            // Back button
            Positioned(
              top: 60,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            // Mute/Unmute button - bottom right with nice styling
            if (_adVideoController != null &&
                _adVideoController!.value.isInitialized)
              Positioned(
                bottom: 30,
                right: 16,
                child: GestureDetector(
                  onTap: _toggleVideoMute,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _isVideoMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white.withOpacity(0.9),
                      size: 18,
                    ),
                  ),
                ),
              ),
            // Project info overlay (minimal text)
            Positioned(
              top: 70,
              left: 60,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    projectArea.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _project?.developerName.toUpperCase() ??
                        'FULLY FINISHED UNITS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5a8a9a),
            Color(0xFF3a6a7a),
            Color(0xFF2a5a6a),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    final projectTitle = _project?.title ?? 'Project';
    final projectLocation = _project?.location ?? _project?.area ?? '';
    final projectScript = _project?.script ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Title and actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        projectLocation,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                GestureDetector(
                  onTap: _toggleSave,
                  child: _buildSaveButton(),
                ),
                if (_project != null &&
                    _project!.whatsappNumber.isNotEmpty &&
                    _project!.whatsappNumber.trim().isNotEmpty)
                  GestureDetector(
                    onTap: _openWhatsApp,
                    child: _buildImageActionButton(
                        'assets/icons_clips/whatsapp.png',
                        iconSize: 56),
                  ),
                GestureDetector(
                  onTap: _shareProject,
                  child: _buildImageActionButton('assets/icons_clips/share.png',
                      iconSize: 56),
                ),
                if (_project != null && _project!.locationUrl.isNotEmpty)
                  GestureDetector(
                    onTap: _openLocation,
                    child: _buildActionButton(Icons.location_on_outlined),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Script section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Script :',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            projectScript.isEmpty
                                ? 'No script available'
                                : (projectScript.length > 100
                                    ? '${projectScript.substring(0, 100)}...'
                                    : projectScript),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (projectScript.length > 100) ...[
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () =>
                                  _showScriptBottomSheet(projectScript),
                              child: const Text(
                                'See more',
                                style: TextStyle(
                                  color: brandRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _copyScript,
                      child: Icon(
                        Icons.copy_outlined,
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                    // Show edit button if user is developer or admin
                    if (_userRole.toLowerCase() == 'developer' ||
                        _userRole.toLowerCase() == 'admin') ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showEditScriptDialog,
                        child: Icon(
                          Icons.edit_outlined,
                          color: brandRed,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tabs - no border
          TabBar(
            controller: _tabController,
            indicatorColor: brandRed,
            indicatorWeight: 3,
            labelColor: brandRed,
            unselectedLabelColor: Colors.white.withOpacity(0.5),
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Project'),
              Tab(text: 'Episodes'),
              Tab(text: 'Inventory'),
              Tab(text: 'Reels'),
              Tab(text: 'PDF'),
            ],
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProjectTab(),
                _buildEpisodesTab(),
                _buildInventoryTab(),
                _buildReelsTab(),
                _buildMbTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1A1A1A),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1A1A1A),
      ),
      child: Center(
        child: _isSaved
            ? const Icon(
                Icons.favorite,
                color: brandRed,
                size: 28,
              )
            : Image.asset(
                'assets/icons_clips/save.png',
                width: 56,
                height: 56,
              ),
      ),
    );
  }

  Widget _buildImageActionButton(String imagePath, {double iconSize = 40}) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1A1A1A),
      ),
      child: Center(
        child: Image.asset(
          imagePath,
          width: iconSize,
          height: iconSize,
        ),
      ),
    );
  }

  Widget _buildInventoryTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _openInventory,
          style: ElevatedButton.styleFrom(
            backgroundColor: brandGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view, size: 18),
              SizedBox(width: 8),
              Text(
                'Open Excel Sheet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodesTab() {
    if (_episodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              color: Colors.white.withOpacity(0.3),
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'No episodes available',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _episodes.length,
      itemBuilder: (context, index) {
        final episode = _episodes[index];
        return _EpisodeItem(
          episodeNumber: episode.episodeNumber,
          duration: episode.duration,
          title: episode.title,
          thumbnail: episode.thumbnail,
          isAsset: episode.isAsset,
          onTap: () async {
            final isAuth = await AuthHelper.requireAuth(context);
            if (!isAuth) return;

            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EpisodePlayerScreen(
                  episode: episode,
                  projectTitle: _project?.title ?? '',
                ),
              ),
            );
            // Progress should be saved automatically when EpisodePlayerScreen disposes
            print('✅ Returned from Episode Player - progress should be saved');
            // Return true to indicate that watch progress was updated
            if (mounted && result == true) {
              Navigator.pop(context, true); // Pass result to parent screen
            }
          },
        );
      },
    );
  }

  Widget _buildProjectTab() {
    if (_relatedProjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business_outlined,
                color: Colors.white.withOpacity(0.3),
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                'No Related Projects',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _relatedProjects.length,
      itemBuilder: (context, index) {
        final project = _relatedProjects[index];
        return _ProjectItem(
          projectName: project.title,
          location:
              project.location.isNotEmpty ? project.location : project.area,
          projectId: project.id,
          onTap: () async {
            // Pause current video (but don't dispose) before opening new project
            // This allows video to resume when returning to this screen
            if (_adVideoController != null &&
                _adVideoController!.value.isInitialized) {
              _adVideoController!.setVolume(0.0);
              await _adVideoController!.pause();
            }
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailsScreen(
                    projectId: project.id,
                  ),
                ),
              ).then((_) {
                // When returning from new project, resume video if needed
                if (mounted &&
                    _adVideoController != null &&
                    _adVideoController!.value.isInitialized) {
                  _adVideoController!.setVolume(_isVideoMuted ? 0.0 : 1.0);
                  _adVideoController!.play();
                } else if (mounted && _project != null) {
                  // Reinitialize video if it was disposed
                  _initializeAdVideo();
                }
              });
            }
          },
        );
      },
    );
  }

  Widget _buildReelsTab() {
    if (_clips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                color: Colors.white.withOpacity(0.3),
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                'No Reels Available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Reels for this project will appear here',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _clips.length,
      itemBuilder: (context, index) {
        final clip = _clips[index];
        return _ClipItem(
          clip: clip,
          onTap: () async {
            final isAuth = await AuthHelper.requireAuth(context);
            if (!isAuth) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReelsScreen(
                  clips: _clips,
                  initialIndex: index,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMbTab() {
    if (_pdfFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                color: Colors.white.withOpacity(0.3),
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                'No PDF Files Available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'PDF files for this project will appear here',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pdfFiles.length,
      itemBuilder: (context, index) {
        final pdfFile = _pdfFiles[index];
        return _PdfFileItem(
          pdfFile: pdfFile,
          onDownload: () => _downloadPdf(pdfFile),
        );
      },
    );
  }

  Future<void> _downloadPdf(PdfFileModel pdfFile) async {
    final isAuth = await AuthHelper.requireAuth(context);
    if (!isAuth) return;

    try {
      // Open PDF in browser or download
      final uri = Uri.parse(pdfFile.fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnackBar('Opening PDF...', isError: false);
      } else {
        _showSnackBar('Could not open PDF', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error opening PDF: $e', isError: true);
    }
  }
}

class _PdfFileItem extends StatelessWidget {
  final PdfFileModel pdfFile;
  final VoidCallback onDownload;

  const _PdfFileItem({
    required this.pdfFile,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDownload,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // PDF Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFE50914).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.picture_as_pdf,
                color: Color(0xFFE50914),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pdfFile.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (pdfFile.description != null &&
                      pdfFile.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pdfFile.description!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: Colors.white.withOpacity(0.4),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          pdfFile.fileName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pdfFile.formattedFileSize,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Download button
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE50914).withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.download,
                color: Color(0xFFE50914),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClipItem extends StatelessWidget {
  final ClipModel clip;
  final VoidCallback? onTap;

  const _ClipItem({
    required this.clip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade800,
                          Colors.grey.shade900,
                        ],
                      ),
                    ),
                    child: clip.thumbnail.isNotEmpty
                        ? (clip.isAsset
                            ? Image.asset(
                                clip.thumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildPlaceholder(),
                              )
                            : Image.network(
                                clip.thumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildPlaceholder(),
                              ))
                        : _buildPlaceholder(),
                  ),
                  // Play icon overlay
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clip.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clip.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.white.withOpacity(0.4),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${clip.likes}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          clip.developerName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(
        Icons.video_library,
        color: Colors.white54,
        size: 30,
      ),
    );
  }
}

class _EpisodeItem extends StatelessWidget {
  final int episodeNumber;
  final String duration;
  final String title;
  final String thumbnail;
  final bool isAsset;
  final VoidCallback? onTap;

  const _EpisodeItem({
    required this.episodeNumber,
    required this.duration,
    this.title = '',
    this.thumbnail = '',
    this.isAsset = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 90,
              height: 65,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFD4A574),
                    Color(0xFFC49A6C),
                    Color(0xFFB8906A),
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbnail.isNotEmpty
                    ? (isAsset
                        ? Image.asset(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          ))
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isNotEmpty ? title : 'Episode $episodeNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    duration,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Play button
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        'EP $episodeNumber',
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ProjectItem extends StatelessWidget {
  final String projectName;
  final String location;
  final String projectId;
  final VoidCallback onTap;

  const _ProjectItem({
    required this.projectName,
    required this.location,
    required this.projectId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 90,
              height: 65,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5a8a9a),
                    Color(0xFF3a6a7a),
                    Color(0xFF2a5a6a),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.business,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    projectName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow button
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectDetailsLoadingPlaceholder extends StatelessWidget {
  const ProjectDetailsLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE50914),
        ),
      ),
    );
  }
}
