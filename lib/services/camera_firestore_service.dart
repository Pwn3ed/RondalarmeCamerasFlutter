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
    return map;
  }

  Camera _cameraFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Camera.fromJson({
      ...doc.data()!,
      'id': doc.id,
      'ownerId': doc.data()!['ownerId'] as String?,
    });
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
        snapshot = await _cameras
            .where('ownerId', isEqualTo: _currentUserId)
            .orderBy('createdAt', descending: true)
            .get();
      }

      final cameras = snapshot.docs.map(_cameraFromDoc).toList();
      if (!isAdmin) {
        await _saveCacheLocal(cameras);
      }
      return cameras;
    } catch (e) {
      if (!isAdmin) return _getCachedCameras();
      rethrow;
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
    required String ownerId,
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
      ownerId: ownerId,
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

    final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
    if (isAdmin) {
      stream = _cameras.orderBy('createdAt', descending: true).snapshots();
    } else {
      stream = _cameras
          .where('ownerId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }

    return stream.map(
      (snapshot) => snapshot.docs.map(_cameraFromDoc).toList(),
    );
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
