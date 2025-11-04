import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../models/camera.dart';
import '../theme/app_theme.dart';
import 'add_camera_screen.dart';
import 'edit_camera_screen.dart';
import 'camera_player_screen.dart';

class CamerasListScreen extends StatefulWidget {
  const CamerasListScreen({super.key});

  @override
  State<CamerasListScreen> createState() => _CamerasListScreenState();
}

class _CamerasListScreenState extends State<CamerasListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().loadCameras();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Câmeras de Segurança'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.primaryWhite,
      ),
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, child) {
          if (cameraProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            );
          }

          if (cameraProvider.cameras.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_off,
                    size: 80,
                    color: AppTheme.lightGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma câmera cadastrada',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.lightGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no botão + para adicionar uma câmera',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightGrey,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => cameraProvider.loadCameras(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cameraProvider.cameras.length,
              itemBuilder: (context, index) {
                final camera = cameraProvider.cameras[index];
                return _buildCameraCard(context, camera, cameraProvider);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddCameraScreen(),
            ),
          );
          
          if (result == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Câmera adicionada com sucesso!'),
                  backgroundColor: AppTheme.lightGreen,
                ),
              );
            }
          }
        },
        backgroundColor: AppTheme.lightGreen,
        child: const Icon(Icons.add, color: AppTheme.primaryWhite),
      ),
    );
  }

  Widget _buildCameraCard(BuildContext context, Camera camera, CameraProvider cameraProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CameraPlayerScreen(camera: camera),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camera.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          camera.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.lightGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: camera.isActive,
                    onChanged: (value) {
                      cameraProvider.toggleCameraStatus(camera.id);
                    },
                    activeColor: AppTheme.lightGreen,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.computer,
                    size: 16,
                    color: AppTheme.lightGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      camera.serverIp != null && camera.serverPort != null
                          ? '${camera.serverIp}:${camera.serverPort}'
                          : camera.streamUrl,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 16,
                    color: AppTheme.lightGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      camera.streamPath,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Criada em: ${_formatDate(camera.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightGrey,
                    ),
                  ),
                                     Row(
                     children: [
                       IconButton(
                         onPressed: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (context) => CameraPlayerScreen(camera: camera),
                             ),
                           );
                         },
                         icon: const Icon(Icons.play_arrow),
                         color: AppTheme.primaryGreen,
                         tooltip: 'Reproduzir',
                       ),
                       IconButton(
                         onPressed: () async {
                           final result = await Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (context) => EditCameraScreen(camera: camera),
                             ),
                           );
                           
                           if (result == true && mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(
                                 content: Text('Câmera atualizada com sucesso!'),
                                 backgroundColor: AppTheme.lightGreen,
                               ),
                             );
                           }
                         },
                         icon: const Icon(Icons.edit),
                         color: AppTheme.lightGreen,
                         tooltip: 'Editar',
                       ),
                       IconButton(
                         onPressed: () => _showDeleteDialog(context, camera, cameraProvider),
                         icon: const Icon(Icons.delete),
                         color: Colors.red,
                         tooltip: 'Excluir',
                       ),
                     ],
                   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showDeleteDialog(BuildContext context, Camera camera, CameraProvider cameraProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Excluir Câmera'),
          content: Text('Tem certeza que deseja excluir a câmera "${camera.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await cameraProvider.deleteCamera(camera.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Câmera excluída com sucesso!'),
                        backgroundColor: AppTheme.lightGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erro ao excluir câmera'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
