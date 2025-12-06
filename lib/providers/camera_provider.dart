import 'package:flutter/foundation.dart';
import '../models/camera.dart';
import '../services/camera_firestore_service.dart';

class CameraProvider with ChangeNotifier {
  final CameraFirestoreService _cameraService = CameraFirestoreService();
  List<Camera> _cameras = [];
  bool _isLoading = false;

  List<Camera> get cameras => _cameras;
  bool get isLoading => _isLoading;

  Future<void> loadCameras() async {
    _isLoading = true;
    notifyListeners();

    try {
      _cameras = await _cameraService.getAllCameras();
    } catch (e) {
      _cameras = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCamera({
    required String name,
    required String description,
    String? serverIp,
    int? serverPort,
    required String streamPath,
    required bool isManualMode,
  }) async {
    try {
      final camera = await _cameraService.addCamera(
        name: name,
        description: description,
        serverIp: serverIp,
        serverPort: serverPort,
        streamPath: streamPath,
        isManualMode: isManualMode,
      );
      
      _cameras.add(camera);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCamera(Camera camera) async {
    try {
      await _cameraService.updateCamera(camera);
      final index = _cameras.indexWhere((c) => c.id == camera.id);
      
      if (index != -1) {
        _cameras[index] = camera;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCamera(String id) async {
    try {
      await _cameraService.deleteCamera(id);
      _cameras.removeWhere((camera) => camera.id == id);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleCameraStatus(String id) async {
    try {
      await _cameraService.toggleCameraStatus(id);
      final index = _cameras.indexWhere((c) => c.id == id);
      
      if (index != -1) {
        _cameras[index] = _cameras[index].copyWith(
          isActive: !_cameras[index].isActive,
        );
        notifyListeners();
      }
    } catch (e) {
      rethrow;
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
    return _cameraService.camerasStream();
  }
  Future<void> clearCache() async {
    await _cameraService.clearCache();
    _cameras = [];
    notifyListeners();
  }
}
