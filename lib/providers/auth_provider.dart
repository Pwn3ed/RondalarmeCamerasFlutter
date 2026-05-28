import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/audit_log_service.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import 'camera_provider.dart';

enum SignInResult {
  success,
  accountNotEnabled,
  accountDisabled,
  needsDeviceKick,
  error,
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final SessionService _sessionService = SessionService();
  final AuditLogService _auditLog = AuditLogService();

  User? _user;
  AppUser? _appUser;
  bool _isLoading = false;
  bool _isBootstrapping = true;
  String? _errorMessage;
  String? _pendingSessionId;

  User? get user => _user;
  AppUser? get appUser => _appUser;
  bool get isLoading => _isLoading;
  bool get isBootstrapping => _isBootstrapping;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null && _appUser != null;
  bool get isAdmin => _appUser?.isAdmin ?? false;
  bool get mustChangePassword => _appUser?.mustChangePassword ?? false;

  SessionService get sessionService => _sessionService;

  AuthProvider() {
    _sessionService.onSessionRevoked = _onSessionRevoked;
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user == null) {
      _appUser = null;
      _pendingSessionId = null;
      _isBootstrapping = false;
      notifyListeners();
      return;
    }

    try {
      await _loadAppUser(user.uid);
      if (_appUser == null || _appUser!.disabled) {
        await _authService.signOut();
        _appUser = null;
        _user = null;
      } else if (_pendingSessionId == null && !_sessionService.hasActiveSession) {
        await _sessionService.startSession(user.uid);
      }
    } catch (_) {
      _appUser = null;
    }
    _isBootstrapping = false;
    notifyListeners();
  }

  Future<void> _onSessionRevoked(String reason) async {
    await _auditLog.log(
      action: 'logout',
      metadata: {'reason': reason, 'revoked': true},
    );
    await _authService.signOut();
    _errorMessage = 'Sua sessão foi encerrada. Faça login novamente.';
    notifyListeners();
  }

  Future<void> _loadAppUser(String uid) async {
    final appUser = await _userService.getByUid(uid);
    _appUser = appUser;
  }

  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cred = await _authService.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      final appUser = await _userService.getByUid(uid);
      if (appUser == null) {
        await _auditLog.log(action: 'login_blocked', metadata: {'reason': 'no_profile'});
        await _authService.signOut();
        _errorMessage = 'Conta não habilitada. Procure o administrador.';
        _isLoading = false;
        notifyListeners();
        return SignInResult.accountNotEnabled;
      }

      if (appUser.disabled) {
        await _auditLog.log(
          action: 'login_blocked',
          targetUid: uid,
          metadata: {'reason': 'disabled'},
        );
        await _authService.signOut();
        _errorMessage = 'Esta conta foi desabilitada.';
        _isLoading = false;
        notifyListeners();
        return SignInResult.accountDisabled;
      }

      _appUser = appUser;
      _user = cred.user;

      await _userService.updateLastLogin(uid);

      final sessionId = await _sessionService.startSession(uid);
      _pendingSessionId = sessionId;

      final activeCount = await _sessionService.countActiveSessions(uid);
      if (activeCount > appUser.maxDevices) {
        await _auditLog.log(
          action: 'multi_device_warning',
          targetUid: uid,
          targetSessionId: sessionId,
          metadata: {
            'activeSessionsCount': activeCount,
            'maxDevices': appUser.maxDevices,
          },
        );
        _isLoading = false;
        notifyListeners();
        return SignInResult.needsDeviceKick;
      }

      await _auditLog.log(
        action: 'login',
        targetSessionId: sessionId,
      );

      _pendingSessionId = null;
      _isLoading = false;
      notifyListeners();
      return SignInResult.success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return SignInResult.error;
    }
  }

  Future<bool> kickOldestDeviceAndContinue() async {
    final uid = _user?.uid;
    final sessionId = _pendingSessionId;
    if (uid == null || sessionId == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final oldest = await _sessionService.getOldestActiveSession(
        uid,
        excludeSessionId: sessionId,
      );
      if (oldest != null) {
        await _sessionService.endSessionById(
          oldest.id,
          endReason: 'replaced_by_newer',
        );
        await _auditLog.log(
          action: 'session_revoked',
          targetUid: uid,
          targetSessionId: oldest.id,
          metadata: {'reason': 'replaced_by_newer'},
        );
      }

      await _auditLog.log(
        action: 'login',
        targetSessionId: sessionId,
      );

      _pendingSessionId = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> cancelPendingSignIn() async {
    await _sessionService.stopSession(endReason: 'login_cancelled');
    await _authService.signOut();
    _pendingSessionId = null;
    _appUser = null;
    _user = null;
    notifyListeners();
  }

  Future<bool> changePasswordAndClearFlag({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final email = _user?.email ?? _appUser?.email ?? '';
      await _authService.reauthenticate(email: email, password: currentPassword);
      await _authService.updatePassword(newPassword);
      final uid = _user!.uid;
      await _userService.clearMustChangePassword(uid);
      _appUser = _appUser?.copyWith(mustChangePassword: false);
      await _auditLog.log(action: 'password_changed', targetUid: uid);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut(CameraProvider? cameraProvider) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auditLog.log(action: 'logout');
      await _sessionService.stopSession(endReason: 'logout');
      await cameraProvider?.clearCache();
      await _authService.signOut();
      _appUser = null;
      _user = null;
      _pendingSessionId = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshAppUser() async {
    final uid = _user?.uid;
    if (uid == null) return;
    await _loadAppUser(uid);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionService.dispose();
    super.dispose();
  }
}
