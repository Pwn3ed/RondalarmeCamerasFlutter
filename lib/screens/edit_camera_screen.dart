import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera.dart';
import '../models/camera_protocol.dart';
import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/camera_stream_config_section.dart';

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

  bool _isLoading = false;
  late CameraProtocol _protocol;
  late bool _isManualMode;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    final cam = widget.camera;
    _nameController = TextEditingController(text: cam.name);
    _descriptionController = TextEditingController(text: cam.description);
    _serverIpController = TextEditingController(text: cam.serverIp ?? '');
    _serverPortController =
        TextEditingController(text: cam.serverPort?.toString() ?? '');
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
      appBar: AppBar(
        title: Text('Editar ${widget.camera.name}'),
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
                        subtitle: Text(
                          'Outros usuários podem ver esta câmera em Câmeras públicas.',
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
              ElevatedButton(
                onPressed: _isLoading ? null : _updateCamera,
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
                        'Atualizar Câmera',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  side: const BorderSide(color: AppTheme.primaryGreen),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
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
                    color: AppTheme.darkGrey,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryBlack,
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

  Future<void> _updateCamera() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<CameraProvider>().updateCamera(_buildUpdatedCamera());
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
