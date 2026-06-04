import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';
import '../utils/camera_permissions.dart';
import '../widgets/camera_grid_card.dart';
import 'camera_player_screen.dart';

class PublicCamerasScreen extends StatefulWidget {
  final bool showAppBar;

  const PublicCamerasScreen({super.key, this.showAppBar = true});

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

  @override
  Widget build(BuildContext context) {
    final content = Consumer<CameraProvider>(
      builder: (context, cameraProvider, child) {
        if (cameraProvider.isLoadingPublic) {
          return const Center(child: CircularProgressIndicator());
        }

        if (cameraProvider.publicCameras.isEmpty) {
          return _buildEmptyState(context, cameraProvider);
        }

        final count = cameraProvider.publicCameras.length;

        return RefreshIndicator(
          onRefresh: () => cameraProvider.loadPublicCameras(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '$count câmera${count == 1 ? '' : 's'} pública${count == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.86,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final camera = cameraProvider.publicCameras[index];
                    return CameraGridCard(
                      camera: camera,
                      onTap: () {
                        final auth = context.read<AuthProvider>();
                        final showPanel = shouldShowPublicVisibilityPanel(
                          camera,
                          auth,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CameraPlayerScreen(
                              camera: camera,
                              canEdit: false,
                              showPublicPanel: showPanel,
                              canTogglePublic: canTogglePublicVisibility(
                                camera,
                                auth,
                              ),
                              publicToggleBlockedMessage: showPanel
                                  ? publicToggleBlockedMessage(auth.appUser)
                                  : null,
                              showSensitiveInfo: false,
                            ),
                          ),
                        );
                      },
                    );
                  }, childCount: count),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!widget.showAppBar) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Câmeras públicas')),
      body: content,
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    CameraProvider cameraProvider,
  ) {
    final err = cameraProvider.publicCamerasError;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              err != null ? Icons.error_outline : Icons.public_off,
              size: 72,
              color: err != null ? Colors.orange : AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              err != null
                  ? 'Não foi possível carregar'
                  : 'Nenhuma câmera pública',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (err != null) ...[
              const SizedBox(height: 12),
              Text(
                err,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => cameraProvider.loadPublicCameras(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Quando o administrador tornar câmeras públicas, elas aparecerão aqui.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
