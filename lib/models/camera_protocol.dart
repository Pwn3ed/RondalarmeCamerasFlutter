/// Protocolo de conexão da câmera (apenas um ativo por cadastro).
enum CameraProtocol {
  /// Intelbras / DDNS: servidor + porta + caminho → HLS (m3u8).
  hls,

  /// Acesso direto via RTSP (URL completa).
  rtsp,

  /// Vídeo por HTTP (arquivo .mp4 ou .mkv).
  httpFile,
}

/// Validação de URLs para [CameraProtocol.httpFile].
bool isValidHttpFileUrl(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return false;
  final lower = trimmed.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return false;
  }
  if (lower.contains('127.0.0.1') || lower.contains('localhost')) {
    return false;
  }
  final path = Uri.tryParse(trimmed)?.path.toLowerCase() ?? lower;
  return path.endsWith('.mp4') || path.endsWith('.mkv');
}

String? validateHttpFileUrlField(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return 'Informe a URL do vídeo';
  final lower = trimmed.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return 'URL deve começar com http:// ou https://';
  }
  if (lower.contains('127.0.0.1') || lower.contains('localhost')) {
    return 'No celular use o IP da rede (ex: 192.168.1.x), não localhost';
  }
  final path = Uri.tryParse(trimmed)?.path.toLowerCase() ?? lower;
  if (!path.endsWith('.mp4') && !path.endsWith('.mkv')) {
    return 'Use um arquivo .mp4 ou .mkv';
  }
  return null;
}

extension CameraProtocolLabels on CameraProtocol {
  String get label {
    switch (this) {
      case CameraProtocol.hls:
        return 'RTMP (HLS)';
      case CameraProtocol.rtsp:
        return 'RTSP';
      case CameraProtocol.httpFile:
        return 'HTTP (MP4/MKV)';
    }
  }

  String get storageValue {
    switch (this) {
      case CameraProtocol.hls:
        return 'hls';
      case CameraProtocol.rtsp:
        return 'rtsp';
      case CameraProtocol.httpFile:
        return 'http_file';
    }
  }

  static CameraProtocol fromStorage(String? value) {
    switch (value) {
      case 'rtsp':
        return CameraProtocol.rtsp;
      case 'http_file':
      case 'http':
        return CameraProtocol.httpFile;
      case 'hls':
      case 'rtmp':
        return CameraProtocol.hls;
      default:
        return CameraProtocol.hls;
    }
  }
}
