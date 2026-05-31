import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';
import 'admin/audit_logs_screen.dart';
import 'admin/sessions_admin_screen.dart';
import 'admin/users_admin_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String _flutterVersion = '3.35.5';

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair da conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirm != true) return;

    final cameraProvider = context.read<CameraProvider>();
    final authProvider = context.read<AuthProvider>();
    await authProvider.signOut(cameraProvider);
  }

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appUser = auth.appUser;
    final isAdmin = auth.isAdmin;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        _ProfileHeader(
          displayName: appUser?.displayName ?? 'Usuário',
          email: appUser?.email ?? auth.user?.email ?? '—',
          isAdmin: isAdmin,
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'Conta',
          children: [
            _SettingsTile(
              icon: Icons.lock_outline,
              title: 'Alterar senha',
              subtitle: 'Atualize sua senha de acesso',
              onTap: () => _openScreen(context, const ChangePasswordScreen()),
            ),
            _SettingsTile(
              icon: Icons.devices,
              title: 'Limite de dispositivos',
              subtitle: '${appUser?.maxDevices ?? 2} aparelhos simultâneos',
              showChevron: false,
            ),
          ],
        ),
        if (isAdmin) ...[
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Administração',
            children: [
              _SettingsTile(
                icon: Icons.group_outlined,
                title: 'Usuários',
                subtitle: 'Cadastro, perfis e permissões',
                onTap: () => _openScreen(context, const UsersAdminScreen()),
              ),
              _SettingsTile(
                icon: Icons.devices_other_outlined,
                title: 'Sessões',
                subtitle: 'Aparelhos conectados e encerramentos',
                onTap: () => _openScreen(context, const SessionsAdminScreen()),
              ),
              _SettingsTile(
                icon: Icons.receipt_long_outlined,
                title: 'Logs de auditoria',
                subtitle: 'Histórico de ações no sistema',
                onTap: () => _openScreen(context, const AuditLogsScreen()),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Sobre',
          children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '—';
                final build = snapshot.data?.buildNumber ?? '—';
                return _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'Versão do app',
                  subtitle: '$version ($build)',
                  showChevron: false,
                );
              },
            ),
            const _SettingsTile(
              icon: Icons.code,
              title: 'Versão do Flutter',
              subtitle: _flutterVersion,
              showChevron: false,
            ),
          ],
        ),
        const SizedBox(height: 32),
        _SignOutButton(
          isLoading: auth.isLoading,
          onPressed: () => _confirmSignOut(context),
        ),
      ],
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SignOutButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEF5350),
          disabledForegroundColor: AppTheme.textMuted,
          side: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.logout, size: 22),
        label: const Text(
          'Sair da conta',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final bool isAdmin;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.softGreen,
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: AppTheme.accentGreen,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(isAdmin ? 'Administrador' : 'Usuário'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showChevron;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: iconColor ?? AppTheme.accentGreen),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: showChevron && enabled
          ? Icon(Icons.chevron_right, color: AppTheme.textMuted)
          : null,
      onTap: onTap,
    );
  }
}
