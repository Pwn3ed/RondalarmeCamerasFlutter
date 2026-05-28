import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/camera.dart';
import '../models/camera_protocol.dart';
import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import '../services/audit_log_service.dart';
import '../services/user_service.dart';
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
  final _userService = UserService();
  final _auditLog = AuditLogService();

  bool _isLoading = false;
  bool _loadingUsers = true;
  CameraProtocol _protocol = CameraProtocol.hls;
  bool _isManualMode = false;
  bool _isPublic = false;
  List<AppUser> _owners = [];
  String? _selectedOwnerId;

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
    _loadOwners();
  }

  Future<void> _loadOwners() async {
    try {
      final owners = await _userService.listForOwnerDropdown();
      if (mounted) {
        setState(() {
          _owners = owners;
          _selectedOwnerId = owners.isNotEmpty ? owners.first.uid : null;
          _loadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
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
    if (_loadingUsers) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Câmera'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.primaryWhite,
      ),
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
                      DropdownButtonFormField<String>(
                        value: _selectedOwnerId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Atribuir a usuário *',
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: _owners
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.uid,
                                child: Text(
                                  '${u.displayName} (${u.email})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedOwnerId = v),
                        validator: (v) =>
                            v == null ? 'Selecione o usuário dono' : null,
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
                        subtitle: Text(
                          'Outros usuários poderão ver e reproduzir em Câmeras públicas.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.darkGrey,
                              ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: AppTheme.primaryWhite,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppTheme.primaryWhite),
                        ),
                      )
                    : const Text(
                        'Salvar Câmera',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        ownerId: _selectedOwnerId,
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
        ownerId: _selectedOwnerId,
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
        ownerId: _selectedOwnerId,
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
      ownerId: _selectedOwnerId,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _saveCamera() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOwnerId == null) return;

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
        ownerId: _selectedOwnerId!,
      );

      final added = provider.cameras.firstWhere(
        (c) => c.name == payload.name && c.ownerId == _selectedOwnerId,
        orElse: () => provider.cameras.last,
      );

      await _auditLog.log(
        action: 'camera_created',
        targetUid: _selectedOwnerId,
        targetCameraId: added.id,
        metadata: {'assignedTo': _selectedOwnerId, 'isPublic': _isPublic},
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
