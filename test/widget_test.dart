import 'package:flutter_test/flutter_test.dart';
import 'package:rondalarme_cameras_flutter/models/camera.dart';
import 'package:rondalarme_cameras_flutter/models/camera_protocol.dart';
import 'package:rondalarme_cameras_flutter/models/app_user.dart';
import 'package:rondalarme_cameras_flutter/models/user_role.dart';
import 'package:rondalarme_cameras_flutter/utils/camera_permissions.dart';

void main() {
  test('Camera toJson/fromJson preserves isPublic and assignedUserIds', () {
    final camera = Camera(
      id: 'cam1',
      name: 'Entrada',
      description: 'Porta principal',
      streamPath: 'http://example.com/stream.m3u8',
      isManualMode: true,
      isPublic: true,
      assignedUserIds: ['user-a', 'user-b'],
      createdAt: DateTime.utc(2024, 6, 15, 12, 0),
    );

    final json = camera.toJson();
    expect(json['isPublic'], true);
    expect(json['assignedUserIds'], ['user-a', 'user-b']);
    expect(json['protocol'], 'hls');
    expect(json.containsKey('ownerId'), false);

    final restored = Camera.fromJson(json);
    expect(restored.id, 'cam1');
    expect(restored.isPublic, true);
    expect(restored.assignedUserIds, ['user-a', 'user-b']);
    expect(restored.hasAccess('user-a'), isTrue);
    expect(restored.protocol, CameraProtocol.hls);
  });

  test('Camera.fromJson migrates legacy ownerId into assignedUserIds', () {
    final restored = Camera.fromJson({
      'id': 'x',
      'name': 'n',
      'description': '',
      'streamPath': '/path',
      'ownerId': 'legacy-user',
      'isActive': true,
      'isManualMode': false,
      'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
    });
    expect(restored.assignedUserIds, isEmpty);
    expect(restored.effectiveAssignedUserIds, ['legacy-user']);
    expect(restored.hasAccess('legacy-user'), isTrue);
  });

  test('Camera RTSP protocol uses rtspPlaybackUrl only', () {
    const url = 'rtsp://admin:pass@10.0.0.1:554/stream';
    final camera = Camera(
      id: 'cam2',
      name: 'Garagem',
      description: '',
      protocol: CameraProtocol.rtsp,
      streamPath: url,
      rtspUrl: url,
      createdAt: DateTime.utc(2024, 6, 15),
    );

    expect(camera.usesRtsp, isTrue);
    expect(camera.streamUrl, url);
    expect(camera.rtspPlaybackUrl, url);

    final restored = Camera.fromJson(camera.toJson());
    expect(restored.protocol, CameraProtocol.rtsp);
    expect(restored.usesRtsp, isTrue);
  });

  test('Camera.fromJson infers RTSP when only rtspUrl is set', () {
    final restored = Camera.fromJson({
      'id': 'x',
      'name': 'n',
      'description': '',
      'streamPath': '',
      'rtspUrl': 'rtsp://192.168.0.5:554/live',
      'isActive': true,
      'isManualMode': false,
      'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
    });
    expect(restored.protocol, CameraProtocol.rtsp);
  });

  test('Camera HTTP file protocol uses stream URL directly', () {
    const url = 'http://192.168.1.5:8080/video.mkv';
    final camera = Camera(
      id: 'cam3',
      name: 'Teste MP4',
      description: '',
      protocol: CameraProtocol.httpFile,
      streamPath: url,
      createdAt: DateTime.utc(2024, 7, 1),
    );

    expect(camera.usesHttpFile, isTrue);
    expect(camera.streamUrl, url);
    expect(camera.usesMediaKitPlayer, isTrue);
    expect(camera.usesExoPlayer, isFalse);

    final restored = Camera.fromJson(camera.toJson());
    expect(restored.protocol, CameraProtocol.httpFile);
    expect(restored.streamUrl, url);
  });

  test('Camera.fromJson infers http_file from mp4 URL', () {
    final restored = Camera.fromJson({
      'id': 'x',
      'name': 'n',
      'description': '',
      'streamPath': 'https://cdn.example.com/clip.mp4',
      'isActive': true,
      'isManualMode': false,
      'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
    });
    expect(restored.protocol, CameraProtocol.httpFile);
  });

  test('Camera HLS protocol uses media_kit and builds Intelbras URL', () {
    final camera = Camera(
      id: 'cam4',
      name: 'Portao',
      description: '',
      protocol: CameraProtocol.hls,
      serverIp: '192.168.0.1',
      serverPort: 8888,
      streamPath: 'app/test',
      createdAt: DateTime.utc(2024, 6, 15),
    );

    expect(camera.usesMediaKitPlayer, isTrue);
    expect(camera.usesExoPlayer, isFalse);
    expect(
      camera.streamUrl,
      'http://192.168.0.1:8888/app/test/video1_stream.m3u8',
    );
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
    expect(restored.isUnassigned, isTrue);
    expect(restored.protocol, CameraProtocol.hls);
  });

  test('AppUser defaults canToggleCameraPublic to true', () {
    const user = AppUser(
      uid: 'u1',
      email: 'a@b.com',
      displayName: 'Cliente',
      role: UserRole.user,
    );
    expect(user.canToggleCameraPublic, isTrue);
    expect(publicToggleBlockedMessage(user), isNull);
  });

  test('publicToggleBlockedMessage explains auto and admin blocks', () {
    const autoBlocked = AppUser(
      uid: 'u1',
      email: 'a@b.com',
      displayName: 'Cliente',
      role: UserRole.user,
      canToggleCameraPublic: false,
      publicToggleBlockedReason: 'auto',
    );
    const adminBlocked = AppUser(
      uid: 'u2',
      email: 'b@b.com',
      displayName: 'Cliente',
      role: UserRole.user,
      canToggleCameraPublic: false,
      publicToggleBlockedReason: 'admin',
    );
    expect(
      publicToggleBlockedMessage(autoBlocked),
      contains('uso excessivo'),
    );
    expect(
      publicToggleBlockedMessage(adminBlocked),
      contains('administrador'),
    );
  });
}
