import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart' as vp;
import '../models/camera.dart';
import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/rtsp_video_view.dart';
import 'edit_camera_screen.dart';

class CameraPlayerScreen extends StatefulWidget {
  final Camera camera;
  final bool canEdit;
  final bool showSensitiveInfo;

  const CameraPlayerScreen({
    super.key,
    required this.camera,
    this.canEdit = false,
    this.showSensitiveInfo = false,
  });

  @override
  State<CameraPlayerScreen> createState() => _CameraPlayerScreenState();
}

class _CameraPlayerScreenState extends State<CameraPlayerScreen> {
  vp.VideoPlayerController? _controller;
  Player? _rtspPlayer;
  TransformationController? _transformationController;
  late Camera _camera;
  bool _usingMediaKitPlayer = false;
  int _mediaKitViewKey = 0;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isFullscreen = false;
  bool _showControls = true;
  bool _isZoomed = false;
  bool _isTogglingPublic = false;
  String? _errorMessage;

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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformationController?.removeListener(_onTransformationChanged);
    _transformationController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    if (_camera.usesMediaKitPlayer) {
      _startMediaKitPlayback();
      return;
    }
    await _initializeExoPlayer();
  }

  void _startMediaKitPlayback() {
    _controller?.dispose();
    _controller = null;
    _rtspPlayer = null;
    if (!mounted) return;
    setState(() {
      _usingMediaKitPlayer = true;
      // Precisa ser false para montar [RtspVideoView] e iniciar a conexão.
      _isLoading = false;
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
      _isLoading = false;
      _isPlaying = true;
      _errorMessage = null;
    });
  }

  void _onMediaKitError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = _formatMediaKitError(message);
      _isLoading = false;
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
      return '$label: não foi possível conectar. Verifique IP, porta e credenciais.';
    }
    if (raw.contains('Failed to recognize file format') ||
        raw.contains('404') ||
        raw.contains('Not Found')) {
      return '$label: stream não encontrado ou formato não suportado.';
    }
    return '$label: $raw';
  }

  Future<void> _initializeExoPlayer() async {
    _usingMediaKitPlayer = false;
    _rtspPlayer = null;
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _isInitialized = false;
      });

      _controller?.dispose();
      _controller = vp.VideoPlayerController.networkUrl(
        Uri.parse(_camera.streamUrl),
      );

      await _controller!.initialize();
      if (!mounted) return;
      _controller!.setLooping(true);
      _controller!.setVolume(1.0);

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
      _play();
    } catch (e) {
      String errorMsg = 'Erro ao conectar com a câmera (${_camera.protocolLabel})';
      final err = e.toString();
      if (err.contains('CleartextNotPermittedException')) {
        errorMsg =
            'Erro de segurança: HTTP não permitido. Verifique a configuração de rede.';
      } else if (err.contains('SocketTimeoutException') ||
          err.contains('timed out')) {
        errorMsg =
            'Tempo esgotado ao conectar. Confirme IP/porta na mesma rede Wi‑Fi e firewall aberto.';
      } else if (err.contains('SocketException')) {
        errorMsg = 'Erro de conexão: verifique se o servidor está acessível.';
      } else if (err.contains('HttpException')) {
        errorMsg = 'Erro HTTP: verifique se a URL do stream está correta.';
      } else {
        errorMsg = 'Erro: $e';
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  void _play() {
    if (_usingMediaKitPlayer && _rtspPlayer != null) {
      _rtspPlayer!.play();
      setState(() => _isPlaying = true);
      return;
    }
    if (_controller != null && _isInitialized) {
      _controller!.play();
      setState(() => _isPlaying = true);
    }
  }

  void _pause() {
    if (_usingMediaKitPlayer && _rtspPlayer != null) {
      _rtspPlayer!.pause();
      setState(() => _isPlaying = false);
      return;
    }
    if (_controller != null && _isInitialized) {
      _controller!.pause();
      setState(() => _isPlaying = false);
    }
  }

  void _reload() {
    _controller?.dispose();
    _controller = null;
    _rtspPlayer = null;
    _usingMediaKitPlayer = false;
    _initializePlayer();
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);

    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _resetZoom() {
    _transformationController?.value = Matrix4.identity();
  }

  Future<void> _togglePublic() async {
    if (_isTogglingPublic || !widget.canEdit) return;
    final next = !_camera.isPublic;
    setState(() => _isTogglingPublic = true);
    try {
      await context.read<CameraProvider>().updateCamera(
            _camera.copyWith(isPublic: next),
          );
      if (!mounted) return;
      setState(() {
        _camera = _camera.copyWith(isPublic: next);
        _isTogglingPublic = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'Câmera pública: aparece em Câmeras públicas.'
                : 'Câmera privada: removida da lista pública.',
          ),
          backgroundColor: AppTheme.lightGreen,
        ),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullscreen
          ? null
          : AppBar(
              title: Text(_camera.name),
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: AppTheme.primaryWhite,
              actions: [
                if (widget.canEdit)
                  IconButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditCameraScreen(camera: _camera),
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
            _buildControls(),
            if (widget.showSensitiveInfo) _buildCameraInfo(),
          ] else if (_showControls)
            _buildControls(),
        ],
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

    if (_usingMediaKitPlayer) {
      return Container(
        color: AppTheme.primaryBlack,
        child: GestureDetector(
          onTap: () {
            if (_isFullscreen) setState(() => _showControls = !_showControls);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              RtspVideoView(
                key: ValueKey('media-kit-$_mediaKitViewKey'),
                url: _camera.streamUrl,
                onPlayerCreated: (player) => _rtspPlayer = player,
                onReady: _onMediaKitReady,
                onError: _onMediaKitError,
              ),
              if (!_isInitialized)
                Container(
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
                          'Conectando via ${_camera.protocolLabel}…',
                          style: const TextStyle(
                            color: AppTheme.primaryWhite,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Container(
        color: AppTheme.primaryBlack,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.lightGreen),
              const SizedBox(height: 16),
              Text(
                'Conectando via ${_camera.protocolLabel}…',
                style: const TextStyle(color: AppTheme.primaryWhite, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: AppTheme.primaryBlack,
        child: const Center(
          child: Text(
            'Inicializando player…',
            style: TextStyle(color: AppTheme.primaryWhite, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      color: AppTheme.primaryBlack,
      child: GestureDetector(
        onTap: () {
          if (_isFullscreen) setState(() => _showControls = !_showControls);
        },
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.0,
          panEnabled: true,
          scaleEnabled: true,
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: vp.VideoPlayer(_controller!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (!_isInitialized || _errorMessage != null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primaryBlack,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _isPlaying ? _pause : _play,
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              size: 32,
              color: AppTheme.primaryWhite,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, size: 24, color: AppTheme.primaryWhite),
          ),
          if (widget.canEdit) ...[
            const SizedBox(width: 16),
            IconButton(
              onPressed:
                  _isTogglingPublic || !_isInitialized ? null : _togglePublic,
              icon: _isTogglingPublic
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.lightGreen,
                      ),
                    )
                  : Icon(
                      _camera.isPublic ? Icons.public : Icons.public_off,
                      size: 24,
                      color: _camera.isPublic
                          ? AppTheme.lightGreen
                          : AppTheme.primaryWhite,
                    ),
            ),
          ],
          const SizedBox(width: 16),
          IconButton(
            onPressed: _isZoomed ? _resetZoom : null,
            icon: Icon(
              Icons.zoom_out_map,
              size: 24,
              color: _isZoomed ? AppTheme.primaryWhite : AppTheme.lightGrey,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _toggleFullscreen,
            icon: Icon(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              size: 24,
              color: AppTheme.primaryWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.offWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informações da Câmera',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
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
                    color: AppTheme.darkGrey,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryBlack,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
