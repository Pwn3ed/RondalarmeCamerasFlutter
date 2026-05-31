import 'dart:io';

import 'package:flutter/material.dart';

import '../services/camera_preview_cache_service.dart';
import '../theme/app_theme.dart';

/// Miniatura da câmera (último frame salvo) ou placeholder padrão.
class CameraPreviewThumbnail extends StatefulWidget {
  final String cameraId;

  const CameraPreviewThumbnail({super.key, required this.cameraId});

  @override
  State<CameraPreviewThumbnail> createState() => _CameraPreviewThumbnailState();
}

class _CameraPreviewThumbnailState extends State<CameraPreviewThumbnail> {
  File? _previewFile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
    CameraPreviewCacheService.instance.addListener(_loadPreview);
  }

  @override
  void dispose() {
    CameraPreviewCacheService.instance.removeListener(_loadPreview);
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final file = await CameraPreviewCacheService.instance.getPreviewFile(
      widget.cameraId,
    );
    if (!mounted) return;
    setState(() {
      _previewFile = file;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _PreviewPlaceholder(showIcon: false);
    }

    final file = _previewFile;
    if (file == null) {
      return const _PreviewPlaceholder();
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const _PreviewPlaceholder(),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  final bool showIcon;

  const _PreviewPlaceholder({this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceElevated,
            AppTheme.softGreen.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: showIcon
          ? const Center(
              child: Icon(
                Icons.videocam_outlined,
                size: 36,
                color: AppTheme.textMuted,
              ),
            )
          : null,
    );
  }
}
