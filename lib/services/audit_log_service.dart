import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/audit_log_entry.dart';
import 'device_identity_service.dart';

class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceIdentityService _deviceIdentity = DeviceIdentityService();

  CollectionReference<Map<String, dynamic>> get _logs =>
      _firestore.collection('audit_logs');

  Future<void> log({
    required String action,
    String? targetUid,
    String? targetCameraId,
    String? targetSessionId,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final identity = await _deviceIdentity.getIdentity();
    final meta = <String, dynamic>{
      'deviceId': identity.deviceId,
      'deviceLabel': identity.deviceLabel,
      'platform': identity.platform,
      'appVersion': identity.appVersion,
      if (metadata != null) ...metadata,
    };

    await _logs.add({
      'actorUid': user.uid,
      'actorEmail': user.email ?? '',
      'action': action,
      if (targetUid != null) 'targetUid': targetUid,
      if (targetCameraId != null) 'targetCameraId': targetCameraId,
      if (targetSessionId != null) 'targetSessionId': targetSessionId,
      'metadata': meta,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<AuditLogEntry>> fetchRecent({
    int limit = 50,
    DocumentSnapshot? startAfter,
    String? actionFilter,
    String? actorUidFilter,
  }) async {
    Query<Map<String, dynamic>> query = _logs.orderBy(
      'createdAt',
      descending: true,
    );

    if (actionFilter != null && actionFilter.isNotEmpty) {
      query = _logs
          .where('action', isEqualTo: actionFilter)
          .orderBy('createdAt', descending: true);
    } else if (actorUidFilter != null && actorUidFilter.isNotEmpty) {
      query = _logs
          .where('actorUid', isEqualTo: actorUidFilter)
          .orderBy('createdAt', descending: true);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.limit(limit).get();
    return snap.docs.map(AuditLogEntry.fromDoc).toList();
  }
}
