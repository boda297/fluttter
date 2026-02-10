class EpisodeModel {
  final String id;
  final String projectId;
  final String title;
  final int episodeNumber;
  final String thumbnail;
  final bool isAsset;
  final String videoUrl;
  final String duration;
  final String description;
  final DateTime? createdAt;

  EpisodeModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.episodeNumber,
    this.thumbnail = '',
    this.isAsset = false,
    this.videoUrl = '',
    this.duration = '',
    this.description = '',
    this.createdAt,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    // Handle projectId as ObjectId or string
    String projectId = '';
    if (json['projectId'] != null) {
      if (json['projectId'] is Map) {
        projectId = json['projectId']['_id']?.toString() ?? json['projectId']['id']?.toString() ?? '';
      } else {
        projectId = json['projectId'].toString();
      }
    }
    
    // Parse episodeOrder to episodeNumber
    int episodeNumber = 1;
    if (json['episodeOrder'] != null) {
      final orderStr = json['episodeOrder'].toString();
      final orderMatch = RegExp(r'\d+').firstMatch(orderStr);
      if (orderMatch != null) {
        episodeNumber = int.tryParse(orderMatch.group(0) ?? '1') ?? 1;
      }
    }
    
    return EpisodeModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      projectId: projectId,
      title: json['title'] ?? '',
      episodeNumber: json['episodeNumber'] ?? episodeNumber,
      thumbnail: json['thumbnail'] ?? '',
      isAsset: json['isAsset'] ?? false,
      videoUrl: json['episodeUrl'] ?? json['videoUrl'] ?? '',
      duration: json['duration'] ?? '',
      description: '', // not in API
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'episodeNumber': episodeNumber,
      'thumbnail': thumbnail,
      'isAsset': isAsset,
      'videoUrl': videoUrl,
      'duration': duration,
      'description': description,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

