import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/camera.dart';
import '../theme/app_theme.dart';
import 'edit_camera_screen.dart';

class CameraPlayerScreen extends StatefulWidget {
  final Camera camera;
  /// Se falso, não exibe edição (ex.: câmera de outro usuário na lista pública).
  final bool canEdit;

  const CameraPlayerScreen({
    super.key,
    required this.camera,
    this.canEdit = true,
  });

  @override
  State<CameraPlayerScreen> createState() => _CameraPlayerScreenState();
}

class _CameraPlayerScreenState extends State<CameraPlayerScreen> {
  VideoPlayerController? _controller;
  TransformationController? _transformationController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isFullscreen = false;
  bool _showControls = true;
  bool _isZoomed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController!.addListener(_onTransformationChanged);
    _initializePlayer();
  }

  void _onTransformationChanged() {
    final scale = _transformationController!.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.0;
    if (isZoomed != _isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformationController?.removeListener(_onTransformationChanged);
    _transformationController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.camera.streamUrl),
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
      String errorMsg = 'Erro ao conectar com a câmera';
      
      if (e.toString().contains('CleartextNotPermittedException')) {
        errorMsg = 'Erro de segurança: HTTP não permitido. Verifique a configuração de rede.';
      } else if (e.toString().contains('SocketException')) {
        errorMsg = 'Erro de conexão: Verifique se o servidor está acessível.';
      } else if (e.toString().contains('HttpException')) {
        errorMsg = 'Erro HTTP: Verifique se a URL do stream está correta.';
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
    if (_controller != null && _isInitialized) {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pause() {
    if (_controller != null && _isInitialized) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _reload() {
    _controller?.dispose();
    _initializePlayer();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _resetZoom() {
    _transformationController?.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullscreen ? null : AppBar(
        title: Text(widget.camera.name),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.primaryWhite,
        actions: [
          if (widget.canEdit)
            IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditCameraScreen(camera: widget.camera),
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
              tooltip: 'Editar Câmera',
            ),
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildVideoPlayer(),
          ),
          if (!_isFullscreen) ...[
            _buildControls(),
            _buildCameraInfo(),
          ] else if (_showControls)
            _buildControls(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return Container(
        color: AppTheme.primaryBlack,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppTheme.lightGreen,
              ),
              SizedBox(height: 16),
              Text(
                'Conectando à câmera...',
                style: TextStyle(
                  color: AppTheme.primaryWhite,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: AppTheme.primaryBlack,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
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

    if (!_isInitialized) {
      return Container(
        color: AppTheme.primaryBlack,
        child: const Center(
          child: Text(
            'Inicializando player...',
            style: TextStyle(
              color: AppTheme.primaryWhite,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppTheme.primaryBlack,
      child: GestureDetector(
        onTap: () {
          if (_isFullscreen) {
            setState(() {
              _showControls = !_showControls;
            });
          }
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
              child: VideoPlayer(_controller!),
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
            tooltip: _isPlaying ? 'Pausar' : 'Reproduzir',
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _reload,
            icon: const Icon(
              Icons.refresh,
              size: 24,
              color: AppTheme.primaryWhite,
            ),
            tooltip: 'Recarregar',
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _isZoomed ? _resetZoom : null,
            icon: Icon(
              Icons.zoom_out_map,
              size: 24,
              color: _isZoomed ? AppTheme.primaryWhite : AppTheme.lightGrey,
            ),
            tooltip: 'Resetar Zoom',
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _toggleFullscreen,
            icon: Icon(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              size: 24,
              color: AppTheme.primaryWhite,
            ),
            tooltip: _isFullscreen ? 'Sair da tela cheia' : 'Tela cheia',
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
          _buildInfoRow('Nome', widget.camera.name),
          _buildInfoRow('Descrição', widget.camera.description),
        _buildInfoRow('Servidor', widget.camera.serverIp != null && widget.camera.serverPort != null ? '${widget.camera.serverIp}:${widget.camera.serverPort}' : '—'),
          _buildInfoRow('Caminho', widget.camera.streamPath),
          _buildInfoRow('Stream URL', widget.camera.streamUrl),
          _buildInfoRow('Status', widget.camera.isActive ? 'Ativa' : 'Inativa'),
          if (widget.camera.isPublic)
            _buildInfoRow('Visibilidade', 'Pública'),
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
            width: 80,
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
