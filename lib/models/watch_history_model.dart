class WatchHistoryModel {
  final String id;
  final String userId;
  final String contentId;
  final String contentTitle;
  final String? contentThumbnail;
  final double currentTime; // seconds
  final double duration; // seconds
  final double progressPercentage; // 0-100
  final bool completed;
  final DateTime lastWatchedAt;
  final String? contentType;
  final int? season;
  final int? episode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WatchHistoryModel({
    required this.id,
    required this.userId,
    required this.contentId,
    required this.contentTitle,
    this.contentThumbnail,
    required this.currentTime,
    required this.duration,
    required this.progressPercentage,
    required this.completed,
    required this.lastWatchedAt,
    this.contentType,
    this.season,
    this.episode,
    this.createdAt,
    this.updatedAt,
  });

  factory WatchHistoryModel.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int? _toIntOrNull(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return WatchHistoryModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      contentId: json['contentId']?.toString() ?? '',
      contentTitle: json['contentTitle']?.toString() ?? '',
      contentThumbnail: json['contentThumbnail']?.toString(),
      currentTime: _toDouble(json['currentTime']),
      duration: _toDouble(json['duration']),
      progressPercentage: _toDouble(json['progressPercentage']),
      completed: json['completed'] == true,
      lastWatchedAt: _toDate(json['lastWatchedAt']) ?? DateTime.now(),
      contentType: json['contentType']?.toString(),
      season: _toIntOrNull(json['season']),
      episode: _toIntOrNull(json['episode']),
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
    );
  }
}

