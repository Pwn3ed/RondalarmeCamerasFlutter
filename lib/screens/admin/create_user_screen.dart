import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user_role.dart';
import '../../services/admin_user_service.dart';
import '../../services/audit_log_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/password_generator.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminUserService = AdminUserService();
  final _auditLog = AuditLogService();

  UserRole _role = UserRole.user;
  int _maxDevices = 2;
  bool _isLoading = false;
  String? _createdPassword;

  bool get _isCreatingAdmin => _role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _regeneratePassword();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _regeneratePassword() {
    setState(() {
      _passwordController.text = generateTempPassword();
    });
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    final roleLabel = _isCreatingAdmin ? 'administrador' : 'cliente';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar criação'),
        content: Text(
          'Será criada uma conta de $roleLabel.\n\n'
          'Anote a senha temporária antes de continuar. '
          'Ela não poderá ser visualizada novamente após criar a conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar conta'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final result = await _adminUserService.createUser(
        email: _emailController.text.trim(),
        displayName: _displayNameController.text.trim(),
        role: _role,
        maxDevices: _isCreatingAdmin ? 5 : _maxDevices,
      );

      await _auditLog.log(
        action: 'user_created',
        targetUid: result.uid,
        metadata: {
          'email': _emailController.text.trim(),
          'role': _role.storageValue,
          'maxDevices': _isCreatingAdmin ? 5 : _maxDevices,
        },
      );

      if (!mounted) return;
      setState(() {
        _createdPassword = result.tempPassword;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar usuário: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_createdPassword != null) {
      return _buildSuccessView();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Criar usuário')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Digite o email';
                if (!v.contains('@')) return 'Email inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Tipo de conta',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(
                  value: UserRole.user,
                  label: Text('Cliente'),
                  icon: Icon(Icons.person_outline),
                ),
                ButtonSegment(
                  value: UserRole.admin,
                  label: Text('Administrador'),
                  icon: Icon(Icons.admin_panel_settings_outlined),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (selection) {
                setState(() => _role = selection.first);
              },
            ),
            if (_isCreatingAdmin) ...[
              const SizedBox(height: 8),
              Text(
                'Administradores têm acesso ao painel de gestão, câmeras e usuários.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Nome de exibição *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Digite o nome' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Senha temporária (gerada automaticamente)',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copiar',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _passwordController.text),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Senha copiada')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Regenerar',
                      onPressed: _regeneratePassword,
                    ),
                  ],
                ),
              ),
            ),
            if (!_isCreatingAdmin) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _maxDevices,
                decoration: const InputDecoration(
                  labelText: 'Máximo de dispositivos simultâneos',
                  prefixIcon: Icon(Icons.devices),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 dispositivo')),
                  DropdownMenuItem(value: 2, child: Text('2 dispositivos')),
                  DropdownMenuItem(value: 3, child: Text('3 dispositivos')),
                  DropdownMenuItem(value: 5, child: Text('5 dispositivos')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _maxDevices = v);
                },
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _createUser,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryWhite,
                      ),
                    )
                  : const Text('Criar conta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conta criada'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppTheme.lightGreen,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              'Conta criada com sucesso!',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isCreatingAdmin
                  ? 'Anote a senha temporária abaixo. O administrador precisará trocá-la no primeiro acesso.'
                  : 'Anote a senha temporária abaixo. O cliente precisará trocá-la no primeiro acesso.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                _createdPassword!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _createdPassword!));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Senha copiada')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar senha'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Concluído'),
            ),
          ],
        ),
      ),
    );
  }
}
