import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/camera.dart';
import '../models/camera_protocol.dart';
import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import '../services/audit_log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/camera_stream_config_section.dart';

class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _serverIpController = TextEditingController();
  final _serverPortController = TextEditingController();
  final _streamPathController = TextEditingController();
  final _manualUrlController = TextEditingController();
  final _rtspUrlController = TextEditingController();
  final _httpFileUrlController = TextEditingController();
  final _auditLog = AuditLogService();

  bool _isLoading = false;
  CameraProtocol _protocol = CameraProtocol.hls;
  bool _isManualMode = false;
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    final isAdmin = context.read<AuthProvider>().isAdmin;
    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
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
      appBar: AppBar(title: const Text('Adicionar Câmera')),
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
                      const SizedBox(height: 8),
                      Text(
                        'Cadastre a câmera agora. Depois, em Usuários, abra o '
                        'cliente e toque em Adicionar para escolher o acesso.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Câmera *',
                          hintText: 'Ex: Câmera Entrada',
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
                          hintText: 'Ex: Câmera da entrada principal',
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tornar câmera pública'),
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
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCamera,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryWhite,
                        ),
                      )
                    : const Text(
                        'Salvar Câmera',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Camera _buildCameraPayload() {
    if (_protocol == CameraProtocol.rtsp) {
      final url = _rtspUrlController.text.trim();
      return Camera(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        protocol: CameraProtocol.rtsp,
        streamPath: url,
        rtspUrl: url,
        isManualMode: false,
        isPublic: _isPublic,
        createdAt: DateTime.now(),
      );
    }

    if (_protocol == CameraProtocol.httpFile) {
      final url = _httpFileUrlController.text.trim();
      return Camera(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        protocol: CameraProtocol.httpFile,
        streamPath: url,
        isManualMode: false,
        isPublic: _isPublic,
        createdAt: DateTime.now(),
      );
    }

    if (_isManualMode) {
      return Camera(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        protocol: CameraProtocol.hls,
        streamPath: _manualUrlController.text.trim(),
        isManualMode: true,
        isPublic: _isPublic,
        createdAt: DateTime.now(),
      );
    }

    return Camera(
      id: '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      protocol: CameraProtocol.hls,
      serverIp: _serverIpController.text.trim(),
      serverPort: int.parse(_serverPortController.text.trim()),
      streamPath: _streamPathController.text.trim(),
      isManualMode: false,
      isPublic: _isPublic,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _saveCamera() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final payload = _buildCameraPayload();
      final provider = context.read<CameraProvider>();
      await provider.addCamera(
        name: payload.name,
        description: payload.description,
        protocol: payload.protocol,
        serverIp: payload.serverIp,
        serverPort: payload.serverPort,
        streamPath: payload.streamPath,
        rtspUrl: payload.rtspUrl,
        isManualMode: payload.isManualMode,
        isPublic: payload.isPublic,
      );

      final added = provider.cameras.firstWhere(
        (c) => c.name == payload.name,
        orElse: () => provider.cameras.first,
      );

      await _auditLog.log(
        action: 'camera_created',
        targetCameraId: added.id,
        metadata: {'isPublic': _isPublic, 'assignedUserIds': <String>[]},
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar câmera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
