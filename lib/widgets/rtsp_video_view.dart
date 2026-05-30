import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Reproduz stream via media_kit (libmpv): HLS, RTSP, HTTP MP4/MKV, etc.
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

  String get _url => widget.url.trim();

  bool get _isRtsp => _url.toLowerCase().startsWith('rtsp://');

  bool get _isHls {
    final lower = _url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('/hls/');
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[MediaKit] $message');
    }
  }

  /// Erros comuns em streams ao vivo que não devem encerrar a reprodução.
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

    final useSoftwareRtsp = Platform.isAndroid && _isRtsp;
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !useSoftwareRtsp,
        hwdec: useSoftwareRtsp ? 'no' : null,
        // RTSP: Surface cedo evita 1º frame congelado. HLS: default do media_kit.
        androidAttachSurfaceAfterVideoParameters: _isRtsp ? false : null,
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

    // RTSP ao vivo: retoma se pausar sozinho. HLS não — evita briga com buffer/cache.
    if (_isRtsp) {
      _subscriptions.add(
        _player.stream.playing.listen((playing) {
          if (!_opened || _failed || playing) return;
          _log('RTSP pausou inesperadamente — retomando');
          unawaited(_player.play());
        }),
      );
    }
  }

  Future<void> _configureStreamOptions() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;

    if (_isHls) {
      await _configureHlsLiveOptions(platform);
      _log('HLS: cache moderado + display-vdrop (sem aceleração)');
      return;
    }

    if (_isRtsp) {
      await _configureRtspLiveOptions(platform);
      _log(
        Platform.isAndroid
            ? 'RTSP: low-latency, tcp, hwdec=no'
            : 'RTSP: low-latency, tcp',
      );
    }
  }

  /// HLS (Intelbras/RTMP→m3u8): prioriza fluidez, não latência mínima.
  /// Evita display-resample/untimed que causam "3s parado + 3s acelerado".
  Future<void> _configureHlsLiveOptions(NativePlayer platform) async {
    await platform.setProperty('cache', 'yes');
    await platform.setProperty('cache-pause', 'yes');
    await platform.setProperty('cache-secs', '8');
    await platform.setProperty('demuxer-readahead-secs', '8');
    await platform.setProperty('demuxer-max-bytes', '32MiB');
    await platform.setProperty('video-sync', 'display-vdrop');
    await platform.setProperty('speed', '1');
    await platform.setProperty('demuxer-thread', 'yes');
    await platform.setProperty('demuxer-lavf-analyzeduration', '500000');
  }

  /// RTSP: latência baixa; configuração separada do HLS.
  Future<void> _configureRtspLiveOptions(NativePlayer platform) async {
    await platform.setProperty('profile', 'low-latency');
    await platform.setProperty('cache', 'no');
    await platform.setProperty('cache-pause', 'no');
    await platform.setProperty('rtsp-transport', 'tcp');
    await platform.setProperty('network-timeout', '20');
    await platform.setProperty('demuxer-thread', 'yes');
  }

  Future<void> _openStream() async {
    _connectTimeout?.cancel();
    _connectTimeout = Timer(const Duration(seconds: 45), () {
      if (!_opened && !_failed && mounted) {
        _fail(_timeoutMessage());
      }
    });

    try {
      await _configureStreamOptions();
      await _player.open(Media(_url), play: true);
      if (!_isRtsp && !_isHls) {
        _succeed();
      }
    } catch (e) {
      final text = e.toString();
      if ((_isRtsp || _isHls) && _isBenignLiveStreamError(text)) {
        _log('open ignorado (live): $text');
        return;
      }
      _log('open falhou: $text');
      _fail(text);
    }
  }

  String _timeoutMessage() {
    if (_isRtsp) {
      return 'Tempo esgotado ao conectar (RTSP). Confirme URL, MediaMTX ativo e porta 8554 no firewall.';
    }
    if (_isHls) {
      return 'Tempo esgotado ao conectar (HLS). Confirme servidor, caminho e se o stream .m3u8 está ativo.';
    }
    return 'Tempo esgotado ao carregar o vídeo.';
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
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
