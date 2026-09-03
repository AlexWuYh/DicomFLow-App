import 'dart:io';

class JobOutput {
  const JobOutput({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.frameCount,
    required this.fps,
    this.width = 0,
    this.height = 0,
    this.kind = 'series',
  });

  final String name;
  final String path;
  final int sizeBytes;
  final int frameCount;
  final int fps;
  final int width;
  final int height;
  final String kind;

  bool get fileExists => path.isNotEmpty && File(path).existsSync();

  Map<String, Object?> toJson() => {
    'name': name,
    'path': path,
    'sizeBytes': sizeBytes,
    'frameCount': frameCount,
    'fps': fps,
    'width': width,
    'height': height,
    'kind': kind,
  };

  factory JobOutput.fromJson(Map<String, Object?> json) {
    return JobOutput(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      frameCount: json['frameCount'] as int? ?? 0,
      fps: json['fps'] as int? ?? 10,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      kind: json['kind'] as String? ?? 'series',
    );
  }
}

class JobRecord {
  const JobRecord({
    required this.id,
    required this.createdAt,
    this.completedAt,
    required this.status,
    required this.sourceFilename,
    this.format = 'mp4',
    this.quality = 'high',
    this.fps = 10,
    this.merge = false,
    this.outputs = const [],
    this.errorCode,
    this.errorMessage,
  });

  final String id;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String status;
  final String sourceFilename;
  final String format;
  final String quality;
  final int fps;
  final bool merge;
  final List<JobOutput> outputs;
  final String? errorCode;
  final String? errorMessage;

  /// Filename shown in history; never empty.
  String get displayTitle {
    final n = sourceFilename.trim();
    if (n.isNotEmpty && n != '/' && n != '.') return n;
    for (final out in outputs) {
      final name = out.name.trim();
      if (name.isNotEmpty) return name;
    }
    return '未命名转换';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'status': status,
    'sourceFilename': sourceFilename,
    'format': format,
    'quality': quality,
    'fps': fps,
    'merge': merge,
    'outputs': [for (final o in outputs) o.toJson()],
    'errorCode': errorCode,
    'errorMessage': errorMessage,
  };

  factory JobRecord.fromJson(Map<String, Object?> json) {
    final outputs = (json['outputs'] as List<dynamic>? ?? [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => JobOutput.fromJson(Map<String, Object?>.from(e)))
        .toList();
    return JobRecord(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      status: json['status'] as String? ?? 'FAILED',
      sourceFilename: json['sourceFilename'] as String? ?? '',
      format: json['format'] as String? ?? 'mp4',
      quality: json['quality'] as String? ?? 'high',
      fps: json['fps'] as int? ?? 10,
      merge: json['merge'] as bool? ?? false,
      outputs: outputs,
      errorCode: json['errorCode'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
