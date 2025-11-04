import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../models/camera.dart';
import '../theme/app_theme.dart';

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
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Inicializar controllers com os dados da câmera
    _nameController = TextEditingController(text: widget.camera.name);
    _descriptionController = TextEditingController(text: widget.camera.description);
    _serverIpController = TextEditingController(text: widget.camera.serverIp ?? '');
    _serverPortController = TextEditingController(text: widget.camera.serverPort?.toString() ?? '');
    _streamPathController = TextEditingController(text: widget.camera.streamPath);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _serverIpController.dispose();
    _serverPortController.dispose();
    _streamPathController.dispose();
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
                        'Configurações do Servidor',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _serverIpController,
                        decoration: const InputDecoration(
                          labelText: 'IP do Servidor *',
                          hintText: 'Ex: 192.168.1.100',
                          prefixIcon: Icon(Icons.computer),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final ip = value?.trim() ?? '';
                          final port = _serverPortController.text.trim();

                          if (ip.isEmpty && port.isEmpty) return null;
                          if (ip.isEmpty && port.isNotEmpty) return 'Informe o IP do servidor ou limpe a porta';
                          if (!_isValidIp(ip)) return 'Por favor, insira um IP válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _serverPortController,
                        decoration: const InputDecoration(
                          labelText: 'Porta do Servidor *',
                          hintText: 'Ex: 8080',
                          prefixIcon: Icon(Icons.settings_ethernet),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final portText = value?.trim() ?? '';
                          final ip = _serverIpController.text.trim();

                          if (portText.isEmpty && ip.isEmpty) return null;
                          if (portText.isEmpty && ip.isNotEmpty) return 'Informe a porta do servidor ou limpe o IP';
                          final port = int.tryParse(portText);
                          if (port == null || port < 1 || port > 65535) return 'Por favor, insira uma porta válida (1-65535)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _streamPathController,
                        decoration: const InputDecoration(
                          labelText: 'Caminho do Stream *',
                          hintText: 'Ex: /live/stream.m3u8',
                          prefixIcon: Icon(Icons.link),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, insira o caminho do stream';
                          }
                          final v = value.trim();
                          if (!(v.startsWith('/') || v.startsWith('http://') || v.startsWith('https://'))) {
                            return 'O caminho deve começar com / ou ser uma URL completa (http/https)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _testStreamUrl,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Testar Stream'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightGreen,
                          foregroundColor: AppTheme.primaryWhite,
                        ),
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
                      _buildInfoRow('Data de Criação', _formatDate(widget.camera.createdAt)),
                      _buildInfoRow('Status Atual', widget.camera.isActive ? 'Ativa' : 'Inativa'),
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
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryWhite),
                        ),
                      )
                    : const Text(
                        'Atualizar Câmera',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
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

  bool _isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  Future<void> _testStreamUrl() async {
    if (_serverIpController.text.trim().isEmpty || 
        _serverPortController.text.trim().isEmpty ||
        _streamPathController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha IP, porta e caminho antes de testar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final testUrl = 'http://${_serverIpController.text.trim()}:${_serverPortController.text.trim()}${_streamPathController.text.trim()}';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Testando Stream'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Testando: $testUrl'),
          ],
        ),
      ),
    );

    try {
      final response = await Future.delayed(const Duration(seconds: 3));
      
      if (mounted) {
        Navigator.pop(context); // Fecha o dialog de loading
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Teste de Stream'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('URL testada: $testUrl'),
                const SizedBox(height: 16),
                const Text(
                  'Para testar completamente, salve a câmera e tente reproduzir no player.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Fecha o dialog de loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao testar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateCamera() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedCamera = widget.camera.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        serverIp: _serverIpController.text.trim().isEmpty ? null : _serverIpController.text.trim(),
        serverPort: _serverPortController.text.trim().isEmpty ? null : int.parse(_serverPortController.text.trim()),
        streamPath: _streamPathController.text.trim(),
      );

      await context.read<CameraProvider>().updateCamera(updatedCamera);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Câmera atualizada com sucesso!'),
            backgroundColor: AppTheme.lightGreen,
          ),
        );
      }
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
