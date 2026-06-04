import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oculta paths, URLs e detalhes de stream na interface (útil para capturas de tela).
class PrivacyModeProvider extends ChangeNotifier {
  static const _prefsKey = 'privacy_mode_enabled';

  bool _enabled = false;
  bool _loaded = false;

  bool get isEnabled => _enabled;
  bool get isLoaded => _loaded;

  PrivacyModeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
