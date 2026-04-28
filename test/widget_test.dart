import 'package:flutter_test/flutter_test.dart';
import 'package:rondalarme_cameras_flutter/models/camera.dart';

void main() {
  test('Camera toJson/fromJson preserves isPublic and ownerId', () {
    final camera = Camera(
      id: 'cam1',
      name: 'Entrada',
      description: 'Porta principal',
      streamPath: 'http://example.com/stream.m3u8',
      isManualMode: true,
      isPublic: true,
      ownerId: 'user-uid',
      createdAt: DateTime.utc(2024, 6, 15, 12, 0),
    );

    final json = camera.toJson();
    expect(json['isPublic'], true);
    expect(json['ownerId'], 'user-uid');

    final restored = Camera.fromJson(json);
    expect(restored.id, 'cam1');
    expect(restored.isPublic, true);
    expect(restored.ownerId, 'user-uid');
    expect(restored.isManualMode, true);
  });

  test('Camera.fromJson defaults isPublic to false when absent', () {
    final restored = Camera.fromJson({
      'id': 'x',
      'name': 'n',
      'description': '',
      'streamPath': '/path',
      'isActive': true,
      'isManualMode': false,
      'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
    });
    expect(restored.isPublic, false);
    expect(restored.ownerId, isNull);
  });
}
