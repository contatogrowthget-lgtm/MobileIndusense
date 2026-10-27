import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema do app: claro, escuro ou automático (segue o sistema).
class ThemeProvider extends ChangeNotifier {
  // v2: o app passou a abrir no tema claro (igual ao login)
  static const String _modeKey = 'theme_mode_v2';
  ThemeMode _themeMode = ThemeMode.light;

  ThemeProvider() {
    _carregarTemaSalvo();
  }

  ThemeMode get themeMode => _themeMode;

  /// true quando o app está escuro agora (considera o modo automático).
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _carregarTemaSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString(_modeKey);
    _themeMode = salvo == null
        ? ThemeMode.light // padrão: claro
        : ThemeMode.values.firstWhere((m) => m.name == salvo, orElse: () => ThemeMode.light);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> toggleTheme(bool isDark) => setMode(isDark ? ThemeMode.dark : ThemeMode.light);
}
