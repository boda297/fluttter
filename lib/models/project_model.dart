class ProjectModel {
  final String id;
  final String title;
  final String subtitle;
  final String? label;
  final String image;
  final bool isAsset;
  final List<String> gradientColors;
  final String location;
  final String area;
  final String developerName;
  final String developerId;
  final String category;
  final String description;
  final double? watchProgress;
  final int? rank;
  final bool isFeatured;
  final bool isUpcoming;
  final bool isSaved;
  final List<String> tags;
  final DateTime? createdAt;
  // New fields for Project Details
  final String script;
  final String whatsappNumber;
  final String locationUrl;
  final String inventoryUrl;
  final String advertisementVideoUrl; // Video URL for advertisement in hero section (from heroVideoUrl in API)
  final String projectThumbnailUrl; // Thumbnail image for project cards
  final String? logo; // Logo URL for the project
  final bool? hasVideo; // Backend determines if project has video (true) or image (false)
  
  // Getter to access heroVideoUrl directly (same as advertisementVideoUrl)
  String get heroVideoUrl => advertisementVideoUrl;

  ProjectModel({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.label,
    required this.image,
    this.isAsset = false,
    this.gradientColors = const ['0xFF1a4a4a', '0xFF0d2525'],
    this.location = '',
    this.area = '',
    this.developerName = '',
    this.developerId = '',
    this.category = 'Residential',
    this.description = '',
    this.watchProgress,
    this.rank,
    this.isFeatured = false,
    this.isUpcoming = false,
    this.isSaved = false,
    this.tags = const [],
    this.createdAt,
    this.script = '',
    this.whatsappNumber = '',
    this.locationUrl = '',
    this.inventoryUrl = '',
    this.advertisementVideoUrl = '',
    this.projectThumbnailUrl = '',
    this.logo,
    this.hasVideo,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    // Handle developer as ObjectId or populated object (API: developer)
    String developerId = '';
    String developerName = '';
    if (json['developer'] != null) {
      if (json['developer'] is Map) {
        developerId = json['developer']['_id']?.toString() ?? json['developer']['id']?.toString() ?? '';
        developerName = json['developer']['name'] ?? '';
      } else {
        developerId = json['developer'].toString();
      }
    }
    developerId = json['developerId']?.toString() ?? developerId;
    developerName = json['developerName']?.toString() ?? developerName;

    // Category derived from status only (API has status, not category)
    String category = 'Residential';
    if (json['status'] != null) {
      final status = json['status'].toString().toUpperCase();
      if (status == 'PLANNING' || status == 'CONSTRUCTION') {
        category = 'Upcoming';
      } else if (status == 'COMPLETED' || status == 'DELIVERED') {
        category = 'Residential';
      }
    }

    // hasVideo derived from heroVideoUrl (API has heroVideoUrl)
    bool? hasVideo;
    final heroVideoUrl = json['heroVideoUrl'] ?? json['advertisementVideoUrl'] ?? '';
    if (heroVideoUrl.isNotEmpty) {
      hasVideo = true;
    } else {
      hasVideo = json['hasVideo'] as bool?;
    }

    // API-only fields; non-API fields use defaults
    return ProjectModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      subtitle: '', // not in API
      label: null, // not in API
      image: json['image']?.toString() ?? heroVideoUrl,
      // Only set isAsset to true if image starts with 'assets/' and is a valid local path
      // Otherwise, treat it as a network URL even if isAsset is true in API
      isAsset: json['isAsset'] == true && 
               (json['image']?.toString() ?? '').startsWith('assets/') &&
               !(json['image']?.toString() ?? '').startsWith('http'),
      gradientColors: const ['0xFF1a4a4a', '0xFF0d2525'], // not in API
      location: json['location']?.toString() ?? '',
      area: json['area']?.toString() ?? json['location']?.toString() ?? '',
      developerName: developerName,
      developerId: developerId,
      category: category,
      description: '', // not in API
      watchProgress: (json['watchProgress'] is num) ? (json['watchProgress'] as num).toDouble() : null,
      rank: null, // only in GET /projects/trending (index+1), not in single project
      isFeatured: json['featured'] == true || json['isFeatured'] == true, // Read from API
      isUpcoming: category == 'Upcoming',
      isSaved: false, // from user/save-project, not project payload
      tags: const [], // not in API
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      script: json['script']?.toString() ?? '',
      whatsappNumber: json['whatsappNumber']?.toString() ?? '',
      locationUrl: json['locationUrl']?.toString() ?? json['mapsLocation']?.toString() ?? '',
      inventoryUrl: '', // from /files/get/inventory, not project payload
      advertisementVideoUrl: heroVideoUrl,
      projectThumbnailUrl: json['projectThumbnailUrl']?.toString() ?? json['image']?.toString() ?? '',
      logo: json['logo']?.toString() ?? json['logoUrl']?.toString(),
      hasVideo: hasVideo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'label': label,
      'image': image,
      'isAsset': isAsset,
      'gradientColors': gradientColors,
      'location': location,
      'area': area,
      'developerName': developerName,
      'developerId': developerId,
      'category': category,
      'description': description,
      'watchProgress': watchProgress,
      'rank': rank,
      'isFeatured': isFeatured,
      'isUpcoming': isUpcoming,
      'isSaved': isSaved,
      'tags': tags,
      'createdAt': createdAt?.toIso8601String(),
      'script': script,
      'whatsappNumber': whatsappNumber,
      'locationUrl': locationUrl,
      'inventoryUrl': inventoryUrl,
      'advertisementVideoUrl': advertisementVideoUrl,
      'projectThumbnailUrl': projectThumbnailUrl,
      'logo': logo,
      'hasVideo': hasVideo,
    };
  }

  ProjectModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? label,
    String? image,
    bool? isAsset,
    List<String>? gradientColors,
    String? location,
    String? area,
    String? developerName,
    String? developerId,
    String? category,
    String? description,
    double? watchProgress,
    int? rank,
    bool? isFeatured,
    bool? isUpcoming,
    bool? isSaved,
    List<String>? tags,
    DateTime? createdAt,
    String? script,
    String? whatsappNumber,
    String? locationUrl,
    String? inventoryUrl,
    String? advertisementVideoUrl,
    String? projectThumbnailUrl,
    String? logo,
    bool? hasVideo,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      label: label ?? this.label,
      image: image ?? this.image,
      isAsset: isAsset ?? this.isAsset,
      gradientColors: gradientColors ?? this.gradientColors,
      location: location ?? this.location,
      area: area ?? this.area,
      developerName: developerName ?? this.developerName,
      developerId: developerId ?? this.developerId,
      category: category ?? this.category,
      description: description ?? this.description,
      watchProgress: watchProgress ?? this.watchProgress,
      rank: rank ?? this.rank,
      isFeatured: isFeatured ?? this.isFeatured,
      isUpcoming: isUpcoming ?? this.isUpcoming,
      isSaved: isSaved ?? this.isSaved,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      script: script ?? this.script,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      locationUrl: locationUrl ?? this.locationUrl,
      inventoryUrl: inventoryUrl ?? this.inventoryUrl,
      advertisementVideoUrl: advertisementVideoUrl ?? this.advertisementVideoUrl,
      projectThumbnailUrl: projectThumbnailUrl ?? this.projectThumbnailUrl,
      logo: logo ?? this.logo,
      hasVideo: hasVideo ?? this.hasVideo,
    );
  }
}

