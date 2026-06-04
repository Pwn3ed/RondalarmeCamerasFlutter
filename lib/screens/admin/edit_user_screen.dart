import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_log_service.dart';
import '../../services/session_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_outlined_action_button.dart';
import 'user_cameras_screen.dart';

class EditUserScreen extends StatefulWidget {
  final AppUser user;

  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _auditLog = AuditLogService();

  late final TextEditingController _displayNameController;

  late UserRole _role;
  late int _maxDevices;
  late bool _disabled;
  late bool _canToggleCameraPublic;
  bool _isLoading = false;

  bool get _isClientRole => _role == UserRole.user;

  @override
  void initState() {
    super.initState();
    final isAdmin = context.read<AuthProvider>().isAdmin;
    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    final u = widget.user;
    _displayNameController = TextEditingController(text: u.displayName);
    _role = u.role;
    _maxDevices = u.maxDevices;
    _disabled = u.disabled;
    _canToggleCameraPublic = u.canToggleCameraPublic;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  bool _isEditingSelf(BuildContext context) {
    final currentUid = context.read<AuthProvider>().user?.uid;
    return currentUid != null && currentUid == widget.user.uid;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isSelf = _isEditingSelf(context);
    if (isSelf && _role != UserRole.admin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não pode remover seu próprio acesso de administrador.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (isSelf && _disabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não pode desabilitar sua própria conta.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final adminUid = context.read<AuthProvider>().user?.uid;
    final wasDisabled = widget.user.disabled;

    try {
      await _userService.updateUser(
        uid: widget.user.uid,
        displayName: _displayNameController.text.trim(),
        role: _role,
        maxDevices: _isClientRole ? _maxDevices : 5,
        disabled: _disabled,
        canToggleCameraPublic: _canToggleCameraPublic,
      );

      if (_disabled && !wasDisabled) {
        await SessionService().revokeAllActiveForUser(
          widget.user.uid,
          endReason: 'revoked_by_admin',
          revokedBy: adminUid,
        );
        await _auditLog.log(
          action: 'user_disabled',
          targetUid: widget.user.uid,
        );
      } else if (!_disabled && wasDisabled) {
        await _auditLog.log(
          action: 'user_enabled',
          targetUid: widget.user.uid,
        );
      }

      await _auditLog.log(
        action: 'user_updated',
        targetUid: widget.user.uid,
        metadata: {
          'role': _role.storageValue,
          'maxDevices': _isClientRole ? _maxDevices : 5,
          'disabled': _disabled,
          'canToggleCameraPublic': _canToggleCameraPublic,
        },
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar usuário: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = _isEditingSelf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar usuário')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome *',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Digite o nome' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: widget.user.email,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<UserRole>(
                        segments: const [
                          ButtonSegment(
                            value: UserRole.user,
                            label: Text('Cliente'),
                          ),
                          ButtonSegment(
                            value: UserRole.admin,
                            label: Text('Admin'),
                          ),
                        ],
                        selected: {_role},
                        onSelectionChanged: isSelf
                            ? null
                            : (selection) {
                                setState(() => _role = selection.first);
                              },
                      ),
                      if (_isClientRole) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _maxDevices,
                          decoration: const InputDecoration(
                            labelText: 'Dispositivos',
                            prefixIcon: Icon(Icons.devices),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1')),
                            DropdownMenuItem(value: 2, child: Text('2')),
                            DropdownMenuItem(value: 3, child: Text('3')),
                            DropdownMenuItem(value: 5, child: Text('5')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _maxDevices = v);
                          },
                        ),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Visibilidade pública'),
                        value: _canToggleCameraPublic,
                        onChanged: (v) =>
                            setState(() => _canToggleCameraPublic = v),
                        activeThumbColor: AppTheme.primaryGreen,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Desabilitado'),
                        value: _disabled,
                        onChanged: isSelf
                            ? null
                            : (v) => setState(() => _disabled = v),
                        activeThumbColor: AppTheme.primaryGreen,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isClientRole) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.videocam_outlined,
                      color: AppTheme.accentGreen,
                    ),
                    title: const Text('Câmeras'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserCamerasScreen(user: widget.user),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AppOutlinedActionButton(
                label: 'Salvar',
                icon: Icons.save_outlined,
                color: AppTheme.primaryGreen,
                isLoading: _isLoading,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
