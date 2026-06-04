import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/camera.dart';
import '../models/camera_protocol.dart';
import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/privacy_mode_provider.dart';
import '../services/audit_log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_outlined_action_button.dart';
import '../widgets/camera_stream_config_section.dart';

/// Valor retornado por [Navigator.pop] quando a câmera foi excluída.
const editCameraDeletedResult = 'deleted';

class EditCameraScreen extends StatefulWidget {
  final Camera camera;

  const EditCameraScreen({super.key, required this.camera});

  @override
  State<EditCameraScreen> createState() => _EditCameraScreenState();
}

class _EditCameraScreenState extends State<EditCameraScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _serverIpController;
  late final TextEditingController _serverPortController;
  late final TextEditingController _streamPathController;
  late final TextEditingController _manualUrlController;
  late final TextEditingController _rtspUrlController;
  late final TextEditingController _httpFileUrlController;

  final _auditLog = AuditLogService();

  bool _isLoading = false;
  late CameraProtocol _protocol;
  late bool _isManualMode;
  late bool _isPublic;

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
    final cam = widget.camera;
    _nameController = TextEditingController(text: cam.name);
    _descriptionController = TextEditingController(text: cam.description);
    _serverIpController = TextEditingController(text: cam.serverIp ?? '');
    _serverPortController = TextEditingController(
      text: cam.serverPort?.toString() ?? '',
    );
    _streamPathController = TextEditingController(
      text: cam.usesRtsp || cam.usesHttpFile ? '' : cam.streamPath,
    );
    _manualUrlController = TextEditingController(
      text: cam.protocol == CameraProtocol.hls && cam.isManualMode
          ? cam.streamPath
          : '',
    );
    _rtspUrlController = TextEditingController(
      text: cam.usesRtsp ? cam.rtspPlaybackUrl : (cam.rtspUrl ?? ''),
    );
    _httpFileUrlController = TextEditingController(
      text: cam.usesHttpFile ? cam.streamPath : '',
    );
    _protocol = cam.protocol;
    _isManualMode = cam.isManualMode;
    _isPublic = cam.isPublic;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _serverIpController.dispose();
    _serverPortController.dispose();
    _streamPathController.dispose();
    _manualUrlController.dispose();
    _rtspUrlController.dispose();
    _httpFileUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar ${widget.camera.name}')),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informações da Câmera',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Câmera *',
                          prefixIcon: Icon(Icons.videocam),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, insira o nome da câmera';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CameraStreamConfigSection(
                protocol: _protocol,
                onProtocolChanged: (p) {
                  if (p == null) return;
                  setState(() => _protocol = p);
                },
                isManualMode: _isManualMode,
                onManualModeChanged: (v) => setState(() => _isManualMode = v),
                serverIpController: _serverIpController,
                serverPortController: _serverPortController,
                streamPathController: _streamPathController,
                manualUrlController: _manualUrlController,
                rtspUrlController: _rtspUrlController,
                httpFileUrlController: _httpFileUrlController,
                privacyMode: context.watch<PrivacyModeProvider>().isEnabled,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visibilidade',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Câmera pública'),
                        subtitle: const Text(
                          'Compartilha com outros usuários e no painel da empresa.',
                        ),
                        value: _isPublic,
                        onChanged: (v) => setState(() => _isPublic = v),
                        activeThumbColor: AppTheme.primaryGreen,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informações do Sistema',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('ID da Câmera', widget.camera.id),
                      _buildInfoRow(
                        'Data de Criação',
                        _formatDate(widget.camera.createdAt),
                      ),
                      _buildInfoRow(
                        'Status Atual',
                        widget.camera.isActive ? 'Ativa' : 'Inativa',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppOutlinedActionButton(
                label: 'Atualizar Câmera',
                icon: Icons.save_outlined,
                color: AppTheme.primaryGreen,
                isLoading: _isLoading,
                onPressed: _updateCamera,
              ),
              const SizedBox(height: 12),
              AppOutlinedActionButton(
                label: 'Excluir Câmera',
                icon: Icons.delete_outline,
                color: const Color(0xFFEF5350),
                isLoading: _isLoading,
                onPressed: _confirmDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Camera _buildUpdatedCamera() {
    final base = widget.camera.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      isPublic: _isPublic,
    );

    if (_protocol == CameraProtocol.rtsp) {
      final url = _rtspUrlController.text.trim();
      return base.copyWith(
        protocol: CameraProtocol.rtsp,
        streamPath: url,
        rtspUrl: url,
        isManualMode: false,
        clearServer: true,
      );
    }

    if (_protocol == CameraProtocol.httpFile) {
      final url = _httpFileUrlController.text.trim();
      return base.copyWith(
        protocol: CameraProtocol.httpFile,
        streamPath: url,
        isManualMode: false,
        clearServer: true,
        clearRtspUrl: true,
      );
    }

    if (_isManualMode) {
      return base.copyWith(
        protocol: CameraProtocol.hls,
        streamPath: _manualUrlController.text.trim(),
        isManualMode: true,
        clearServer: true,
        clearRtspUrl: true,
      );
    }

    return base.copyWith(
      protocol: CameraProtocol.hls,
      serverIp: _serverIpController.text.trim(),
      serverPort: int.parse(_serverPortController.text.trim()),
      streamPath: _streamPathController.text.trim(),
      isManualMode: false,
      clearRtspUrl: true,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir câmera'),
          content: Text(
            'Tem certeza que deseja excluir a câmera "${widget.camera.name}"? '
            'Esta ação não pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF5350),
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await _deleteCamera();
  }

  Future<void> _deleteCamera() async {
    setState(() => _isLoading = true);

    try {
      await context.read<CameraProvider>().deleteCamera(widget.camera.id);
      await _auditLog.log(
        action: 'camera_deleted',
        targetCameraId: widget.camera.id,
      );
      if (mounted) Navigator.pop(context, editCameraDeletedResult);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir câmera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateCamera() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updated = _buildUpdatedCamera();
      final wasPublic = widget.camera.isPublic;
      await context.read<CameraProvider>().updateCamera(updated);
      await _auditLog.log(
        action: 'camera_updated',
        targetCameraId: updated.id,
      );
      if (wasPublic != updated.isPublic) {
        await _auditLog.log(
          action: 'camera_public_toggled',
          targetCameraId: updated.id,
          metadata: {'isPublic': updated.isPublic},
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar câmera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
