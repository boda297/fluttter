class NewsModel {
  final String id;
  final String projectId;
  final String title;
  final String subtitle;
  final String description;
  final String image;
  final bool isAsset;
  final List<String> gradientColors;
  final DateTime date;
  final String projectName;
  final String projectSubtitle;
  final bool isReminded;

  NewsModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.subtitle = '',
    this.description = '',
    required this.image,
    this.isAsset = false,
    this.gradientColors = const ['0xFF5a8a9a', '0xFF3a6a7a'],
    required this.date,
    required this.projectName,
    this.projectSubtitle = '',
    this.isReminded = false,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    String projectId = '';
    String projectName = '';
    if (json['projectId'] != null) {
      if (json['projectId'] is Map) {
        projectId = json['projectId']['_id']?.toString() ?? json['projectId']['id']?.toString() ?? '';
        projectName = json['projectId']['title']?.toString() ?? '';
      } else {
        projectId = json['projectId'].toString();
      }
    }
    // API: title, thumbnail, projectId, developer (string). projectName from projectId.title when populated.
    final projectSubtitle = json['projectSubtitle']?.toString() ?? json['developer']?.toString() ?? '';
    return NewsModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      projectId: projectId,
      title: json['title'] ?? '',
      subtitle: '', // not in API
      description: '', // not in API
      image: json['thumbnail']?.toString() ?? json['image']?.toString() ?? '',
      isAsset: json['isAsset'] == true,
      gradientColors: const ['0xFF5a8a9a', '0xFF3a6a7a'], // not in API
      date: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['date'] != null ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() : DateTime.now()),
      projectName: json['projectName']?.toString() ?? projectName,
      projectSubtitle: projectSubtitle,
      isReminded: false, // local only; not in API
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'image': image,
      'isAsset': isAsset,
      'gradientColors': gradientColors,
      'date': date.toIso8601String(),
      'projectName': projectName,
      'projectSubtitle': projectSubtitle,
      'isReminded': isReminded,
    };
  }

  NewsModel copyWith({
    String? id,
    String? projectId,
    String? title,
    String? subtitle,
    String? description,
    String? image,
    bool? isAsset,
    List<String>? gradientColors,
    DateTime? date,
    String? projectName,
    String? projectSubtitle,
    bool? isReminded,
  }) {
    return NewsModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      image: image ?? this.image,
      isAsset: isAsset ?? this.isAsset,
      gradientColors: gradientColors ?? this.gradientColors,
      date: date ?? this.date,
      projectName: projectName ?? this.projectName,
      projectSubtitle: projectSubtitle ?? this.projectSubtitle,
      isReminded: isReminded ?? this.isReminded,
    );
  }
}

