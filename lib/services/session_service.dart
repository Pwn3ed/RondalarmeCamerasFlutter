import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_session.dart';
import 'device_identity_service.dart';

typedef SessionRevokedCallback = Future<void> Function(String reason);

class SessionService with WidgetsBindingObserver {
  static const _sessionIdKey = 'active_session_id';
  static const _activeWindow = Duration(minutes: 15);
  static const _heartbeatInterval = Duration(minutes: 5);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceIdentityService _deviceIdentity = DeviceIdentityService();

  Timer? _heartbeatTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _watchSub;
  String? _currentSessionId;
  String? _currentUid;
  SessionRevokedCallback? onSessionRevoked;

  bool get hasActiveSession => _currentSessionId != null;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection('sessions');

  Future<String> startSession(String uid) async {
    if (_currentSessionId != null && _currentUid == uid) {
      await heartbeat();
      return _currentSessionId!;
    }

    final identity = await _deviceIdentity.getIdentity();
    final now = FieldValue.serverTimestamp();

    final doc = await _sessions.add({
      'uid': uid,
      'deviceId': identity.deviceId,
      'deviceLabel': identity.deviceLabel,
      'platform': identity.platform,
      'appVersion': identity.appVersion,
      'createdAt': now,
      'lastSeenAt': now,
    });

    _currentSessionId = doc.id;
    _currentUid = uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, doc.id);

    _startHeartbeat();
    WidgetsBinding.instance.addObserver(this);
    _watchSession(doc.id);

    return doc.id;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      heartbeat();
    });
  }

  Future<void> heartbeat() async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;

    final doc = await _sessions.doc(sessionId).get();
    if (!doc.exists) {
      await _handleRevoked('session_deleted');
      return;
    }

    final data = doc.data() ?? {};
    if (data['endedAt'] != null) {
      await _handleRevoked(data['endReason'] as String? ?? 'revoked');
      return;
    }

    await _sessions.doc(sessionId).update({
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }

  void _watchSession(String sessionId) {
    _watchSub?.cancel();
    _watchSub = _sessions.doc(sessionId).snapshots().listen((snap) async {
      if (!snap.exists) {
        await _handleRevoked('session_deleted');
        return;
      }
      final data = snap.data();
      if (data != null && data['endedAt'] != null) {
        await _handleRevoked(data['endReason'] as String? ?? 'revoked');
      }
    });
  }

  Future<void> _handleRevoked(String reason) async {
    if (_currentSessionId == null) return;
    await stopSession(endReason: reason, notify: false);
    await onSessionRevoked?.call(reason);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      heartbeat();
    }
  }

  Future<List<AppSession>> getActiveSessionsForUser(String uid) async {
    final cutoff = DateTime.now().subtract(_activeWindow);
    final snap = await _sessions
        .where('uid', isEqualTo: uid)
        .where('endedAt', isNull: true)
        .get();

    return snap.docs
        .map(AppSession.fromDoc)
        .where((s) => s.lastSeenAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<int> countActiveSessions(String uid) async {
    final sessions = await getActiveSessionsForUser(uid);
    return sessions.length;
  }

  Future<AppSession?> getOldestActiveSession(
    String uid, {
    String? excludeSessionId,
  }) async {
    final sessions = await getActiveSessionsForUser(uid);
    for (final s in sessions) {
      if (s.id != excludeSessionId) return s;
    }
    return null;
  }

  Future<void> endSessionById(
    String sessionId, {
    required String endReason,
    String? revokedBy,
  }) async {
    await _sessions.doc(sessionId).update({
      'endedAt': FieldValue.serverTimestamp(),
      'endReason': endReason,
      if (revokedBy != null) 'revokedBy': revokedBy,
    });
  }

  Future<void> revokeAllActiveForUser(
    String uid, {
    required String endReason,
    String? revokedBy,
  }) async {
    final active = await getActiveSessionsForUser(uid);
    for (final s in active) {
      await endSessionById(
        s.id,
        endReason: endReason,
        revokedBy: revokedBy,
      );
    }
  }

  Future<List<AppSession>> fetchSessions({
    bool activeOnly = false,
    int limit = 100,
  }) async {
    Query<Map<String, dynamic>> query =
        _sessions.orderBy('lastSeenAt', descending: true);

    if (activeOnly) {
      query = _sessions
          .where('endedAt', isNull: true)
          .orderBy('lastSeenAt', descending: true);
    }

    final snap = await query.limit(limit).get();
    final sessions = snap.docs.map(AppSession.fromDoc).toList();

    if (activeOnly) {
      final cutoff = DateTime.now().subtract(_activeWindow);
      return sessions.where((s) => s.lastSeenAt.isAfter(cutoff)).toList();
    }
    return sessions;
  }

  Future<void> stopSession({
    String endReason = 'logout',
    bool notify = true,
  }) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    await _watchSub?.cancel();
    _watchSub = null;

    final sessionId = _currentSessionId;
    _currentSessionId = null;
    _currentUid = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);

    if (sessionId != null) {
      try {
        await _sessions.doc(sessionId).update({
          'endedAt': FieldValue.serverTimestamp(),
          'endReason': endReason,
        });
      } catch (_) {
        // session may already be ended
      }
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _watchSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
