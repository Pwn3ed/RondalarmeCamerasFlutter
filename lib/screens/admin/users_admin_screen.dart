import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'create_user_screen.dart';
import 'edit_user_screen.dart';
import 'user_admin_actions.dart';

class UsersAdminScreen extends StatelessWidget {
  const UsersAdminScreen({super.key});

  Future<void> _refreshUsers(UserService userService) async {
    await userService.watchAll().first;
  }

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar usuários')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateUserScreen()),
          );
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Conta criada com sucesso'),
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

          if (users.isEmpty) {
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
              itemCount: users.length,
              itemBuilder: (context, index) {
                final u = users[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(u.displayName)),
                        if (u.isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.softGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                color: AppTheme.accentGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${u.email}\n'
                      '${u.isAdmin ? 'Administrador' : 'Máx. dispositivos: ${u.maxDevices}'}'
                      '${u.disabled ? '\nDESABILITADO' : ''}'
                      '${u.mustChangePassword ? '\nTroca de senha pendente' : ''}'
                      '${!u.canToggleCameraPublic ? '\nVisibilidade pública bloqueada' : ''}',
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditUserScreen(user: u),
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
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) =>
                          handleUserAdminAction(context, u, action),
                      itemBuilder: (_) => userAdminMenuItems(u),
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
}
