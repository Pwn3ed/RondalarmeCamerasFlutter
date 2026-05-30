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
  Timer? _stallWatchdog;
  bool _opened = false;
  bool _failed = false;
  int _bufferingStallTicks = 0;

  String get _url => widget.url.trim();

  bool get _isRtsp => _url.toLowerCase().startsWith('rtsp://');

  bool get _isHls {
    final lower = _url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('/hls/');
  }

  bool get _isLiveStream => _isRtsp || _isHls;

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
        androidAttachSurfaceAfterVideoParameters: _isLiveStream ? false : null,
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

    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (!_opened || _failed || playing) return;
        _log('reprodução pausada inesperadamente — retomando');
        unawaited(_player.play());
      }),
    );

    _subscriptions.add(
      _player.stream.completed.listen((_) {
        if (!_isLiveStream || _failed || !mounted) return;
        _log('stream ao vivo encerrou — reabrindo');
        unawaited(_reopenStream());
      }),
    );

    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        if (!_opened || _failed || !_isLiveStream) return;
        if (buffering) {
          _bufferingStallTicks++;
          if (_bufferingStallTicks >= 8) {
            _bufferingStallTicks = 0;
            _log('buffer travado — reabrindo stream');
            unawaited(_reopenStream());
          }
          return;
        }
        _bufferingStallTicks = 0;
      }),
    );
  }

  Future<void> _configureStreamOptions() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;

    if (_isLiveStream) {
      await platform.setProperty('profile', 'low-latency');
      await platform.setProperty('cache', 'no');
      await platform.setProperty('cache-pause', 'no');
      await platform.setProperty('untimed', 'yes');
      await platform.setProperty('demuxer-lavf-analyzeduration', '0');
      await platform.setProperty('demuxer-readahead-secs', '0');
      await platform.setProperty('video-sync', 'display-resample');
      await platform.setProperty('demuxer-thread', 'yes');
    }

    if (_isRtsp) {
      await platform.setProperty('rtsp-transport', 'tcp');
      await platform.setProperty('network-timeout', '20');
      _log(
        Platform.isAndroid
            ? 'RTSP live: low-latency, tcp, hwdec=no'
            : 'RTSP live: low-latency, tcp',
      );
      return;
    }

    if (_isHls) {
      _log('HLS live: low-latency, surface early');
    }
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
      if (!_isLiveStream) {
        _succeed();
      }
    } catch (e) {
      final text = e.toString();
      if (_isLiveStream && _isBenignLiveStreamError(text)) {
        _log('open ignorado (live): $text');
        return;
      }
      _log('open falhou: $text');
      _fail(text);
    }
  }

  Future<void> _reopenStream() async {
    if (_failed || !mounted) return;
    try {
      await _configureStreamOptions();
      await _player.open(Media(_url), play: true);
    } catch (e) {
      _log('reopen falhou: $e');
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
    _startLiveWatchdog();
  }

  void _startLiveWatchdog() {
    if (!_isLiveStream) return;
    _stallWatchdog?.cancel();
    _stallWatchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_opened || _failed || !mounted) return;
      if (!_player.state.playing) {
        unawaited(_player.play());
      }
    });
  }

  void _fail(String message) {
    if (_failed || !mounted) return;
    _connectTimeout?.cancel();
    _stallWatchdog?.cancel();
    setState(() => _failed = true);
    widget.onError?.call(message);
  }

  @override
  void dispose() {
    _connectTimeout?.cancel();
    _stallWatchdog?.cancel();
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
