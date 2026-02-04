class PdfFileModel {
  final String id;
  final String projectId;
  final String title;
  final String fileName;
  final String fileUrl; // Cloud Storage URL
  final String? description;
  final int fileSize; // Size in bytes
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PdfFileModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.fileName,
    required this.fileUrl,
    this.description,
    this.fileSize = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory PdfFileModel.fromJson(Map<String, dynamic> json) {
    // Backend uses project (ObjectId or populated); also support projectId
    String projectId = '';
    final proj = json['project'] ?? json['projectId'];
    if (proj != null) {
      if (proj is Map) {
        projectId = proj['_id']?.toString() ?? proj['id']?.toString() ?? '';
      } else {
        projectId = proj.toString();
      }
    }
    // API: pdfUrl, title, s3Key, project. fileUrl from pdfUrl; fileName from title or s3Key.
    final fileUrl = json['pdfUrl']?.toString() ?? json['fileUrl']?.toString() ?? '';
    String fileName = json['title']?.toString() ?? '';
    if (fileName.isEmpty && json['s3Key'] != null) {
      final s3 = json['s3Key'].toString();
      fileName = s3.contains('/') ? s3.split('/').last : s3;
    }
    return PdfFileModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      projectId: projectId,
      title: json['title'] ?? '',
      fileName: fileName,
      fileUrl: fileUrl,
      description: null, // not in API
      fileSize: 0, // not in API
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'description': description,
      'fileSize': fileSize,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Format file size for display
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

