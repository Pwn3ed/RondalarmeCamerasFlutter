class Camera {
  final String id;
  final String name;
  final String description;
  final String? serverIp;
  final int? serverPort;
  final String streamPath;
  final bool isActive;
  final bool isManualMode;
  final bool isPublic;
  /// Dono da câmera (útil em listagens via collectionGroup e regras).
  final String? ownerId;
  final DateTime createdAt;

  Camera({
    required this.id,
    required this.name,
    required this.description,
    this.serverIp,
    this.serverPort,
    required this.streamPath,
    this.isActive = true,
    this.isManualMode = false,
    this.isPublic = false,
    this.ownerId,
    required this.createdAt,
  });

  String get streamUrl {
    final path = streamPath.trim();
    if (isManualMode) {
      return path;
    }
    if (serverIp != null && serverPort != null && path.isNotEmpty) {
      final server = serverIp!.trim();
      final cleanPath = path.startsWith('/') ? path : '/$path';
      return 'http://$server:$serverPort$cleanPath/video1_stream.m3u8';
    }
    return path;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'serverIp': serverIp,
      'serverPort': serverPort,
      'streamPath': streamPath,
      'isActive': isActive,
      'isManualMode': isManualMode,
      'isPublic': isPublic,
      if (ownerId != null) 'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      serverIp: json['serverIp'] as String?,
      serverPort: json['serverPort'] is int
          ? json['serverPort'] as int
          : (json['serverPort'] != null
              ? int.tryParse(json['serverPort'].toString())
              : null),
      streamPath: json['streamPath'] as String,
      isActive: json['isActive'] ?? true,
      isManualMode: json['isManualMode'] ?? false,
      isPublic: json['isPublic'] ?? false,
      ownerId: json['ownerId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Camera copyWith({
    String? id,
    String? name,
    String? description,
    String? serverIp,
    int? serverPort,
    String? streamPath,
    bool? isActive,
    bool? isManualMode,
    bool? isPublic,
    String? ownerId,
    DateTime? createdAt,
  }) {
    return Camera(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      serverIp: serverIp ?? this.serverIp,
      serverPort: serverPort ?? this.serverPort,
      streamPath: streamPath ?? this.streamPath,
      isActive: isActive ?? this.isActive,
      isManualMode: isManualMode ?? this.isManualMode,
      isPublic: isPublic ?? this.isPublic,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
