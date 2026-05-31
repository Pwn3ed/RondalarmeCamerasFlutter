import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/camera.dart';
import '../models/camera_protocol.dart';

class CameraFirestoreService {
  static const String _localCacheKey = 'cameras_cache';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _cameras =>
      _firestore.collection('cameras');

  Map<String, dynamic> _cameraPayloadForWrite(Camera camera) {
    final map = Map<String, dynamic>.from(camera.toJson());
    map.remove('id');
    map.remove('ownerId');
    return map;
  }

  Camera _cameraFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Camera.fromJson({...doc.data()!, 'id': doc.id});
  }

  List<Camera> _mergeCameraDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final cameras = <String, Camera>{};
    for (final doc in docs) {
      cameras[doc.id] = _cameraFromDoc(doc);
    }
    return cameras.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Stream<List<Camera>> _mergeQuerySnapshots(
    List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams,
  ) {
    if (streams.isEmpty) return Stream.value(const []);
    if (streams.length == 1) {
      return streams.first.map((snapshot) => _mergeCameraDocs(snapshot.docs));
    }

    final controller = StreamController<List<Camera>>();
    final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
      streams.length,
      null,
    );
    final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emitMerged() {
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final snapshot in latest) {
        if (snapshot != null) docs.addAll(snapshot.docs);
      }
      if (!controller.isClosed) {
        controller.add(_mergeCameraDocs(docs));
      }
    }

    for (var i = 0; i < streams.length; i++) {
      final index = i;
      subscriptions.add(
        streams[i].listen(
          (snapshot) {
            latest[index] = snapshot;
            emitMerged();
          },
          onError: controller.addError,
        ),
      );
    }

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  Future<List<Camera>> _getClientCameras(String uid) async {
    final byAssignment = await _cameras
        .where('assignedUserIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .get();
    final byLegacyOwner = await _cameras
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return _mergeCameraDocs([...byAssignment.docs, ...byLegacyOwner.docs]);
  }

  Stream<List<Camera>> _clientCamerasStream(String uid) {
    return _mergeQuerySnapshots([
      _cameras
          .where('assignedUserIds', arrayContains: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      _cameras
          .where('ownerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
    ]);
  }

  Future<List<Camera>> getAllCameras({required bool isAdmin}) async {
    try {
      if (_currentUserId == null) {
        return _getCachedCameras();
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot;
      if (isAdmin) {
        snapshot = await _cameras.orderBy('createdAt', descending: true).get();
      } else {
        final cameras = await _getClientCameras(_currentUserId!);
        await _saveCacheLocal(cameras);
        return cameras;
      }

      final cameras = snapshot.docs.map(_cameraFromDoc).toList();
      return cameras;
    } catch (e) {
      if (!isAdmin) return _getCachedCameras();
      rethrow;
    }
  }

  Future<List<Camera>> getCamerasForUser(String userId) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    final byAssignment = await _cameras
        .where('assignedUserIds', arrayContains: userId)
        .get();
    final byLegacyOwner = await _cameras.where('ownerId', isEqualTo: userId).get();

    final cameras = <String, Camera>{};
    for (final doc in [...byAssignment.docs, ...byLegacyOwner.docs]) {
      cameras[doc.id] = _cameraFromDoc(doc);
    }

    final list = cameras.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<Camera> addCamera({
    required String name,
    required String description,
    required CameraProtocol protocol,
    String? serverIp,
    int? serverPort,
    required String streamPath,
    String? rtspUrl,
    required bool isManualMode,
    bool isPublic = false,
    List<String> assignedUserIds = const [],
  }) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    final camera = Camera(
      id: '',
      name: name,
      description: description,
      protocol: protocol,
      serverIp: serverIp,
      serverPort: serverPort,
      streamPath: streamPath,
      rtspUrl: rtspUrl?.trim().isEmpty == true ? null : rtspUrl?.trim(),
      isManualMode: isManualMode,
      isPublic: isPublic,
      assignedUserIds: assignedUserIds,
      createdAt: DateTime.now(),
    );

    final docRef = await _cameras.add(_cameraPayloadForWrite(camera));
    return camera.copyWith(id: docRef.id);
  }

  Future<void> updateCamera(Camera camera) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    await _cameras.doc(camera.id).update(_cameraPayloadForWrite(camera));
  }

  Future<void> grantUserCameraAccess({
    required String userId,
    required Set<String> cameraIds,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }
    if (cameraIds.isEmpty) return;

    for (final cameraId in cameraIds) {
      final doc = await _cameras.doc(cameraId).get();
      if (!doc.exists) {
        throw Exception('Câmera não encontrada');
      }

      final camera = _cameraFromDoc(doc);
      if (camera.hasAccess(userId)) continue;

      final ids = [...camera.effectiveAssignedUserIds, userId]..sort();
      await _cameras.doc(cameraId).update(
        _cameraPayloadForWrite(
          camera.copyWith(assignedUserIds: ids, clearOwnerId: true),
        ),
      );
    }
  }

  Future<void> revokeUserCameraAccess({
    required String cameraId,
    required String userId,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    final doc = await _cameras.doc(cameraId).get();
    if (!doc.exists) {
      throw Exception('Câmera não encontrada');
    }

    final camera = _cameraFromDoc(doc);
    if (!camera.hasAccess(userId)) return;

    final ids = camera.effectiveAssignedUserIds
        .where((id) => id != userId)
        .toList();
    await _cameras.doc(cameraId).update(
      _cameraPayloadForWrite(
        camera.copyWith(assignedUserIds: ids, clearOwnerId: true),
      ),
    );
  }

  Future<void> deleteCamera(String id) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }
    await _cameras.doc(id).delete();
  }

  Future<void> toggleCameraStatus(String id) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    final doc = await _cameras.doc(id).get();
    if (doc.exists) {
      final isActive = doc.data()?['isActive'] ?? true;
      await _cameras.doc(id).update({'isActive': !isActive});
    }
  }

  Future<List<Camera>> getPublicCameras() async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    final snapshot = await _cameras
        .where('isPublic', isEqualTo: true)
        .orderBy('name')
        .get();

    return snapshot.docs.map(_cameraFromDoc).toList();
  }

  Stream<List<Camera>> camerasStream({required bool isAdmin}) {
    if (_currentUserId == null) {
      return Stream.error(Exception('Usuário não autenticado'));
    }

    if (isAdmin) {
      return _cameras
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_cameraFromDoc).toList());
    }

    return _clientCamerasStream(_currentUserId!);
  }

  Future<void> _saveCacheLocal(List<Camera> cameras) async {
    final prefs = await SharedPreferences.getInstance();
    final camerasJson = cameras
        .map((camera) => jsonEncode(camera.toJson()))
        .toList();
    await prefs.setStringList(_localCacheKey, camerasJson);
  }

  Future<List<Camera>> _getCachedCameras() async {
    final prefs = await SharedPreferences.getInstance();
    final camerasJson = prefs.getStringList(_localCacheKey) ?? [];
    return camerasJson
        .map(
          (json) => Camera.fromJson(jsonDecode(json) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localCacheKey);
  }
}
