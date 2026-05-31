import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import 'cameras_list_screen.dart';
import 'force_password_change_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _syncedAdminMode = false;
  bool _removedNativeSplash = false;

  void _removeNativeSplashOnce() {
    if (_removedNativeSplash) return;
    _removedNativeSplash = true;
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CameraProvider>(
      builder: (context, authProvider, cameraProvider, child) {
        if (authProvider.isBootstrapping) {
          return const SplashScreen();
        }

        _removeNativeSplashOnce();

        if (!authProvider.isAuthenticated) {
          if (_syncedAdminMode) {
            _syncedAdminMode = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              cameraProvider.setAdminMode(false);
            });
          }
          return const LoginScreen();
        }

        final isAdmin = authProvider.isAdmin;
        if (_syncedAdminMode != isAdmin) {
          _syncedAdminMode = isAdmin;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            cameraProvider.setAdminMode(isAdmin);
          });
        }

        if (authProvider.mustChangePassword) {
          return const ForcePasswordChangeScreen();
        }

        return const CamerasListScreen();
      },
    );
  }
}
