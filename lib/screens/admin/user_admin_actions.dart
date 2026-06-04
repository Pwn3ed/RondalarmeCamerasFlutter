import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_log_service.dart';
import '../../services/session_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'edit_user_screen.dart';
import 'user_cameras_screen.dart';

List<PopupMenuItem<String>> userAdminMenuItems(
  AppUser user, {
  bool includeCamerasAction = true,
}) {
  return [
    const PopupMenuItem(
      value: 'edit',
      child: Text('Editar usuário'),
    ),
    if (includeCamerasAction)
      const PopupMenuItem(
        value: 'cameras',
        child: Text('Câmeras com acesso'),
      ),
    PopupMenuItem(
      value: user.canToggleCameraPublic
          ? 'block_public_toggle'
          : 'unblock_public_toggle',
      child: Text(
        user.canToggleCameraPublic
            ? 'Bloquear visibilidade pública'
            : 'Permitir visibilidade pública',
      ),
    ),
    const PopupMenuItem(
      value: 'force_change',
      child: Text('Forçar troca de senha'),
    ),
    const PopupMenuItem(
      value: 'reset_email',
      child: Text('Enviar e-mail de reset'),
    ),
    PopupMenuItem(
      value: user.disabled ? 'enable' : 'disable',
      child: Text(user.disabled ? 'Reativar conta' : 'Desabilitar conta'),
    ),
  ];
}

Future<void> handleUserAdminAction(
  BuildContext context,
  AppUser user,
  String action, {
  bool includeCamerasNavigation = true,
}) async {
  final userService = UserService();
  final sessionService = SessionService();
  final auditLog = AuditLogService();
  final auth = context.read<AuthProvider>();

  switch (action) {
    case 'edit':
      if (context.mounted) {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => EditUserScreen(user: user),
          ),
        );
        if (updated == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuário atualizado'),
              backgroundColor: AppTheme.lightGreen,
            ),
          );
        }
      }
      break;
    case 'cameras':
      if (!includeCamerasNavigation) return;
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserCamerasScreen(user: user),
          ),
        );
      }
      break;
    case 'block_public_toggle':
      await userService.setCanToggleCameraPublic(
        user.uid,
        allowed: false,
        blockedReason: 'admin',
      );
      await auditLog.log(
        action: 'public_toggle_blocked_by_admin',
        targetUid: user.uid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Usuário não pode mais alterar visibilidade pública',
            ),
          ),
        );
      }
      break;
    case 'unblock_public_toggle':
      await userService.setCanToggleCameraPublic(user.uid, allowed: true);
      await auditLog.log(
        action: 'public_toggle_unblocked_by_admin',
        targetUid: user.uid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visibilidade pública liberada para o usuário'),
            backgroundColor: AppTheme.lightGreen,
          ),
        );
      }
      break;
    case 'force_change':
      await userService.setMustChangePassword(user.uid, true);
      await auditLog.log(action: 'force_change_set', targetUid: user.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Usuário precisará trocar a senha no próximo login',
            ),
            backgroundColor: AppTheme.lightGreen,
          ),
        );
      }
      break;
    case 'reset_email':
      final ok = await auth.resetPassword(user.email);
      if (ok) {
        await auditLog.log(action: 'reset_sent', targetUid: user.uid);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'E-mail de reset enviado' : auth.errorMessage ?? 'Erro',
            ),
            backgroundColor: ok ? AppTheme.lightGreen : Colors.red,
          ),
        );
      }
      break;
    case 'disable':
      final currentUid = auth.user?.uid;
      if (currentUid == user.uid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você não pode desabilitar sua própria conta.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;
      }
      await userService.setDisabled(user.uid, true);
      await sessionService.revokeAllActiveForUser(
        user.uid,
        endReason: 'revoked_by_admin',
        revokedBy: auth.user?.uid,
      );
      await auditLog.log(action: 'user_disabled', targetUid: user.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Conta desabilitada')));
      }
      break;
    case 'enable':
      await userService.setDisabled(user.uid, false);
      await auditLog.log(action: 'user_enabled', targetUid: user.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta reativada'),
            backgroundColor: AppTheme.lightGreen,
          ),
        );
      }
      break;
  }
}
