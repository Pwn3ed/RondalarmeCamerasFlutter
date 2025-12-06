class Camera {
  final String id;
  final String name;
  final String description;
  final String? serverIp;
  final int? serverPort;
  final String streamPath;
  final bool isActive;
  final bool isManualMode;
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
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      serverIp: json['serverIp'],
      serverPort: json['serverPort'] is int ? json['serverPort'] : (json['serverPort'] != null ? int.tryParse(json['serverPort'].toString()) : null),
      streamPath: json['streamPath'],
      isActive: json['isActive'] ?? true,
      isManualMode: json['isManualMode'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
