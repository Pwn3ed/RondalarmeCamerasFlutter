import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera.dart';
import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';
import 'camera_player_screen.dart';

class PublicCamerasScreen extends StatefulWidget {
  final bool showAppBar;

  const PublicCamerasScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<PublicCamerasScreen> createState() => _PublicCamerasScreenState();
}

class _PublicCamerasScreenState extends State<PublicCamerasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().loadPublicCameras();
    });
  }

  bool _canEditCamera(Camera camera) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || camera.ownerId == null) return false;
    return uid == camera.ownerId;
  }

  @override
  Widget build(BuildContext context) {
    final content = Consumer<CameraProvider>(
        builder: (context, cameraProvider, child) {
          if (cameraProvider.isLoadingPublic) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            );
          }

          if (cameraProvider.publicCameras.isEmpty) {
            final err = cameraProvider.publicCamerasError;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      err != null ? Icons.error_outline : Icons.public_off,
                      size: 80,
                      color: err != null ? Colors.orange : AppTheme.lightGrey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      err != null ? 'Não foi possível carregar' : 'Nenhuma câmera pública',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.lightGrey,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    if (err != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        err,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.darkGrey,
                              fontFamily: 'monospace',
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Em geral: configure as Regras do Firestore para leitura de câmeras públicas e crie o índice composto se o erro mencionar index.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.darkGrey,
                            ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => cameraProvider.loadPublicCameras(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: AppTheme.primaryWhite,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Quando usuários tornarem câmeras públicas, elas aparecerão aqui. Confira no Firebase Console se o campo isPublic está true no documento.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.lightGrey,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => cameraProvider.loadPublicCameras(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cameraProvider.publicCameras.length,
              itemBuilder: (context, index) {
                final camera = cameraProvider.publicCameras[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.softGreen,
                      child: Icon(Icons.videocam, color: AppTheme.primaryGreen),
                    ),
                    title: Text(
                      camera.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      camera.description.isEmpty ? 'Sem descrição' : camera.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.play_circle_outline),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CameraPlayerScreen(
                            camera: camera,
                            canEdit: _canEditCamera(camera),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
    );

    if (!widget.showAppBar) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Câmeras públicas'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.primaryWhite,
      ),
      body: content,
    );
  }
}
