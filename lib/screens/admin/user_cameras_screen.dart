import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/camera.dart';
import '../../services/audit_log_service.dart';
import '../../services/camera_firestore_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_camera_picker_sheet.dart';
import 'user_admin_actions.dart';

/// Câmeras atribuídas a um usuário — gestão de acesso pelo admin.
class UserCamerasScreen extends StatefulWidget {
  final AppUser user;

  const UserCamerasScreen({super.key, required this.user});

  @override
  State<UserCamerasScreen> createState() => _UserCamerasScreenState();
}

class _UserCamerasScreenState extends State<UserCamerasScreen> {
  final _service = CameraFirestoreService();
  final _auditLog = AuditLogService();
  final _userService = UserService();

  List<Camera> _cameras = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cameras = await _service.getCamerasForUser(widget.user.uid);
      if (mounted) {
        setState(() {
          _cameras = cameras;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _addCameras() async {
    try {
      final allCameras = await _service.getAllCameras(isAdmin: true);
      final available = allCameras
          .where((camera) => !camera.hasAccess(widget.user.uid))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;

      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este usuário já tem acesso a todas as câmeras.'),
          ),
        );
        return;
      }

      final selected = await showUserCameraPickerSheet(
        context: context,
        cameras: available,
        initialSelection: const {},
        title: 'Adicionar câmeras',
      );

      if (selected == null || selected.isEmpty || !mounted) return;

      await _service.grantUserCameraAccess(
        userId: widget.user.uid,
        cameraIds: selected,
      );

      for (final cameraId in selected) {
        await _auditLog.log(
          action: 'user_camera_access_granted',
          targetUid: widget.user.uid,
          targetCameraId: cameraId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selected.length == 1
                ? '1 câmera adicionada'
                : '${selected.length} câmeras adicionadas',
          ),
          backgroundColor: AppTheme.lightGreen,
        ),
      );
      await _loadCameras();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao adicionar câmeras: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeAccess(Camera camera) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover acesso'),
        content: Text(
          'Remover o acesso de ${widget.user.displayName} à câmera '
          '"${camera.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.revokeUserCameraAccess(
        cameraId: camera.id,
        userId: widget.user.uid,
      );
      await _auditLog.log(
        action: 'user_camera_access_revoked',
        targetUid: widget.user.uid,
        targetCameraId: camera.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acesso removido')),
      );
      await _loadCameras();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao remover acesso: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _userService.watchByUid(widget.user.uid),
      initialData: widget.user,
      builder: (context, snapshot) {
        final user = snapshot.data ?? widget.user;

        return Scaffold(
          appBar: AppBar(
            title: Text('Câmeras de ${user.displayName}'),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Ações do usuário',
                onSelected: (action) => handleUserAdminAction(
                  context,
                  user,
                  action,
                  includeCamerasNavigation: false,
                ),
                itemBuilder: (_) => userAdminMenuItems(
                  user,
                  includeCamerasAction: false,
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _loading ? null : _addCameras,
            backgroundColor: AppTheme.lightGreen,
            icon: const Icon(Icons.add, color: AppTheme.primaryWhite),
            label: const Text(
              'Adicionar',
              style: TextStyle(color: AppTheme.primaryWhite),
            ),
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Erro ao carregar câmeras: $_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCameras,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameras.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadCameras,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off_outlined,
                        size: 64,
                        color: AppTheme.textMuted.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma câmera atribuída',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toque em Adicionar para escolher quais câmeras '
                        'este usuário pode acessar.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCameras,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: _cameras.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final camera = _cameras[index];
          return Card(
            child: ListTile(
              leading: Icon(
                Icons.videocam_outlined,
                color: camera.isPublic
                    ? AppTheme.lightGreen
                    : AppTheme.textSecondary,
              ),
              title: Text(
                camera.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  if (camera.description.isNotEmpty) camera.description,
                  camera.protocolLabel,
                  if (camera.isPublic) 'Pública',
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Remover acesso',
                icon: const Icon(Icons.link_off_outlined),
                color: Colors.red.shade300,
                onPressed: () => _removeAccess(camera),
              ),
            ),
          );
        },
      ),
    );
  }
}
