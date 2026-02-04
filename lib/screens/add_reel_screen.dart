import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api/project_api.dart';
import '../services/api/auth_api.dart';
import '../services/clip_service.dart';
import '../models/project_model.dart';
import 'dart:io';

class AddReelScreen extends StatefulWidget {
  const AddReelScreen({super.key});

  @override
  State<AddReelScreen> createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _projectApi = Get.find<ProjectApi>();
  final _authApi = AuthApi();
  late final ClipService _clipService;

  bool _whatsAppEnabled = false;
  bool _watchOrientationEnabled = false;
  String? _selectedProjectId;
  File? _selectedVideo;
  File? _selectedThumbnail;
  bool _isLoading = false;
  bool _isLoadingProjects = false;
  double _uploadProgress = 0.0;
  List<ProjectModel> _developerProjects = [];

  static const Color brandRed = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    _clipService = Get.find<ClipService>();
    _loadDeveloperProjects();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDeveloperProjects() async {
    setState(() {
      _isLoadingProjects = true;
    });

    try {
      print('═══════════════════════════════════════════════════════════');
      print('📡 LOADING DEVELOPER PROJECTS - START');
      print('═══════════════════════════════════════════════════════════');

      final userInfo = await _authApi.getStoredUserInfo();
      print('👤 User Info: $userInfo');

      // Try to get developerId from user profile
      String developerId = '';
      try {
        final profile = await _authApi.getUserProfile();
        print('📋 User Profile: $profile');
        developerId = profile['developerId']?.toString() ??
            userInfo['developerId']?.toString() ??
            '';
      } catch (e) {
        print('⚠️ Error getting user profile: $e');
        developerId = userInfo['developerId']?.toString() ?? '';
      }

      print('🔍 DeveloperId to use: "$developerId"');
      print('   (empty = will get all projects from trending)');
      print('');

      final projects = await _projectApi.getDeveloperProjects(developerId);

      print('📦 Projects received: ${projects.length}');
      print('   Project IDs: ${projects.map((p) => p.id).toList()}');
      print('   Project Titles: ${projects.map((p) => p.title).toList()}');
      print('═══════════════════════════════════════════════════════════');
      print('📡 LOADING DEVELOPER PROJECTS - END');
      print('═══════════════════════════════════════════════════════════');
      print('');

      if (mounted) {
        setState(() {
          _developerProjects = projects;
          _isLoadingProjects = false;
        });

        if (projects.isEmpty) {
          print(
              '⚠️ WARNING: No projects loaded! Showing "No projects available"');
        }
      }
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ ERROR LOADING DEVELOPER PROJECTS');
      print('═══════════════════════════════════════════════════════════');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      print('');

      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
        });
        _showSnackBar('Error loading projects: $e');
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedVideo = File(result.files.single.path!);
          // If user changes video, thumbnail might no longer match—reset it.
          _selectedThumbnail = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error picking video: $e');
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedThumbnail = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking thumbnail: $e');
    }
  }

  Future<void> _shareReel() async {
    // Validation
    if (_selectedVideo == null) {
      _showSnackBar('Please select a video', isError: true);
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a title', isError: true);
      return;
    }

    if (_watchOrientationEnabled && _selectedProjectId == null) {
      _showSnackBar('Please select an orientation', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final projectId = _watchOrientationEnabled ? _selectedProjectId : null;
      final newClip = await _clipService.addReel(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        videoPath: _selectedVideo!.path,
        projectId: projectId,
        hasWhatsApp: _whatsAppEnabled,
        thumbnailPath: _selectedThumbnail?.path,
        onUploadProgress: (sent, total) {
          if (mounted) {
            setState(() {
              _uploadProgress = sent / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
        });

        if (newClip != null) {
          _showSnackBar('Reel added successfully!', isSuccess: true);
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pop(context, newClip);
            }
          });
        } else {
          _showSnackBar('Failed to add reel', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
        });
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : isSuccess
                ? Colors.green
                : Colors.grey[800],
        duration: const Duration(seconds: 2),
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
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload area
                    _buildUploadArea(),
                    const SizedBox(height: 12),
                    // Thumbnail upload/select area (below upload box)
                    _buildThumbnailPickerArea(),
                    const SizedBox(height: 24),
                    // Title field
                    _buildTextField(
                      controller: _titleController,
                      hint: 'Title',
                    ),
                    const SizedBox(height: 16),
                    // Description field
                    _buildTextField(
                      controller: _descriptionController,
                      hint: 'Description',
                    ),
                    const SizedBox(height: 24),
                    // Toggle switches
                    _buildToggles(),
                    // Select Orientation dropdown (when Watch Orientation is enabled)
                    if (_watchOrientationEnabled) ...[
                      const SizedBox(height: 16),
                      _buildOrientationDropdown(),
                    ],
                    // Show selected project info
                    if (_watchOrientationEnabled &&
                        _selectedProjectId != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: brandRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selected: ${_developerProjects.firstWhere((p) => p.id == _selectedProjectId, orElse: () => ProjectModel(id: '', title: 'Unknown', image: '')).title}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Upload progress indicator
            if (_isLoading && _uploadProgress > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(brandRed),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Share button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _shareReel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A2A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Share Reel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
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
                'Add Reel',
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

  Widget _buildThumbnailPickerArea() {
    try {
      return GestureDetector(
        onTap: _pickThumbnail,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: brandRed.withOpacity(0.9),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _selectedThumbnail != null
                      ? Image.file(
                          _selectedThumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildThumbnailPlaceholder(),
                        )
                      : _buildThumbnailPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Thumbnail',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedThumbnail != null
                          ? 'Tap to change'
                          : 'Tap to add thumbnail',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.6),
                size: 22,
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Error building thumbnail picker: $e');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: Text(
          'Error: $e',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _pickVideo,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          height: 280,
          width: double.infinity,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _selectedVideo != null
              ? Stack(
                  children: [
                    // Video preview placeholder
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam,
                              color: Colors.white.withOpacity(0.7),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedVideo!.path.split('/').last,
                              style: GoogleFonts.cairo(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Change video button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _pickVideo,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.white.withOpacity(0.7),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add Reel',
                      style: GoogleFonts.cairo(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              color: Colors.white.withOpacity(0.85),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildToggles() {
    return Row(
      children: [
        // WhatsApp toggle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WhatsApp',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Switch(
                value: _whatsAppEnabled,
                onChanged: (value) {
                  setState(() {
                    _whatsAppEnabled = value;
                  });
                },
                activeColor: brandRed,
                activeTrackColor: brandRed.withOpacity(0.5),
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[700],
              ),
            ],
          ),
        ),
        // Watch Orientation toggle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Watch Orientation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Switch(
                value: _watchOrientationEnabled,
                onChanged: (value) {
                  setState(() {
                    _watchOrientationEnabled = value;
                    if (!value) {
                      _selectedProjectId = null;
                    }
                  });
                },
                activeColor: brandRed,
                activeTrackColor: brandRed.withOpacity(0.5),
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[700],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrientationDropdown() {
    // Ensure unique project IDs
    final uniqueProjects = <String, ProjectModel>{};
    for (final project in _developerProjects) {
      if (!uniqueProjects.containsKey(project.id)) {
        uniqueProjects[project.id] = project;
      }
    }
    final projectsList = uniqueProjects.values.toList();

    // Validate selected value exists in the list
    String? validSelectedValue = _selectedProjectId;
    if (validSelectedValue != null &&
        !projectsList.any((p) => p.id == validSelectedValue)) {
      validSelectedValue = null;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validSelectedValue,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select Orientation',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ),
          icon: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          isExpanded: true,
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          items: _isLoadingProjects
              ? [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Loading...'),
                    ),
                  ),
                ]
              : projectsList.isEmpty
                  ? [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('No projects available'),
                        ),
                      ),
                    ]
                  : projectsList.map((ProjectModel project) {
                      return DropdownMenuItem<String>(
                        value: project.id,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(project.title),
                        ),
                      );
                    }).toList(),
          onChanged: _isLoadingProjects || projectsList.isEmpty
              ? null
              : (String? newValue) {
                  setState(() {
                    _selectedProjectId = newValue;
                  });
                },
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE50914)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashWidth = 10.0;
    const dashSpace = 6.0;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        const Radius.circular(12),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
