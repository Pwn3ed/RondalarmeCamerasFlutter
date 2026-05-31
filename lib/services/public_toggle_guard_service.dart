import 'audit_log_service.dart';
import 'user_service.dart';

/// Detecta alternâncias excessivas de visibilidade pública e bloqueia o cliente.
class PublicToggleGuardService {
  static const int maxTogglesInWindow = 10;
  static const Duration window = Duration(minutes: 15);

  final AuditLogService _auditLog = AuditLogService();
  final UserService _userService = UserService();

  /// Registra o toggle e retorna `false` se o usuário foi bloqueado automaticamente.
  /// Falhas de auditoria/contagem não propagam erro — o toggle da câmera já foi salvo.
  Future<bool> recordClientToggle({
    required String uid,
    required String cameraId,
    required bool isPublic,
  }) async {
    try {
      await _auditLog.log(
        action: 'camera_public_toggled',
        targetCameraId: cameraId,
        metadata: {'isPublic': isPublic, 'byClient': true},
      );

      final recent = await _auditLog.fetchRecent(
        limit: 30,
        actorUidFilter: uid,
      );
      final cutoff = DateTime.now().subtract(window);
      final togglesInWindow = recent
          .where((entry) => entry.action == 'camera_public_toggled')
          .where((entry) => entry.createdAt.isAfter(cutoff))
          .length;

      if (togglesInWindow < maxTogglesInWindow) return true;

      await _userService.setCanToggleCameraPublic(
        uid,
        allowed: false,
        blockedReason: 'auto',
      );
      await _auditLog.log(
        action: 'public_toggle_auto_blocked',
        targetUid: uid,
        metadata: {
          'togglesInWindow': togglesInWindow,
          'windowMinutes': window.inMinutes,
        },
      );
      return false;
    } catch (_) {
      return true;
    }
  }
}
