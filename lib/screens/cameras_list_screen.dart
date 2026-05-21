import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../providers/auth_provider.dart';
import '../models/camera.dart';
import '../theme/app_theme.dart';
import 'add_camera_screen.dart';
import 'edit_camera_screen.dart';
import 'camera_player_screen.dart';
import 'public_cameras_screen.dart';

class CamerasListScreen extends StatefulWidget {
  const CamerasListScreen({super.key});

  @override
  State<CamerasListScreen> createState() => _CamerasListScreenState();
}

class _CamerasListScreenState extends State<CamerasListScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().loadCameras();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMyCamerasTab = _selectedIndex == 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(isMyCamerasTab ? 'Minhas câmeras' : 'Câmeras públicas'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.primaryWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Sair'),
                  content: const Text('Deseja realmente sair?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );

              if (!context.mounted) return;
              if (confirm == true) {
                final cameraProvider = context.read<CameraProvider>();
                final authProvider = context.read<AuthProvider>();
                await authProvider.signOut(cameraProvider);
              }
            },
            tooltip: 'Sair',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Consumer<CameraProvider>(
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
          const PublicCamerasScreen(showAppBar: false),
        ],
      ),
      floatingActionButton: isMyCamerasTab ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddCameraScreen(),
            ),
          );
          if (!context.mounted) return;
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Câmera adicionada com sucesso!'),
                backgroundColor: AppTheme.lightGreen,
              ),
            );
          }
        },
        backgroundColor: AppTheme.lightGreen,
        child: const Icon(Icons.add, color: AppTheme.primaryWhite),
      ) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        indicatorColor: AppTheme.softGreen,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Minhas câmeras',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'Câmeras públicas',
          ),
        ],
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          camera.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      if (camera.isPublic) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            'Pública',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.darkGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppTheme.softGreen,
                          side: BorderSide.none,
                        ),
                      ],
                    ],
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
                    Icons.settings_input_component,
                    size: 16,
                    color: AppTheme.lightGrey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    camera.protocolLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.lightGrey,
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
                      camera.usesRtsp
                          ? camera.rtspPlaybackUrl
                          : camera.usesHttpFile
                              ? camera.streamUrl
                              : camera.streamPath,
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
                           if (!context.mounted) return;
                           if (result == true) {
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
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir Câmera'),
          content: Text('Tem certeza que deseja excluir a câmera "${camera.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await cameraProvider.deleteCamera(camera.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Câmera excluída com sucesso!'),
                      backgroundColor: AppTheme.lightGreen,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro ao excluir câmera'),
                      backgroundColor: Colors.red,
                    ),
                  );
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
