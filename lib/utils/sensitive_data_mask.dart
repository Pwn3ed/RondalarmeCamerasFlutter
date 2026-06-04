/// Mascara dados sensíveis de câmeras (URLs, paths, IPs) na UI.
class SensitiveDataMask {
  static const String hidden = '••••••••••';

  static String mask(String? value) {
    if (value == null || value.trim().isEmpty) return '—';
    return hidden;
  }

  /// Remove URLs e IPs de mensagens de erro brutas do player.
  static String sanitizeError(String raw) {
    var text = raw;
    text = text.replaceAll(
      RegExp(r'rtsp://\S+', caseSensitive: false),
      '[oculto]',
    );
    text = text.replaceAll(
      RegExp(r'https?://\S+', caseSensitive: false),
      '[oculto]',
    );
    text = text.replaceAll(
      RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b'),
      '[oculto]',
    );
    return text;
  }
}
