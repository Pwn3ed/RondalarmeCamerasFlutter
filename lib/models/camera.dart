class Camera {
  final String id;
  final String name;
  final String description;
  final String serverIp;
  final int serverPort;
  final String streamPath;
  final bool isActive;
  final DateTime createdAt;

  Camera({
    required this.id,
    required this.name,
    required this.description,
    required this.serverIp,
    required this.serverPort,
    required this.streamPath,
    this.isActive = true,
    required this.createdAt,
  });

  String get streamUrl {
    return 'http://$serverIp:$serverPort$streamPath';
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
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      serverIp: json['serverIp'],
      serverPort: json['serverPort'],
      streamPath: json['streamPath'],
      isActive: json['isActive'] ?? true,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
