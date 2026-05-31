import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'create_user_screen.dart';
import 'user_admin_actions.dart';
import 'user_cameras_screen.dart';

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
                      '${u.mustChangePassword ? '\nTroca de senha pendente' : ''}'
                      '${!u.canToggleCameraPublic ? '\nVisibilidade pública bloqueada' : ''}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserCamerasScreen(user: u),
                        ),
                      );
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
