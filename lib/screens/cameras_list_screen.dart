import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/camera.dart';
import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/privacy_mode_provider.dart';
import '../theme/app_theme.dart';
import '../utils/camera_permissions.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/camera_grid_card.dart';
import 'add_camera_screen.dart';
import 'camera_player_screen.dart';
import 'public_cameras_screen.dart';
import 'settings_screen.dart';

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

  String get _headerSubtitle {
    final isAdmin = context.read<AuthProvider>().isAdmin;
    return switch (_selectedIndex) {
      0 => isAdmin ? 'Minhas câmeras' : 'Suas câmeras',
      1 => 'Câmeras públicas',
      _ => 'Configurações',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final isMyCamerasTab = _selectedIndex == 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppShellHeader(subtitle: _headerSubtitle),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _MyCamerasTab(isAdmin: isAdmin),
                  PublicCamerasScreen(showAppBar: false),
                  const SettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isMyCamerasTab && isAdmin
          ? FloatingActionButton(
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
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  );
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.videocam_outlined),
            selectedIcon: const Icon(Icons.videocam),
            label: isAdmin ? 'Câmeras' : 'Minhas câmeras',
          ),
          const NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'Públicas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Configurações',
          ),
        ],
      ),
    );
  }
}

class _MyCamerasTab extends StatelessWidget {
  final bool isAdmin;

  const _MyCamerasTab({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraProvider>(
      builder: (context, cameraProvider, child) {
        if (cameraProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (cameraProvider.cameras.isEmpty) {
          return _EmptyCamerasState(isAdmin: isAdmin);
        }

        final activeCount =
            cameraProvider.cameras.where((c) => c.isActive).length;

        return RefreshIndicator(
          onRefresh: () => cameraProvider.loadCameras(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '$activeCount câmera${activeCount == 1 ? '' : 's'} ativa${activeCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final camera = cameraProvider.cameras[index];
                    return _MyCameraGridCard(
                      camera: camera,
                      isAdmin: isAdmin,
                    );
                  }, childCount: cameraProvider.cameras.length),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MyCameraGridCard extends StatelessWidget {
  final Camera camera;
  final bool isAdmin;

  const _MyCameraGridCard({
    required this.camera,
    required this.isAdmin,
  });

  void _openPlayer(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final privacyMode = context.read<PrivacyModeProvider>().isEnabled;
    final showPanel = shouldShowPublicVisibilityPanel(camera, auth);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraPlayerScreen(
          camera: camera,
          canEdit: isAdmin,
          showPublicPanel: showPanel,
          canTogglePublic: canTogglePublicVisibility(camera, auth),
          publicToggleBlockedMessage: showPanel
              ? publicToggleBlockedMessage(auth.appUser)
              : null,
          showSensitiveInfo: isAdmin && !privacyMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CameraGridCard(
      camera: camera,
      onTap: () => _openPlayer(context),
    );
  }
}

class _EmptyCamerasState extends StatelessWidget {
  final bool isAdmin;

  const _EmptyCamerasState({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 72,
              color: AppTheme.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma câmera cadastrada',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isAdmin
                  ? 'Toque no botão + para adicionar uma câmera'
                  : 'Aguarde o administrador cadastrar suas câmeras',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
