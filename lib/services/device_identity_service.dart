import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentity {
  final String deviceId;
  final String deviceLabel;
  final String platform;
  final String appVersion;

  const DeviceIdentity({
    required this.deviceId,
    required this.deviceLabel,
    required this.platform,
    required this.appVersion,
  });
}

class DeviceIdentityService {
  static const _deviceIdKey = 'device_identity_id';
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Uuid _uuid = const Uuid();

  Future<DeviceIdentity> getIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _uuid.v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final platform = _platformName();
    final deviceLabel = await _deviceLabel();

    return DeviceIdentity(
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      platform: platform,
      appVersion: packageInfo.version,
    );
  }

  String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }

  Future<String> _deviceLabel() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return '${info.brand} ${info.model}'.trim();
      }
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.utsname.machine;
      }
      if (Platform.isLinux) {
        final info = await _deviceInfo.linuxInfo;
        return info.prettyName;
      }
      if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        return info.model;
      }
      if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        return info.computerName;
      }
    } catch (_) {
      // fallback
    }
    return 'Dispositivo';
  }
}
