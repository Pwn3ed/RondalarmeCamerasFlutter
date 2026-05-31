import 'package:flutter/material.dart';

import '../models/camera.dart';
import '../theme/app_theme.dart';
import 'camera_preview_thumbnail.dart';

class CameraGridCard extends StatelessWidget {
  final Camera camera;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CameraGridCard({
    super.key,
    required this.camera,
    required this.isAdmin,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceDark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ThumbnailArea(
                  camera: camera,
                  showAdminActions: isAdmin && (onEdit != null || onDelete != null),
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, isAdmin ? 10 : 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            camera.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (camera.isPublic)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: _PublicBadge(),
                          ),
                      ],
                    ),
                    if (camera.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        camera.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.2,
                        ),
                      ),
                    ],
                    if (isAdmin) ...[
                      const SizedBox(height: 6),
                      Text(
                        camera.isUnassigned
                            ? 'Sem usuário atribuído'
                            : '${camera.assignedUserCount} usuário${camera.assignedUserCount == 1 ? '' : 's'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: camera.isUnassigned
                              ? Colors.orange
                              : AppTheme.textMuted,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        camera.protocolLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.15,
                        ),
                      ),
                      if (camera.serverIp != null && camera.serverPort != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${camera.serverIp}:${camera.serverPort}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailArea extends StatelessWidget {
  final Camera camera;
  final bool showAdminActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ThumbnailArea({
    required this.camera,
    this.showAdminActions = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: CameraPreviewThumbnail(cameraId: camera.id),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: _StatusBadge(isActive: camera.isActive),
          ),
          if (showAdminActions)
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    _ActionIcon(
                      icon: Icons.edit_outlined,
                      color: AppTheme.accentGreen,
                      tooltip: 'Editar',
                      onPressed: onEdit!,
                    ),
                  if (onDelete != null)
                    _ActionIcon(
                      icon: Icons.delete_outline,
                      color: const Color(0xFFEF5350),
                      tooltip: 'Excluir',
                      onPressed: onDelete!,
                    ),
                ],
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            right: 10,
            bottom: 10,
            child: Icon(
              Icons.play_circle_fill,
              color: AppTheme.lightGreen,
              size: 32,
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.lightGreen : AppTheme.textMuted;
    final label = isActive ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicBadge extends StatelessWidget {
  const _PublicBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.softGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Pública',
        style: TextStyle(
          color: AppTheme.accentGreen,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
