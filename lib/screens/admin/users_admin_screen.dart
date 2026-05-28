import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_log_service.dart';
import '../../services/session_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'create_user_screen.dart';

class UsersAdminScreen extends StatelessWidget {
  const UsersAdminScreen({super.key});

  Future<void> _refreshUsers(UserService userService) async {
    await userService.watchAll().first;
  }

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar usuários'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.primaryWhite,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateUserScreen()),
          );
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Usuário criado'),
                backgroundColor: AppTheme.lightGreen,
              ),
            );
          }
        },
        backgroundColor: AppTheme.lightGreen,
        child: const Icon(Icons.person_add, color: AppTheme.primaryWhite),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: userService.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            );
          }

          final users = snapshot.data ?? [];
          final clients = users.where((u) => !u.isAdmin).toList();

          if (clients.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refreshUsers(userService),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 300,
                    child: Center(child: Text('Nenhum usuário cadastrado')),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refreshUsers(userService),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final u = clients[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(u.displayName),
                    subtitle: Text(
                      '${u.email}\n'
                      'Máx. dispositivos: ${u.maxDevices}'
                      '${u.disabled ? '\nDESABILITADO' : ''}'
                      '${u.mustChangePassword ? '\nTroca de senha pendente' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) => _handleAction(context, u, action),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'force_change',
                          child: Text('Forçar troca de senha'),
                        ),
                        const PopupMenuItem(
                          value: 'reset_email',
                          child: Text('Enviar e-mail de reset'),
                        ),
                        PopupMenuItem(
                          value: u.disabled ? 'enable' : 'disable',
                          child: Text(u.disabled ? 'Reativar conta' : 'Desabilitar conta'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    AppUser user,
    String action,
  ) async {
    final userService = UserService();
    final sessionService = SessionService();
    final auditLog = AuditLogService();
    final auth = context.read<AuthProvider>();

    switch (action) {
      case 'force_change':
        await userService.setMustChangePassword(user.uid, true);
        await auditLog.log(
          action: 'force_change_set',
          targetUid: user.uid,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuário precisará trocar a senha no próximo login'),
              backgroundColor: AppTheme.lightGreen,
            ),
          );
        }
        break;
      case 'reset_email':
        final ok = await auth.resetPassword(user.email);
        if (ok) {
          await auditLog.log(
            action: 'reset_sent',
            targetUid: user.uid,
          );
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
        await userService.setDisabled(user.uid, true);
        await sessionService.revokeAllActiveForUser(
          user.uid,
          endReason: 'revoked_by_admin',
          revokedBy: auth.user?.uid,
        );
        await auditLog.log(
          action: 'user_disabled',
          targetUid: user.uid,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta desabilitada')),
          );
        }
        break;
      case 'enable':
        await userService.setDisabled(user.uid, false);
        await auditLog.log(
          action: 'user_enabled',
          targetUid: user.uid,
        );
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
}
