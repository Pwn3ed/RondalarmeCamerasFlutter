import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/camera.dart';
import '../models/camera_protocol.dart';

class CameraService {
  static const String _storageKey = 'cameras';
  final Uuid _uuid = const Uuid();

  Future<List<Camera>> getAllCameras() async {
    final prefs = await SharedPreferences.getInstance();
    final camerasJson = prefs.getStringList(_storageKey) ?? [];

    return camerasJson
        .map((json) => Camera.fromJson(jsonDecode(json)))
        .toList();
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
  }) async {
    final camera = Camera(
      id: _uuid.v4(),
      name: name,
      description: description,
      protocol: protocol,
      serverIp: serverIp,
      serverPort: serverPort,
      streamPath: streamPath,
      rtspUrl: rtspUrl?.trim().isEmpty == true ? null : rtspUrl?.trim(),
      isManualMode: isManualMode,
      isPublic: false,
      createdAt: DateTime.now(),
    );

    final cameras = await getAllCameras();
    cameras.add(camera);

    await _saveCameras(cameras);
    return camera;
  }

  Future<void> updateCamera(Camera camera) async {
    final cameras = await getAllCameras();
    final index = cameras.indexWhere((c) => c.id == camera.id);

    if (index != -1) {
      cameras[index] = camera;
      await _saveCameras(cameras);
    }
  }

  Future<void> deleteCamera(String id) async {
    final cameras = await getAllCameras();
    cameras.removeWhere((camera) => camera.id == id);
    await _saveCameras(cameras);
  }

  Future<void> toggleCameraStatus(String id) async {
    final cameras = await getAllCameras();
    final index = cameras.indexWhere((c) => c.id == id);

    if (index != -1) {
      cameras[index] = cameras[index].copyWith(
        isActive: !cameras[index].isActive,
      );
      await _saveCameras(cameras);
    }
  }

  Future<void> _saveCameras(List<Camera> cameras) async {
    final prefs = await SharedPreferences.getInstance();
    final camerasJson = cameras
        .map((camera) => jsonEncode(camera.toJson()))
        .toList();

    await prefs.setStringList(_storageKey, camerasJson);
  }
}
