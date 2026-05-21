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

  CollectionReference<Map<String, dynamic>> _getUserCamerasCollection() {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }
    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('cameras');
  }

  Map<String, dynamic> _cameraPayloadForWrite(Camera camera) {
    final map = Map<String, dynamic>.from(camera.toJson());
    map.remove('id');
    return map;
  }

  Camera _cameraFromUserDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String ownerUid,
  ) {
    return Camera.fromJson({
      ...doc.data(),
      'id': doc.id,
      'ownerId': ownerUid,
    });
  }

  Future<List<Camera>> getAllCameras() async {
    try {
      if (_currentUserId == null) {
        return _getCachedCameras();
      }

      final uid = _currentUserId!;
      final snapshot = await _getUserCamerasCollection().get();
      final cameras = snapshot.docs
          .map((doc) => _cameraFromUserDoc(doc, uid))
          .toList();
      await _saveCacheLocal(cameras);
      return cameras;
    } catch (e) {
      return _getCachedCameras();
    }
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
  }) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    final uid = _currentUserId!;

    try {
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
        ownerId: uid,
        createdAt: DateTime.now(),
      );

      final docRef = await _getUserCamerasCollection()
          .add(_cameraPayloadForWrite(camera));
      final cameraWithId = camera.copyWith(id: docRef.id);
      return cameraWithId;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCamera(Camera camera) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    final uid = _currentUserId!;
    final withOwner = camera.ownerId == null || camera.ownerId!.isEmpty
        ? camera.copyWith(ownerId: uid)
        : camera;

    try {
      await _getUserCamerasCollection()
          .doc(withOwner.id)
          .update(_cameraPayloadForWrite(withOwner));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCamera(String id) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      await _getUserCamerasCollection().doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleCameraStatus(String id) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      final doc = await _getUserCamerasCollection().doc(id).get();
      if (doc.exists) {
        final isActive = doc.data()?['isActive'] ?? true;
        await _getUserCamerasCollection()
            .doc(id)
            .update({'isActive': !isActive});
      }
    } catch (e) {
      rethrow;
    }
  }

  Camera _cameraFromGroupDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final ownerFromPath = doc.reference.parent.parent?.id;
    final ownerId = (doc.data()['ownerId'] as String?) ?? ownerFromPath;
    return Camera.fromJson({
      ...doc.data(),
      'id': doc.id,
      if (ownerId != null) 'ownerId': ownerId,
    });
  }

  /// Câmeras públicas: junta (1) as suas em `users/{uid}/cameras` — sempre permitido pelas regras de dono —
  /// com (2) `collectionGroup('cameras')` — precisa de regra que permita ler documentos com `isPublic == true`.
  Future<List<Camera>> getPublicCameras() async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    final uid = _currentUserId!;
    final seenPaths = <String>{};
    final result = <Camera>[];

    void addUnique(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final path = doc.reference.path;
      if (seenPaths.contains(path)) return;
      seenPaths.add(path);
      result.add(_cameraFromGroupDoc(doc));
    }

    final ownSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('cameras')
        .where('isPublic', isEqualTo: true)
        .get();
    for (final d in ownSnap.docs) {
      addUnique(d);
    }

    try {
      final groupSnap = await _firestore
          .collectionGroup('cameras')
          .where('isPublic', isEqualTo: true)
          .get();
      for (final d in groupSnap.docs) {
        addUnique(d);
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        if (result.isEmpty) rethrow;
        // Mantém só as suas câmeras públicas; collectionGroup continua bloqueada pelas regras.
      } else {
        rethrow;
      }
    }

    return result;
  }

  Stream<List<Camera>> camerasStream() {
    if (_currentUserId == null) {
      return Stream.error(Exception('Usuário não autenticado'));
    }

    final uid = _currentUserId!;
    return _getUserCamerasCollection().snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => _cameraFromUserDoc(doc, uid))
          .toList();
    });
  }

  Future<void> _saveCacheLocal(List<Camera> cameras) async {
    final prefs = await SharedPreferences.getInstance();
    final camerasJson =
        cameras.map((camera) => jsonEncode(camera.toJson())).toList();
    await prefs.setStringList(_localCacheKey, camerasJson);
  }

  Future<List<Camera>> _getCachedCameras() async {
    final prefs = await SharedPreferences.getInstance();
    final camerasJson = prefs.getStringList(_localCacheKey) ?? [];
    return camerasJson
        .map((json) => Camera.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localCacheKey);
  }
}
