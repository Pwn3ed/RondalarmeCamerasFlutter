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
  final _manualUrlController = TextEditingController();
  
  bool _isLoading = false;
  bool _isManualMode = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _serverIpController.dispose();
    _serverPortController.dispose();
    _streamPathController.dispose();
    _manualUrlController.dispose();
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
                      Row(
                        children: [
                          Text(
                            'Configuração da URL',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Modo:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _isManualMode ? 'Manual' : 'Automático',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _isManualMode,
                            onChanged: (value) {
                              setState(() {
                                _isManualMode = value;
                              });
                            },
                            thumbColor: const WidgetStatePropertyAll(AppTheme.primaryGreen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (!_isManualMode) ...[
                        Text(
                          'Preencha os campos abaixo para gerar a URL automaticamente:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _serverIpController,
                          decoration: const InputDecoration(
                            labelText: 'Servidor (DDNS/IP) *',
                            hintText: 'rondagprs.ddns.net',
                            prefixIcon: Icon(Icons.dns),
                          ),
                          enableSuggestions: false,
                          autocorrect: false,
                          validator: (value) {
                            if (!_isManualMode && (value == null || value.trim().isEmpty)) {
                              return 'Informe o servidor';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _serverPortController,
                          decoration: const InputDecoration(
                            labelText: 'Porta *',
                            hintText: '8888',
                            prefixIcon: Icon(Icons.settings_ethernet),
                          ),
                          enableSuggestions: false,
                          autocorrect: false,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (!_isManualMode) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Informe a porta';
                              }
                              final port = int.tryParse(value.trim());
                              if (port == null || port < 1 || port > 65535) {
                                return 'Porta inválida (1-65535)';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _streamPathController,
                          decoration: const InputDecoration(
                            labelText: 'Caminho *',
                            hintText: 'app/deni',
                            prefixIcon: Icon(Icons.folder),
                          ),
                          enableSuggestions: false,
                          autocorrect: false,
                          validator: (value) {
                            if (!_isManualMode && (value == null || value.trim().isEmpty)) {
                              return 'Informe o caminho';
                            }
                            return null;
                          },
                        ),
                      ],

                      if (_isManualMode) ...[
                        Text(
                          'Digite a URL completa do stream:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _manualUrlController,
                          decoration: const InputDecoration(
                            labelText: 'URL Completa *',
                            hintText: 'http://servidor.com:8888/stream.m3u8',
                            prefixIcon: Icon(Icons.link),
                          ),
                          enableSuggestions: false,
                          autocorrect: false,
                          maxLines: 2,
                          validator: (value) {
                            if (_isManualMode) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Digite a URL completa';
                              }
                              if (!value.trim().startsWith('http://') && 
                                  !value.trim().startsWith('https://')) {
                                return 'URL deve começar com http:// ou https://';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
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

  Future<void> _saveCamera() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isManualMode) {
        await context.read<CameraProvider>().addCamera(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          serverIp: null,
          serverPort: null,
          streamPath: _manualUrlController.text.trim(),
          isManualMode: true,
        );
      } else {
        await context.read<CameraProvider>().addCamera(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          serverIp: _serverIpController.text.trim(),
          serverPort: int.parse(_serverPortController.text.trim()),
          streamPath: _streamPathController.text.trim(),
          isManualMode: false,
        );
      }

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
