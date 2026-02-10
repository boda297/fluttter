class ClipModel {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnail;
  final bool isAsset;
  final String developerName;
  final String developerLogo;
  final int likes;
  final bool isLiked;
  final bool hasWhatsApp;
  final DateTime? createdAt;

  ClipModel({
    required this.id,
    required this.projectId,
    this.title = '',
    this.description = '',
    this.videoUrl = '',
    this.thumbnail = '',
    this.isAsset = false,
    this.developerName = '',
    this.developerLogo = '',
    this.likes = 0,
    this.isLiked = false,
    this.hasWhatsApp = true,
    this.createdAt,
  });

  factory ClipModel.fromJson(Map<String, dynamic> json) {
    String projectId = '';
    if (json['projectId'] != null) {
      if (json['projectId'] is Map) {
        projectId = json['projectId']['_id']?.toString() ??
            json['projectId']['id']?.toString() ??
            '';
      } else {
        projectId = json['projectId'].toString();
      }
    }
    // developerName/developerLogo from populated developerId (API: developerId → { name, logoUrl })
    String developerName = json['developerName']?.toString() ?? '';
    String developerLogo = json['developerLogo']?.toString() ?? '';
    final dev = json['developerId'];
    if (dev is Map) {
      if (developerName.isEmpty) developerName = dev['name']?.toString() ?? '';
      if (developerLogo.isEmpty)
        developerLogo =
            dev['logoUrl']?.toString() ?? dev['logo']?.toString() ?? '';
    }
    return ClipModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      projectId: projectId,
      title: json['title'] ?? '',
      description: '', // not in API
      videoUrl: json['videoUrl']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      isAsset: json['isAsset'] == true,
      developerName: developerName,
      developerLogo: developerLogo,
      likes: 0, // not in API (Reel has viewCount, saveCount)
      isLiked: false, // not in API
      hasWhatsApp: true, // not in API; default for UI
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnail': thumbnail,
      'isAsset': isAsset,
      'developerName': developerName,
      'developerLogo': developerLogo,
      'likes': likes,
      'isLiked': isLiked,
      'hasWhatsApp': hasWhatsApp,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  ClipModel copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    String? videoUrl,
    String? thumbnail,
    bool? isAsset,
    String? developerName,
    String? developerLogo,
    int? likes,
    bool? isLiked,
    bool? hasWhatsApp,
    DateTime? createdAt,
  }) {
    return ClipModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnail: thumbnail ?? this.thumbnail,
      isAsset: isAsset ?? this.isAsset,
      developerName: developerName ?? this.developerName,
      developerLogo: developerLogo ?? this.developerLogo,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      hasWhatsApp: hasWhatsApp ?? this.hasWhatsApp,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
