import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api/project_api.dart';
import '../services/api/auth_api.dart';
import '../models/project_model.dart';

class ChangeInventoryScreen extends StatefulWidget {
  const ChangeInventoryScreen({super.key});

  @override
  State<ChangeInventoryScreen> createState() => _ChangeInventoryScreenState();
}

class _ChangeInventoryScreenState extends State<ChangeInventoryScreen> {

  static const Color brandRed = Color(0xFFE50914);
  static const Color brandGreen = Color(0xFF00C853);

  final _projectApi = ProjectApi();
  final _authApi = AuthApi();
  bool _isLoading = false;
  bool _isLoadingProjects = false;
  List<ProjectModel> _developerProjects = [];
  Map<String, String?> _inventoryUrls = {}; // projectId -> inventoryUrl

  @override
  void initState() {
    super.initState();
    _loadDeveloperProjects();
  }

  Future<void> _loadDeveloperProjects() async {
    setState(() {
      _isLoadingProjects = true;
    });

    try {
      final userInfo = await _authApi.getStoredUserInfo();
      final developerId = userInfo['developerId']?.toString() ?? '';
      final projects = await _projectApi.getDeveloperProjects(developerId);
      
      // Load inventory URLs for each project
      final inventoryUrls = <String, String?>{};
      for (final project in projects) {
        final url = await _projectApi.getInventoryUrl(project.id);
        inventoryUrls[project.id] = url;
      }
      
      if (mounted) {
        setState(() {
          _developerProjects = projects;
          _inventoryUrls = inventoryUrls;
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
        });
        _showSnackBar('Error loading projects: $e');
      }
    }
  }

  Future<void> _pickExcelFile(String projectId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        setState(() { _isLoading = true; });
        try {
          final success = await _projectApi.uploadInventoryFile(projectId, path);
          if (mounted) {
            setState(() { _isLoading = false; });
            if (success) {
              final url = await _projectApi.getInventoryUrl(projectId);
              if (url != null) _inventoryUrls[projectId] = url;
              _showSnackBar('Inventory updated successfully!', isSuccess: true);
              _loadDeveloperProjects();
            } else {
              _showSnackBar('Failed to update inventory', isError: true);
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() { _isLoading = false; });
            _showSnackBar('Error: $e', isError: true);
          }
        }
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
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
            // Results header
            _buildResultsHeader(),
            // List
            Expanded(
              child: _buildInventoryList(),
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
                'Change Inventory',
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'My Orientations',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${_developerProjects.length} Orientations)',
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

  Widget _buildInventoryList() {
    if (_isLoadingProjects) {
      return const Center(
        child: CircularProgressIndicator(
          color: brandRed,
        ),
      );
    }

    if (_developerProjects.isEmpty) {
      return Center(
        child: Text(
          'No projects found',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _developerProjects.length,
      itemBuilder: (context, index) {
        final project = _developerProjects[index];
        final hasExcel = _inventoryUrls[project.id] != null;
        return _InventoryItem(
          developerName: project.developerName,
          projectName: project.title,
          hasExcel: hasExcel,
          onTap: () => _pickExcelFile(project.id),
          isLoading: _isLoading,
        );
      },
    );
  }
}

class _InventoryItem extends StatelessWidget {
  final String developerName;
  final String projectName;
  final bool hasExcel;
  final VoidCallback onTap;
  final bool isLoading;

  const _InventoryItem({
    required this.developerName,
    required this.projectName,
    required this.hasExcel,
    required this.onTap,
    this.isLoading = false,
  });

  static const Color brandGreen = Color(0xFF00C853);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/change_inventory/masaya_thumbnail.png',
              width: 100,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  developerName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  projectName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                // Action button
                GestureDetector(
                  onTap: isLoading ? null : onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isLoading ? Colors.grey[700] : brandGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            hasExcel ? 'Change Excel Sheet' : 'Add Excel Sheet',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

