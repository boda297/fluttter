import 'package:dio/dio.dart';
import '../dio_client.dart';
import '../../models/project_model.dart';
import '../../models/developer_model.dart';
import '../../models/area_model.dart';
import '../../utils/cache_manager.dart';
import 'project_api.dart';

class HomeApi {
  final DioClient _dioClient = DioClient();
  final ProjectApi _projectApi = ProjectApi();

  HomeApi() {
    _dioClient.init();
  }

  /// GET /projects/featured?limit= (with caching)
  Future<List<ProjectModel>> getFeaturedProjects({bool useCache = true}) async {
    const cacheKey = 'featured_projects';
    
    // Try to get from cache first
    if (useCache) {
      final cached = await CacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        final projects = cached.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
        print('📦 Cached featured projects: ${projects.length}');
        return projects;
      }
    }
    
    try {
      // Use the correct endpoint: GET /projects/featured?limit=
      print('📡 Calling GET /projects/featured?limit=50...');
      final response = await _dioClient.dio.get('/projects/featured', queryParameters: {'limit': '50'});
      print('📡 Response status: ${response.statusCode}');
      print('📡 Response data type: ${response.data.runtimeType}');
      
      final list = response.data is List ? response.data as List : <dynamic>[];
      print('📡 Parsed list length: ${list.length}');
      
      if (list.isEmpty) {
        print('⚠️ Empty list returned from API');
        return [];
      }
      
      final projects = <ProjectModel>[];
      for (var i = 0; i < list.length; i++) {
        try {
          final item = list[i] as Map<String, dynamic>;
          final project = ProjectModel.fromJson(item);
          projects.add(project);
        } catch (e) {
          print('⚠️ Error parsing project at index $i: $e');
          print('   Data: ${list[i]}');
        }
      }
      
      print('✅ Got ${projects.length} featured projects from API (parsed ${projects.length}/${list.length})');
      
      // Cache the results (increased duration to reduce API calls)
      if (useCache && list.isNotEmpty) {
        await CacheManager.set(cacheKey, list, duration: const Duration(minutes: 30));
        print('💾 Cached ${list.length} featured projects');
      }
      
      return projects;
    } on DioException catch (e) {
      print('❌ DioException getting featured projects: ${e.message}');
      print('   Type: ${e.type}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}');
        print('   Data: ${e.response?.data}');
      }
      return [];
    } catch (e, stackTrace) {
      print('❌ Unexpected error getting featured projects: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// GET /projects/latest?limit= (with caching)
  Future<List<ProjectModel>> getLatestProjects({bool useCache = true}) async {
    const cacheKey = 'latest_projects';
    
    // Try to get from cache first
    if (useCache) {
      final cached = await CacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    
    try {
      // Use correct endpoint: GET /projects/latest?limit=
      print('📡 Calling GET /projects/latest?limit=10...');
      final response = await _dioClient.dio.get('/projects/latest', queryParameters: {'limit': '10'});
      print('📡 Response status: ${response.statusCode}');
      
      final list = response.data is List ? response.data as List : <dynamic>[];
      print('📡 Parsed list length: ${list.length}');
      
      if (list.isEmpty) {
        print('⚠️ Empty list returned from API');
        return [];
      }
      
      final projects = <ProjectModel>[];
      for (var i = 0; i < list.length; i++) {
        try {
          final item = list[i] as Map<String, dynamic>;
          // Debug: Print image fields from API
          if (i < 3) { // Print first 3 projects for debugging
            print('📸 Project $i image fields:');
            print('   projectThumbnailUrl: ${item['projectThumbnailUrl']}');
            print('   image: ${item['image']}');
            print('   logo: ${item['logo']}');
            print('   logoUrl: ${item['logoUrl']}');
          }
          final project = ProjectModel.fromJson(item);
          // Debug: Print parsed values
          if (i < 3) {
            print('📸 Project $i parsed values:');
            print('   projectThumbnailUrl: "${project.projectThumbnailUrl}"');
            print('   image: "${project.image}"');
            print('   logo: "${project.logo}"');
          }
          projects.add(project);
        } catch (e) {
          print('⚠️ Error parsing project at index $i: $e');
        }
      }
      
      print('✅ Got ${projects.length} latest projects from API (parsed ${projects.length}/${list.length})');
      
      // Cache the results (increased duration to reduce API calls)
      if (useCache && list.isNotEmpty) {
        await CacheManager.set(cacheKey, list, duration: const Duration(minutes: 30));
      }
      
      return projects;
    } on DioException catch (e) {
      print('❌ DioException getting latest projects: ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}, Data: ${e.response?.data}');
      }
      return [];
    } catch (e, stackTrace) {
      print('❌ Unexpected error getting latest projects: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Uses ProjectApi.getContinueWatchingProjects (backend watch-history + local fallback)
  Future<List<ProjectModel>> getContinueWatching() async {
    try {
      print('🏠 HomeApi: Fetching continue watching...');
      final projects = await _projectApi.getContinueWatchingProjects();
      print('🏠 HomeApi: Got ${projects.length} continue watching projects');
      return projects;
    } catch (e) {
      print('❌ HomeApi: Error in getContinueWatching: $e');
      return [];
    }
  }

  /// GET /projects/trending?limit=10 (with caching)
  Future<List<ProjectModel>> getTop10Projects({bool useCache = true}) async {
    const cacheKey = 'top10_projects';
    
    // Try to get from cache first
    if (useCache) {
      final cached = await CacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    
    try {
      final response = await _dioClient.dio.get('/projects/trending', queryParameters: {'limit': '10'});
      final list = response.data is List ? response.data as List : <dynamic>[];
      final projects = list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      
      // Cache the results (increased duration to reduce API calls)
      if (useCache && list.isNotEmpty) {
        await CacheManager.set(cacheKey, list, duration: const Duration(minutes: 30));
      }
      
      return projects;
    } on DioException catch (e) {
      print('❌ Error getting top 10: ${e.message}');
      return [];
    }
  }

  /// GET /projects/location?location= (with caching)
  Future<List<ProjectModel>> getProjectsByArea(String area, {bool useCache = true}) async {
    final cacheKey = 'projects_area_$area';
    
    // Try to get from cache first
    if (useCache) {
      final cached = await CacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    
    try {
      // Use correct endpoint: GET /projects/location?location=
      final response = await _dioClient.dio.get('/projects/location', queryParameters: {'location': area});
      final list = response.data is List ? response.data as List : <dynamic>[];
      final projects = list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      
      // Cache the results (increased duration to reduce API calls)
      if (useCache && list.isNotEmpty) {
        await CacheManager.set(cacheKey, list, duration: const Duration(minutes: 30));
      }
      
      return projects;
    } on DioException catch (e) {
      print('❌ Error getting projects by area ($area): ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}, Data: ${e.response?.data}');
      }
      return [];
    }
  }

  /// GET /projects/status?status=PLANNING (for "upcoming") (with caching)
  /// Returns only projects with status = PLANNING
  Future<List<ProjectModel>> getUpcomingProjects({bool useCache = true}) async {
    const cacheKey = 'upcoming_projects';
    
    // Try to get from cache first
    if (useCache) {
      final cached = await CacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        final projects = cached.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
        // Filter to ensure only PLANNING status projects (check original JSON status)
        final filtered = projects.where((p) {
          // Find the original JSON data for this project
          final originalJson = cached.firstWhere(
            (item) => (item as Map<String, dynamic>)['_id']?.toString() == p.id,
            orElse: () => <String, dynamic>{},
          ) as Map<String, dynamic>;
          final status = (originalJson['status']?.toString() ?? '').toUpperCase();
          return status == 'PLANNING';
        }).toList();
        print('📦 Cached upcoming projects (PLANNING): ${filtered.length}');
        return filtered;
      }
    }
    
    try {
      // Use correct endpoint: GET /projects/status?status=PLANNING
      print('📡 Fetching upcoming projects (status=PLANNING)...');
      final response = await _dioClient.dio.get('/projects/status', queryParameters: {'status': 'PLANNING'});
      final list = response.data is List ? response.data as List : <dynamic>[];
      
      // Filter to ensure only PLANNING status projects are returned
      final filteredList = list.where((item) {
        final json = item as Map<String, dynamic>;
        final status = (json['status']?.toString() ?? '').toUpperCase();
        return status == 'PLANNING';
      }).toList();
      
      final projects = filteredList.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      
      print('✅ Got ${projects.length} upcoming projects (status=PLANNING) from API');
      
      // Cache the filtered results (only PLANNING projects) - increased duration to reduce API calls
      if (useCache && filteredList.isNotEmpty) {
        await CacheManager.set(cacheKey, filteredList, duration: const Duration(minutes: 30));
      }
      
      return projects;
    } on DioException catch (e) {
      print('❌ Error getting upcoming projects: ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}, Data: ${e.response?.data}');
      }
      return [];
    }
  }

  /// GET /projects/status?status= (for "Upcoming") or /projects/trending (for others)
  Future<List<ProjectModel>> getProjectsByCategory(String category) async {
    try {
      if (category == 'Upcoming') {
        final response = await _dioClient.dio.get('/projects/status', queryParameters: {'status': 'PLANNING'});
        final list = response.data is List ? response.data as List : <dynamic>[];
        return list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        // For other categories, use trending
        final response = await _dioClient.dio.get('/projects/trending', queryParameters: {'limit': '50'});
        final list = response.data is List ? response.data as List : <dynamic>[];
        return list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// GET /developer — requires ADMIN/SUPERADMIN; may 403 for normal users.
  Future<List<DeveloperModel>> getDevelopers() async {
    try {
      final response = await _dioClient.dio.get('/developer');
      final list = response.data is List ? response.data as List : <dynamic>[];
      return list.map((e) => DeveloperModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      print('Error getting developers: ${e.message}');
      return [];
    }
  }

  /// No /areas in backend; return empty.
  Future<List<AreaModel>> getAreas() async {
    return [];
  }

  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to server.';
      case DioExceptionType.badResponse:
        return e.response?.data?['message'] ?? 'An error occurred. Please try again.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}
