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
  final List<String> assignedUserIds;

  /// Legado: migrado para [assignedUserIds] na leitura.
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
    List<String>? assignedUserIds,
    this.ownerId,
    required this.createdAt,
  }) : assignedUserIds = List.unmodifiable(assignedUserIds ?? const []);

  bool get usesRtsp => protocol == CameraProtocol.rtsp;

  bool get usesHttpFile => protocol == CameraProtocol.httpFile;

  bool get usesMediaKitPlayer =>
      usesRtsp || usesHttpFile || protocol == CameraProtocol.hls;

  bool get usesExoPlayer => false;

  bool get isUnassigned => effectiveAssignedUserIds.isEmpty;

  int get assignedUserCount => effectiveAssignedUserIds.length;

  List<String> get effectiveAssignedUserIds {
    if (assignedUserIds.isNotEmpty) return assignedUserIds;
    if (ownerId != null && ownerId!.isNotEmpty) return [ownerId!];
    return const [];
  }

  bool hasAccess(String uid) => effectiveAssignedUserIds.contains(uid);

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

  static List<String> _assignedUserIdsFromJson(Map<String, dynamic> json) {
    final raw = json['assignedUserIds'];
    final ids = <String>[];
    if (raw is List) {
      for (final item in raw) {
        final id = item?.toString().trim();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
  }

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
      'assignedUserIds': assignedUserIds,
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
      assignedUserIds: _assignedUserIdsFromJson(json),
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
    List<String>? assignedUserIds,
    String? ownerId,
    DateTime? createdAt,
    bool clearServer = false,
    bool clearRtspUrl = false,
    bool clearOwnerId = false,
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
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
      ownerId: clearOwnerId ? null : (ownerId ?? this.ownerId),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
