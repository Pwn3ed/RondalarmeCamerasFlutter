import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogEntry {
  final String id;
  final String actorUid;
  final String actorEmail;
  final String action;
  final String? targetUid;
  final String? targetCameraId;
  final String? targetSessionId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.actorUid,
    required this.actorEmail,
    required this.action,
    this.targetUid,
    this.targetCameraId,
    this.targetSessionId,
    this.metadata = const {},
    required this.createdAt,
  });

  static AuditLogEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AuditLogEntry(
      id: doc.id,
      actorUid: data['actorUid'] as String? ?? '',
      actorEmail: data['actorEmail'] as String? ?? '',
      action: data['action'] as String? ?? '',
      targetUid: data['targetUid'] as String?,
      targetCameraId: data['targetCameraId'] as String?,
      targetSessionId: data['targetSessionId'] as String?,
      metadata: Map<String, dynamic>.from(
        (data['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
