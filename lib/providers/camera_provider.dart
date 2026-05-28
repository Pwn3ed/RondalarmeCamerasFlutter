import 'package:flutter/foundation.dart';

import '../models/camera.dart';
import '../models/camera_protocol.dart';
import '../services/camera_firestore_service.dart';

class CameraProvider with ChangeNotifier {
  final CameraFirestoreService _cameraService = CameraFirestoreService();
  List<Camera> _cameras = [];
  List<Camera> _publicCameras = [];
  bool _isLoading = false;
  bool _isLoadingPublic = false;
  String? _publicCamerasError;
  bool _isAdmin = false;

  List<Camera> get cameras => _cameras;
  List<Camera> get publicCameras => _publicCameras;
  bool get isLoading => _isLoading;
  bool get isLoadingPublic => _isLoadingPublic;
  String? get publicCamerasError => _publicCamerasError;

  void setAdminMode(bool isAdmin) {
    if (_isAdmin == isAdmin) return;
    _isAdmin = isAdmin;
    _cameras = [];
    _publicCameras = [];
    notifyListeners();
  }

  Future<void> loadCameras() async {
    _isLoading = true;
    notifyListeners();

    try {
      _cameras = await _cameraService.getAllCameras(isAdmin: _isAdmin);
    } catch (e) {
      _cameras = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPublicCameras() async {
    _isLoadingPublic = true;
    notifyListeners();

    try {
      _publicCamerasError = null;
      _publicCameras = await _cameraService.getPublicCameras();
      _publicCameras.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      _publicCameras = [];
      _publicCamerasError = e.toString();
    } finally {
      _isLoadingPublic = false;
      notifyListeners();
    }
  }

  Future<void> addCamera({
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
    final camera = await _cameraService.addCamera(
      name: name,
      description: description,
      protocol: protocol,
      serverIp: serverIp,
      serverPort: serverPort,
      streamPath: streamPath,
      rtspUrl: rtspUrl,
      isManualMode: isManualMode,
      isPublic: isPublic,
      ownerId: ownerId,
    );

    _cameras.insert(0, camera);
    notifyListeners();
  }

  Future<void> updateCamera(Camera camera) async {
    await _cameraService.updateCamera(camera);
    final index = _cameras.indexWhere((c) => c.id == camera.id);

    if (index != -1) {
      _cameras[index] = camera;
      notifyListeners();
    }

    final pubIndex = _publicCameras.indexWhere((c) => c.id == camera.id);
    if (pubIndex != -1) {
      if (camera.isPublic) {
        _publicCameras[pubIndex] = camera;
      } else {
        _publicCameras.removeAt(pubIndex);
      }
      notifyListeners();
    } else if (camera.isPublic) {
      _publicCameras.add(camera);
      _publicCameras.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
  }

  Future<void> deleteCamera(String id) async {
    await _cameraService.deleteCamera(id);
    _cameras.removeWhere((camera) => camera.id == id);
    _publicCameras.removeWhere((camera) => camera.id == id);
    notifyListeners();
  }

  Future<void> toggleCameraStatus(String id) async {
    await _cameraService.toggleCameraStatus(id);
    final index = _cameras.indexWhere((c) => c.id == id);

    if (index != -1) {
      _cameras[index] = _cameras[index].copyWith(
        isActive: !_cameras[index].isActive,
      );
      notifyListeners();
    }
  }

  Camera? getCameraById(String id) {
    try {
      return _cameras.firstWhere((camera) => camera.id == id);
    } catch (e) {
      return null;
    }
  }

  Stream<List<Camera>> watchCameras() {
    return _cameraService.camerasStream(isAdmin: _isAdmin);
  }

  Future<void> clearCache() async {
    await _cameraService.clearCache();
    _cameras = [];
    _publicCameras = [];
    notifyListeners();
  }
}
