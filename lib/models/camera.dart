import 'camera_protocol.dart';

class Camera {
  final String id;
  final String name;
  final String description;
  final CameraProtocol protocol;
  final String? serverIp;
  final int? serverPort;
  final String streamPath;
  final String? rtspUrl;
  final bool isActive;
  final bool isManualMode;
  final bool isPublic;
  final String? ownerId;
  final DateTime createdAt;

  Camera({
    required this.id,
    required this.name,
    required this.description,
    this.protocol = CameraProtocol.hls,
    this.serverIp,
    this.serverPort,
    required this.streamPath,
    this.rtspUrl,
    this.isActive = true,
    this.isManualMode = false,
    this.isPublic = false,
    this.ownerId,
    required this.createdAt,
  });

  bool get usesRtsp => protocol == CameraProtocol.rtsp;

  bool get usesHttpFile => protocol == CameraProtocol.httpFile;

  /// RTSP e HTTP (MP4/MKV) usam media_kit; HLS usa video_player.
  bool get usesMediaKitPlayer => usesRtsp || usesHttpFile;

  /// Usa [video_player] (somente HLS).
  bool get usesExoPlayer => protocol == CameraProtocol.hls;

  String get rtspPlaybackUrl {
    final url = rtspUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
    return streamPath.trim();
  }

  String get streamUrl {
    if (usesRtsp) return rtspPlaybackUrl;
    if (usesHttpFile) return streamPath.trim();

    final path = streamPath.trim();
    if (isManualMode) return path;
    if (serverIp != null && serverPort != null && path.isNotEmpty) {
      final server = serverIp!.trim();
      final cleanPath = path.startsWith('/') ? path : '/$path';
      return 'http://$server:$serverPort$cleanPath/video1_stream.m3u8';
    }
    return path;
  }

  String get protocolLabel => protocol.label;

  static CameraProtocol _protocolFromJson(Map<String, dynamic> json) {
    final explicit = json['protocol'] as String?;
    if (explicit != null) {
      return CameraProtocolLabels.fromStorage(explicit);
    }
    final path = (json['streamPath'] as String?)?.trim() ?? '';
    if (path.toLowerCase().startsWith('rtsp://')) {
      return CameraProtocol.rtsp;
    }
    if (isValidHttpFileUrl(path)) {
      return CameraProtocol.httpFile;
    }
    final rtsp = (json['rtspUrl'] as String?)?.trim();
    if (rtsp != null && rtsp.isNotEmpty) {
      final hasHlsServer =
          json['serverIp'] != null &&
          (json['serverIp'] as String).toString().trim().isNotEmpty;
      final manualHls =
          json['isManualMode'] == true &&
          path.isNotEmpty &&
          !path.toLowerCase().startsWith('rtsp://');
      if (!hasHlsServer && !manualHls) return CameraProtocol.rtsp;
    }
    return CameraProtocol.hls;
  }

  Map<String, dynamic> toJson() {
    final trimmedRtsp = rtspUrl?.trim();
    return {
      'id': id,
      'name': name,
      'description': description,
      'protocol': protocol.storageValue,
      'serverIp': serverIp,
      'serverPort': serverPort,
      'streamPath': streamPath,
      if (trimmedRtsp != null && trimmedRtsp.isNotEmpty) 'rtspUrl': trimmedRtsp,
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
      protocol: _protocolFromJson(json),
      serverIp: json['serverIp'] as String?,
      serverPort: json['serverPort'] is int
          ? json['serverPort'] as int
          : (json['serverPort'] != null
                ? int.tryParse(json['serverPort'].toString())
                : null),
      streamPath: json['streamPath'] as String? ?? '',
      rtspUrl: json['rtspUrl'] as String?,
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
    CameraProtocol? protocol,
    String? serverIp,
    int? serverPort,
    String? streamPath,
    String? rtspUrl,
    bool? isActive,
    bool? isManualMode,
    bool? isPublic,
    String? ownerId,
    DateTime? createdAt,
    bool clearServer = false,
    bool clearRtspUrl = false,
  }) {
    return Camera(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      protocol: protocol ?? this.protocol,
      serverIp: clearServer ? null : (serverIp ?? this.serverIp),
      serverPort: clearServer ? null : (serverPort ?? this.serverPort),
      streamPath: streamPath ?? this.streamPath,
      rtspUrl: clearRtspUrl
          ? null
          : (rtspUrl != null
                ? (rtspUrl.isEmpty ? null : rtspUrl)
                : this.rtspUrl),
      isActive: isActive ?? this.isActive,
      isManualMode: isManualMode ?? this.isManualMode,
      isPublic: isPublic ?? this.isPublic,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
