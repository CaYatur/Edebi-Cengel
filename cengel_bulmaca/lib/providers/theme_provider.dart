import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  AppThemeType _currentTheme = AppThemeType.teal;
  SharedPreferences? _prefs;
  
  // Gelişmiş Tema Modu ayarları
  bool _advancedThemeEnabled = false;
  double _colorVibrancy = 0.5; // 0.0 - 1.0, 0.5 = normal

  AppThemeType get currentTheme => _currentTheme;

  AppTheme get currentAppTheme => AppTheme.themes[_currentTheme]!;

  ThemeData get currentThemeData => currentAppTheme.toThemeData();
  
  bool get advancedThemeEnabled => _advancedThemeEnabled;
  double get colorVibrancy => _colorVibrancy;

  List<AppTheme> get allThemes => AppTheme.themes.values.toList();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs?.getString('app_theme');
    final savedAdvancedMode = _prefs?.getBool('advanced_theme_enabled') ?? false;
    final savedVibrancy = _prefs?.getDouble('color_vibrancy') ?? 0.5;
    
    if (savedTheme != null) {
      try {
        _currentTheme = AppThemeType.values.firstWhere(
          (e) => e.toString() == 'AppThemeType.$savedTheme',
        );
      } catch (e) {
        _currentTheme = AppThemeType.teal;
      }
    }
    
    _advancedThemeEnabled = savedAdvancedMode;
    _colorVibrancy = savedVibrancy;
    notifyListeners();
  }

  Future<void> setTheme(AppThemeType theme) async {
    if (_currentTheme == theme) return;
    _currentTheme = theme;
    await _prefs?.setString('app_theme', theme.toString().split('.').last);
    notifyListeners();
  }
  
  Future<void> setAdvancedThemeEnabled(bool value) async {
    if (_advancedThemeEnabled == value) return;
    _advancedThemeEnabled = value;
    await _prefs?.setBool('advanced_theme_enabled', value);
    notifyListeners();
  }
  
  Future<void> setColorVibrancy(double value) async {
    final clampedValue = value.clamp(0.0, 1.0);
    if ((_colorVibrancy - clampedValue).abs() < 0.01) return; // Benzer değerlerde güncelleme yapma
    _colorVibrancy = clampedValue;
    await _prefs?.setDouble('color_vibrancy', clampedValue);
    notifyListeners();
  }
}
