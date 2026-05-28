import 'package:cloud_firestore/cloud_firestore.dart';

class AppSession {
  final String id;
  final String uid;
  final String deviceId;
  final String deviceLabel;
  final String platform;
  final String appVersion;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final DateTime? endedAt;
  final String? endReason;
  final String? revokedBy;

  const AppSession({
    required this.id,
    required this.uid,
    required this.deviceId,
    required this.deviceLabel,
    required this.platform,
    required this.appVersion,
    required this.createdAt,
    required this.lastSeenAt,
    this.endedAt,
    this.endReason,
    this.revokedBy,
  });

  bool get isActive {
    if (endedAt != null) return false;
    return DateTime.now().difference(lastSeenAt) <= const Duration(minutes: 15);
  }

  static AppSession fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppSession(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      deviceId: data['deviceId'] as String? ?? '',
      deviceLabel: data['deviceLabel'] as String? ?? 'Desconhecido',
      platform: data['platform'] as String? ?? '',
      appVersion: data['appVersion'] as String? ?? '',
      createdAt: _ts(data['createdAt']) ?? DateTime.now(),
      lastSeenAt: _ts(data['lastSeenAt']) ?? DateTime.now(),
      endedAt: _ts(data['endedAt']),
      endReason: data['endReason'] as String?,
      revokedBy: data['revokedBy'] as String?,
    );
  }

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }
}
