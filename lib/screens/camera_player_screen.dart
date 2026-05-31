import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import '../models/camera.dart';
import '../models/camera_protocol.dart';
import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import '../services/audit_log_service.dart';
import '../services/camera_preview_cache_service.dart';
import '../services/public_toggle_guard_service.dart';
import '../theme/app_theme.dart';
import '../widgets/public_visibility_panel.dart';
import '../widgets/rtsp_video_view.dart';
import 'edit_camera_screen.dart';

class CameraPlayerScreen extends StatefulWidget {
  final Camera camera;
  final bool canEdit;
  final bool showPublicPanel;
  final bool canTogglePublic;
  final String? publicToggleBlockedMessage;
  final bool showSensitiveInfo;

  const CameraPlayerScreen({
    super.key,
    required this.camera,
    this.canEdit = false,
    this.showPublicPanel = false,
    this.canTogglePublic = false,
    this.publicToggleBlockedMessage,
    this.showSensitiveInfo = false,
  });

  @override
  State<CameraPlayerScreen> createState() => _CameraPlayerScreenState();
}

class _CameraPlayerScreenState extends State<CameraPlayerScreen> {
  Player? _mediaKitPlayer;
  TransformationController? _transformationController;
  late Camera _camera;
  int _mediaKitViewKey = 0;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isFullscreen = false;
  bool _showControls = true;
  bool _isZoomed = false;
  bool _isTogglingPublic = false;
  bool _showFullscreenHint = false;
  String? _errorMessage;
  Timer? _fullscreenHintTimer;
  Timer? _previewCaptureTimer;

  static const Duration _fullscreenHintDuration = Duration(seconds: 2);
  static const Duration _previewCaptureDelay = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _camera = widget.camera;
    _transformationController = TransformationController();
    _transformationController!.addListener(_onTransformationChanged);
    _initializePlayer();
  }

  void _onTransformationChanged() {
    final scale = _transformationController!.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.0;
    if (isZoomed != _isZoomed) {
      setState(() => _isZoomed = isZoomed);
    }
  }

  @override
  void dispose() {
    _fullscreenHintTimer?.cancel();
    _previewCaptureTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformationController?.removeListener(_onTransformationChanged);
    _transformationController?.dispose();
    super.dispose();
  }

  void _initializePlayer() {
    _mediaKitPlayer = null;
    if (!mounted) return;
    setState(() {
      _isInitialized = false;
      _isPlaying = false;
      _errorMessage = null;
      _mediaKitViewKey++;
    });
  }

  void _onMediaKitReady() {
    if (!mounted) return;
    setState(() {
      _isInitialized = true;
      _isPlaying = true;
      _errorMessage = null;
    });
    if (_isFullscreen) _scheduleFullscreenHint();
    _schedulePreviewCapture();
  }

  void _schedulePreviewCapture() {
    _previewCaptureTimer?.cancel();
    _previewCaptureTimer = Timer(_previewCaptureDelay, () {
      unawaited(_capturePreview());
    });
  }

  Future<void> _capturePreview() async {
    final player = _mediaKitPlayer;
    if (player == null || !_isInitialized) return;

    try {
      final bytes = await player.screenshot(format: 'image/jpeg');
      if (bytes != null && bytes.isNotEmpty) {
        await CameraPreviewCacheService.instance.save(_camera.id, bytes);
      }
    } catch (_) {
      // Miniatura é opcional; falha silenciosa.
    }
  }

  void _onMediaKitError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = _formatMediaKitError(message);
      _isInitialized = false;
    });
  }

  String _formatMediaKitError(String raw) {
    final label = _camera.protocolLabel;
    if (raw.contains('Connection refused') ||
        raw.contains('Connection timed out') ||
        raw.contains('SocketTimeout') ||
        raw.contains('timed out')) {
      if (_camera.usesHttpFile) {
        return '$label: não conectou ao servidor. Use o IP do PC na Wi‑Fi (não localhost), '
            'libere a porta no firewall e suba o servidor com: '
            'python -m http.server 8080 --bind 0.0.0.0';
      }
      if (_camera.usesRtsp) {
        return '$label: não conectou. Use IP da rede (não localhost), libere a porta '
            '8554/tcp no firewall (ufw allow 8554/tcp) e confirme que o MediaMTX/ffmpeg estão rodando.';
      }
      if (_camera.protocol == CameraProtocol.hls) {
        return '$label: não conectou ao servidor HLS. Confirme IP/porta/caminho, '
            'se o RTMP→HLS está ativo no servidor e se a URL termina em video1_stream.m3u8.';
      }
      return '$label: não foi possível conectar. Verifique IP, porta e credenciais.';
    }
    if (raw.contains('Failed to recognize file format') ||
        raw.contains('404') ||
        raw.contains('Not Found')) {
      return '$label: stream não encontrado ou formato não suportado.';
    }
    return '$label: $raw';
  }

  void _play() {
    if (_mediaKitPlayer != null && _isInitialized) {
      _mediaKitPlayer!.play();
      setState(() => _isPlaying = true);
    }
  }

  void _pause() {
    if (_mediaKitPlayer != null && _isInitialized) {
      _mediaKitPlayer!.pause();
      setState(() => _isPlaying = false);
    }
  }

  void _reload() {
    _mediaKitPlayer = null;
    _resetZoom();
    _initializePlayer();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) _showControls = true;
    });

    if (_isFullscreen) {
      _scheduleFullscreenHint();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      _cancelFullscreenHint();
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _resetZoom() {
    _transformationController?.value = Matrix4.identity();
  }

  void _cancelFullscreenHint() {
    _fullscreenHintTimer?.cancel();
    _fullscreenHintTimer = null;
    if (_showFullscreenHint) {
      setState(() => _showFullscreenHint = false);
    }
  }

  void _scheduleFullscreenHint() {
    _cancelFullscreenHint();
    if (!_isFullscreen || !_isInitialized) return;

    setState(() => _showFullscreenHint = true);
    _fullscreenHintTimer = Timer(_fullscreenHintDuration, () {
      if (!mounted) return;
      setState(() => _showFullscreenHint = false);
      _fullscreenHintTimer = null;
    });
  }

  Future<void> _setPublic(bool isPublic) async {
    if (_isTogglingPublic ||
        !widget.canTogglePublic ||
        isPublic == _camera.isPublic) {
      return;
    }
    setState(() => _isTogglingPublic = true);
    final cameraProvider = context.read<CameraProvider>();
    final auth = context.read<AuthProvider>();
    try {
      await cameraProvider.updateCamera(
        _camera.copyWith(isPublic: isPublic),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTogglingPublic = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível alterar visibilidade: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    var blockedAfterToggle = false;
    if (!auth.isAdmin) {
      final uid = auth.appUser?.uid ?? auth.user?.uid;
      if (uid != null) {
        final stillAllowed = await PublicToggleGuardService().recordClientToggle(
          uid: uid,
          cameraId: _camera.id,
          isPublic: isPublic,
        );
        blockedAfterToggle = !stillAllowed;
        await auth.refreshAppUser();
      }
    } else {
      await AuditLogService().log(
        action: 'camera_public_toggled',
        targetCameraId: _camera.id,
        metadata: {'isPublic': isPublic, 'byClient': false},
      );
    }

    if (!mounted) return;
    setState(() {
      _camera = _camera.copyWith(isPublic: isPublic);
      _isTogglingPublic = false;
    });
    if (blockedAfterToggle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Uso excessivo detectado. Você não pode mais alterar a '
            'visibilidade pública. Contate o administrador.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPublic
              ? 'Câmera pública: disponível em Câmeras Públicas e no painel de monitoramento da empresa.'
              : 'Câmera privada: removida da lista pública.',
        ),
        backgroundColor: AppTheme.lightGreen,
      ),
    );
  }


  Widget _buildPublicVisibilityPanel() {
    if (!widget.showPublicPanel) return const SizedBox.shrink();

    return PublicVisibilityPanel(
      isPublic: _camera.isPublic,
      isLoading: _isTogglingPublic,
      onChanged: widget.canTogglePublic && !_isTogglingPublic
          ? _setPublic
          : null,
      blockedMessage: widget.publicToggleBlockedMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_capturePreview());
      },
      child: Scaffold(
      appBar: _isFullscreen
          ? null
          : AppBar(
              title: Text(_camera.name),
              actions: [
                if (widget.canEdit)
                  IconButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EditCameraScreen(camera: _camera),
                        ),
                      );
                      if (!context.mounted) return;
                      if (result == true) {
                        final refreshed = context
                            .read<CameraProvider>()
                            .getCameraById(_camera.id);
                        if (refreshed != null) {
                          final streamChanged =
                              refreshed.streamUrl != _camera.streamUrl ||
                              refreshed.protocol != _camera.protocol ||
                              refreshed.rtspPlaybackUrl !=
                                  _camera.rtspPlaybackUrl;
                          setState(() => _camera = refreshed);
                          if (streamChanged) _reload();
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Câmera atualizada com sucesso!'),
                            backgroundColor: AppTheme.lightGreen,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.edit),
                    tooltip: 'Editar Câmera',
                  ),
              ],
            ),
      body: Column(
        children: [
          Expanded(child: _buildVideoPlayer()),
          if (!_isFullscreen) ...[
            _buildPublicVisibilityPanel(),
            _buildControls(),
            if (widget.showSensitiveInfo) _buildCameraInfo(),
          ] else if (_showControls)
            _buildControls(),
        ],
      ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_errorMessage != null) {
      return Container(
        color: AppTheme.primaryBlack,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Erro de Conexão',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.primaryWhite,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.lightGreen,
                  foregroundColor: AppTheme.primaryWhite,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppTheme.primaryBlack,
      child: GestureDetector(
        onTap: () {
          if (_isFullscreen) {
            setState(() => _showControls = !_showControls);
            if (_showControls) _scheduleFullscreenHint();
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 4.0,
              panEnabled: _isZoomed,
              scaleEnabled: _isInitialized,
              clipBehavior: Clip.none,
              child: SizedBox.expand(
                child: RtspVideoView(
                  key: ValueKey('media-kit-$_mediaKitViewKey'),
                  url: _camera.streamUrl,
                  onPlayerCreated: (player) => _mediaKitPlayer = player,
                  onReady: _onMediaKitReady,
                  onError: _onMediaKitError,
                ),
              ),
            ),
            if (!_isInitialized)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppTheme.lightGreen,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Conectando…',
                          style: const TextStyle(
                            color: AppTheme.primaryWhite,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isFullscreen && _showFullscreenHint && _isInitialized)
              Positioned(
                top: 16,
                left: 24,
                right: 24,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        'Toque na tela para esconder a barra de configuração',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (!_isInitialized || _errorMessage != null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: AppTheme.primaryBlack,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _isPlaying ? _pause : _play,
              tooltip: _isPlaying ? 'Pausar' : 'Reproduzir',
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 32,
                color: AppTheme.primaryWhite,
              ),
            ),
            IconButton(
              onPressed: _reload,
              tooltip: 'Recarregar stream',
              icon: const Icon(
                Icons.refresh,
                size: 24,
                color: AppTheme.primaryWhite,
              ),
            ),
            IconButton(
              onPressed: _isZoomed ? _resetZoom : null,
              tooltip: 'Resetar zoom',
              icon: Icon(
                Icons.zoom_out_map,
                size: 24,
                color: _isZoomed ? AppTheme.primaryWhite : AppTheme.lightGrey,
              ),
            ),
            IconButton(
              onPressed: _toggleFullscreen,
              tooltip: _isFullscreen ? 'Sair da tela cheia' : 'Tela cheia',
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 24,
                color: AppTheme.primaryWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informações da Câmera',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.accentGreen,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Nome', _camera.name),
          _buildInfoRow('Descrição', _camera.description),
          _buildInfoRow('Protocolo', _camera.protocolLabel),
          if (_camera.usesRtsp) ...[
            _buildInfoRow('URL RTSP', _camera.rtspPlaybackUrl),
          ] else if (_camera.usesHttpFile) ...[
            _buildInfoRow('URL do vídeo', _camera.streamUrl),
          ] else ...[
            _buildInfoRow(
              'Servidor',
              _camera.serverIp != null && _camera.serverPort != null
                  ? '${_camera.serverIp}:${_camera.serverPort}'
                  : '—',
            ),
            _buildInfoRow('Caminho', _camera.streamPath),
            _buildInfoRow('Stream URL', _camera.streamUrl),
          ],
          _buildInfoRow('Status', _camera.isActive ? 'Ativa' : 'Inativa'),
          _buildInfoRow(
            'Visibilidade',
            _camera.isPublic ? 'Pública' : 'Privada',
          ),
        ],
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
            width: 110,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
