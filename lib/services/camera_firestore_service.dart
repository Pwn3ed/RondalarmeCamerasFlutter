import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/camera.dart';

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
  Future<List<Camera>> getAllCameras() async {
    try {
      if (_currentUserId == null) {
        return _getCachedCameras();
      }

      final snapshot = await _getUserCamerasCollection().get();
      final cameras = snapshot.docs
          .map((doc) => Camera.fromJson({...doc.data(), 'id': doc.id}))
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
    String? serverIp,
    int? serverPort,
    required String streamPath,
    required bool isManualMode,
  }) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      final camera = Camera(
        id: '',
        name: name,
        description: description,
        serverIp: serverIp,
        serverPort: serverPort,
        streamPath: streamPath,
        isManualMode: isManualMode,
        createdAt: DateTime.now(),
      );

      final docRef = await _getUserCamerasCollection()
          .add(camera.toJson());
      final cameraWithId = Camera(
        id: docRef.id,
        name: camera.name,
        description: camera.description,
        serverIp: camera.serverIp,
        serverPort: camera.serverPort,
        streamPath: camera.streamPath,
        isManualMode: camera.isManualMode,
        createdAt: camera.createdAt,
      );

      return cameraWithId;
    } catch (e) {
      rethrow;
    }
  }
  Future<void> updateCamera(Camera camera) async {
    if (_currentUserId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      await _getUserCamerasCollection()
          .doc(camera.id)
          .update(camera.toJson());
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
  Stream<List<Camera>> camerasStream() {
    if (_currentUserId == null) {
      return Stream.error(Exception('Usuário não autenticado'));
    }

    return _getUserCamerasCollection().snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Camera.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
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
        .map((json) => Camera.fromJson(jsonDecode(json)))
        .toList();
  }
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localCacheKey);
  }
}
