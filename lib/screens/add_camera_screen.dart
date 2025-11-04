import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';

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
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Valores padrão para facilitar testes
    _serverPortController.text = '8080';
    _streamPathController.text = '/live/stream.m3u8';
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

                          // Both empty -> optional
                          if (ip.isEmpty && port.isEmpty) return null;

                          // If port provided but ip missing, require ip
                          if (ip.isEmpty && port.isNotEmpty) {
                            return 'Informe o IP do servidor ou limpe a porta';
                          }

                          if (!_isValidIp(ip)) {
                            return 'Por favor, insira um IP válido';
                          }
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

                          // Both empty -> optional
                          if (portText.isEmpty && ip.isEmpty) return null;

                          // If ip provided but port missing, require port
                          if (portText.isEmpty && ip.isNotEmpty) {
                            return 'Informe a porta do servidor ou limpe o IP';
                          }

                          final port = int.tryParse(portText);
                          if (port == null || port < 1 || port > 65535) {
                            return 'Por favor, insira uma porta válida (1-65535)';
                          }
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
                          // Allow either a path starting with / or a full http(s) URL
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
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryWhite),
                        ),
                      )
                    : const Text(
                        'Salvar Câmera',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
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
    final streamText = _streamPathController.text.trim();

    if (streamText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o caminho do stream antes de testar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String testUrl;
    if (streamText.startsWith('http://') || streamText.startsWith('https://')) {
      testUrl = streamText;
    } else {
      final ip = _serverIpController.text.trim();
      final port = _serverPortController.text.trim();

      if (ip.isEmpty || port.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se o caminho não for uma URL, preencha IP e porta antes de testar'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      testUrl = 'http://$ip:$port${streamText}';
    }
    
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

  Future<void> _saveCamera() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<CameraProvider>().addCamera(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        serverIp: _serverIpController.text.trim().isEmpty ? null : _serverIpController.text.trim(),
        serverPort: _serverPortController.text.trim().isEmpty ? null : int.parse(_serverPortController.text.trim()),
        streamPath: _streamPathController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
