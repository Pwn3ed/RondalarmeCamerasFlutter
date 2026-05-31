import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Armazena localmente a última miniatura capturada de cada câmera.
class CameraPreviewCacheService extends ChangeNotifier {
  CameraPreviewCacheService._();

  static final CameraPreviewCacheService instance = CameraPreviewCacheService._();

  Directory? _directory;

  Future<Directory> _previewDirectory() async {
    if (_directory != null) return _directory!;
    final base = await getApplicationSupportDirectory();
    _directory = Directory('${base.path}/camera_previews');
    if (!_directory!.existsSync()) {
      await _directory!.create(recursive: true);
    }
    return _directory!;
  }

  Future<File> _fileFor(String cameraId) async {
    final dir = await _previewDirectory();
    return File('${dir.path}/$cameraId.jpg');
  }

  Future<File?> getPreviewFile(String cameraId) async {
    if (kIsWeb) return null;
    final file = await _fileFor(cameraId);
    return file.existsSync() ? file : null;
  }

  Future<void> save(String cameraId, Uint8List bytes) async {
    if (kIsWeb || bytes.isEmpty) return;
    final file = await _fileFor(cameraId);
    await file.writeAsBytes(bytes, flush: true);
    notifyListeners();
  }

  Future<void> clear(String cameraId) async {
    if (kIsWeb) return;
    final file = await _fileFor(cameraId);
    if (file.existsSync()) {
      await file.delete();
      notifyListeners();
    }
  }
}
