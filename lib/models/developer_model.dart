class DeveloperModel {
  final String id;
  final String name;
  final String logo;
  final bool isAsset;
  final int projectsCount;
  final String description;
  final List<String> areas;
  final DateTime? createdAt;

  DeveloperModel({
    required this.id,
    required this.name,
    this.logo = '',
    this.isAsset = false,
    this.projectsCount = 0,
    this.description = '',
    this.areas = const [],
    this.createdAt,
  });

  factory DeveloperModel.fromJson(Map<String, dynamic> json) {
    // Handle projects array to get count
    int projectsCount = 0;
    if (json['projects'] != null) {
      if (json['projects'] is List) {
        projectsCount = (json['projects'] as List).length;
      }
    }
    projectsCount = json['projectsCount'] is int ? json['projectsCount'] as int : projectsCount;

    // API: name, email, phone, location, projects, deletedAt. No logo, description, areas.
    return DeveloperModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      logo: json['logo']?.toString() ?? json['logoUrl']?.toString() ?? '',
      isAsset: json['isAsset'] == true,
      projectsCount: projectsCount,
      description: '', // not in API
      areas: const [], // not in API
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
      'isAsset': isAsset,
      'projectsCount': projectsCount,
      'description': description,
      'areas': areas,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

