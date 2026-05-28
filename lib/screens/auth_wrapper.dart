import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';
import 'cameras_list_screen.dart';
import 'force_password_change_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _syncedAdminMode = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CameraProvider>(
      builder: (context, authProvider, cameraProvider, child) {
        if (authProvider.isBootstrapping) {
          return const Scaffold(
            backgroundColor: AppTheme.offWhite,
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            ),
          );
        }

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
