class AreaModel {
  final String id;
  final String name;
  final String image;
  final bool isAsset;
  final int projectsCount;
  final String country;
  final DateTime? createdAt;

  AreaModel({
    required this.id,
    required this.name,
    this.image = '',
    this.isAsset = false,
    this.projectsCount = 0,
    this.country = '',
    this.createdAt,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      isAsset: json['isAsset'] ?? false,
      projectsCount: json['projectsCount'] ?? 0,
      country: json['country'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'isAsset': isAsset,
      'projectsCount': projectsCount,
      'country': country,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

