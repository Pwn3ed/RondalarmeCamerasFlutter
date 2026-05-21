import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Reproduz stream via media_kit (libmpv): RTSP, HTTP MP4/MKV, etc.
class RtspVideoView extends StatefulWidget {
  final String url;
  final void Function(Player player)? onPlayerCreated;
  final VoidCallback? onReady;
  final void Function(String message)? onError;

  const RtspVideoView({
    super.key,
    required this.url,
    this.onPlayerCreated,
    this.onReady,
    this.onError,
  });

  @override
  State<RtspVideoView> createState() => _RtspVideoViewState();
}

class _RtspVideoViewState extends State<RtspVideoView> {
  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _connectTimeout;
  bool _opened = false;
  bool _failed = false;

  bool get _isRtsp => widget.url.trim().toLowerCase().startsWith('rtsp://');

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[MediaKit] $message');
    }
  }

  /// Erros comuns em RTSP ao vivo que não devem encerrar a reprodução.
  /// O media_kit_video faz seek ao redimensionar a Surface; em live isso falha.
  bool _isBenignLiveStreamError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('cannot seek') ||
        lower.contains('nothing to seek') ||
        lower.contains('force-seekable') ||
        lower.contains('force it with') ||
        lower.contains('not seekable') ||
        (lower.contains('seek') && lower.contains('stream')) ||
        (lower.contains('seek') && lower.contains('seekable'));
  }

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: PlayerConfiguration(
        vo: 'null',
        protocolWhitelist: const [
          'udp',
          'rtp',
          'tcp',
          'tls',
          'data',
          'file',
          'http',
          'https',
          'crypto',
          'rtsp',
        ],
        logLevel: MPVLogLevel.error,
      ),
    );
    // RTSP ao vivo: MediaCodec (MTK/Xiaomi) falha com width/height=0 antes do SPS.
    // Decodificação por software evita "Could not open codec".
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration:
            Platform.isAndroid ? !_isRtsp : true,
        hwdec: Platform.isAndroid && _isRtsp ? 'no' : null,
        androidAttachSurfaceAfterVideoParameters:
            _isRtsp ? true : null,
      ),
    );
    widget.onPlayerCreated?.call(_player);
    _listenToPlayerEvents();
    _openStream();
  }

  void _listenToPlayerEvents() {
    _subscriptions.add(
      _player.stream.error.listen((message) {
        if (message.trim().isEmpty || _failed) return;
        if (_isBenignLiveStreamError(message)) {
          _log('ignorado (live): $message');
          return;
        }
        _log('erro: $message');
        _fail(message);
      }),
    );

    _subscriptions.add(
      _player.stream.width.listen((width) {
        if ((width ?? 0) > 0) _succeed();
      }),
    );

    _subscriptions.add(
      _player.stream.videoParams.listen((params) {
        if (params.w != null && params.w! > 0) _succeed();
      }),
    );
  }

  Future<void> _configureLiveStreamOptions() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;

    if (_isRtsp) {
      await platform.setProperty('rtsp-transport', 'tcp');
      await platform.setProperty('network-timeout', '20');
      await platform.setProperty('cache', 'no');
      await platform.setProperty('demuxer-thread', 'yes');
      // media_kit_video chama seek ao anexar Surface; live RTSP não é seekable.
      await platform.setProperty('force-seekable', 'yes');
      _log(
        Platform.isAndroid
            ? 'RTSP: tcp, force-seekable, hwdec=no'
            : 'RTSP: tcp, force-seekable',
      );
    }
  }

  Future<void> _openStream() async {
    _connectTimeout?.cancel();
    _connectTimeout = Timer(const Duration(seconds: 45), () {
      if (!_opened && !_failed && mounted) {
        _fail(
          _isRtsp
              ? 'Tempo esgotado ao conectar (RTSP). Confirme URL, MediaMTX ativo e porta 8554 no firewall.'
              : 'Tempo esgotado ao carregar o vídeo.',
        );
      }
    });

    try {
      await _configureLiveStreamOptions();
      await _player.open(Media(widget.url), play: true);
      if (!_isRtsp) {
        _succeed();
      }
    } catch (e) {
      final text = e.toString();
      if (_isRtsp && _isBenignLiveStreamError(text)) {
        _log('open ignorado (live): $text');
        return;
      }
      _log('open falhou: $text');
      _fail(text);
    }
  }

  void _succeed() {
    if (_opened || _failed || !mounted) return;
    _connectTimeout?.cancel();
    setState(() => _opened = true);
    widget.onReady?.call();
  }

  void _fail(String message) {
    if (_failed || !mounted) return;
    _connectTimeout?.cancel();
    setState(() => _failed = true);
    widget.onError?.call(message);
  }

  @override
  void dispose() {
    _connectTimeout?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        Video(
          controller: _videoController,
          fit: BoxFit.contain,
          controls: NoVideoControls,
        ),
        if (!_opened)
          const ColoredBox(
            color: Colors.black54,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
