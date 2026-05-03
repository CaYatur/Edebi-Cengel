import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_settings.dart';

/// Uygulama ayarlarını yönetim servisi (Singleton)
class SettingsService {
  static SettingsService? _instance;
  static const String _settingsKey = 'app_settings';
  
  AppSettings _settings = AppSettings();
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  SettingsService._();

  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
    _isInitialized = true;
  }

  Future<void> _loadSettings() async {
    try {
      final json = _prefs?.getString(_settingsKey);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(decoded);
      }
    } catch (e) {
      print('Ayarlar yüklenirken hata: $e');
      _settings = AppSettings();
    }
  }

  Future<void> _saveSettings() async {
    try {
      final json = jsonEncode(_settings.toJson());
      await _prefs?.setString(_settingsKey, json);
    } catch (e) {
      print('Ayarlar kaydedilirken hata: $e');
    }
  }

  // ==================== Getter'lar ====================

  AppSettings get settings => _settings;
  bool get soundEnabled => _settings.soundEnabled;
  bool get animationsEnabled => _settings.animationsEnabled;
  bool get particlesEnabled => _settings.particlesEnabled;
  int get animationSpeed => _settings.animationSpeed;
  bool get reducedMotion => _settings.reducedMotion;
  bool get alwaysUseHamburger => _settings.alwaysUseHamburger;
  
  // ===== Tema Getter'ları =====
  bool get advancedThemeEnabled => _settings.advancedThemeEnabled;
  double get colorVibrancy => _settings.colorVibrancy;
  String get backgroundStyle => _settings.backgroundStyle;
  double get cardElevation => _settings.cardElevation;
  double get borderRadius => _settings.borderRadius;
  double get fontSize => _settings.fontSize;
  bool get gameScreenAnimations => _settings.gameScreenAnimations;
  String get cardStyle => _settings.cardStyle;

  /// Animasyon hızı için duration hesapla
  Duration getAnimationDuration({Duration defaultDuration = const Duration(milliseconds: 300)}) {
    if (!animationsEnabled) return Duration.zero;
    if (reducedMotion) return defaultDuration * 2;
    
    return defaultDuration * (3 / animationSpeed);
  }

  // ==================== Setter'lar ====================

  Future<void> setSoundEnabled(bool value) async {
    _settings = _settings.copyWith(soundEnabled: value);
    await _saveSettings();
  }

  Future<void> setAnimationsEnabled(bool value) async {
    _settings = _settings.copyWith(animationsEnabled: value);
    await _saveSettings();
  }

  Future<void> setParticlesEnabled(bool value) async {
    _settings = _settings.copyWith(particlesEnabled: value);
    await _saveSettings();
  }

  Future<void> setAnimationSpeed(int value) async {
    if (value < 1 || value > 3) return; // 1-3 arası
    _settings = _settings.copyWith(animationSpeed: value);
    await _saveSettings();
  }

  Future<void> setReducedMotion(bool value) async {
    _settings = _settings.copyWith(reducedMotion: value);
    if (value) {
      // Reduced motion aktif ise animasyonları zorunlu olarak aç
      _settings = _settings.copyWith(animationsEnabled: true);
    }
    await _saveSettings();
  }

  Future<void> setAlwaysUseHamburger(bool value) async {
    _settings = _settings.copyWith(alwaysUseHamburger: value);
    await _saveSettings();
  }

  // ===== Tema Setter'ları =====
  Future<void> setAdvancedThemeEnabled(bool value) async {
    _settings = _settings.copyWith(advancedThemeEnabled: value);
    await _saveSettings();
  }

  Future<void> setColorVibrancy(double value) async {
    if (value < 0.0 || value > 1.0) return;
    _settings = _settings.copyWith(colorVibrancy: value);
    await _saveSettings();
  }

  Future<void> setBackgroundStyle(String style) async {
    if (['gradient', 'solid', 'pattern'].contains(style)) {
      _settings = _settings.copyWith(backgroundStyle: style);
      await _saveSettings();
    }
  }

  Future<void> setCardElevation(double value) async {
    if (value >= 0.0 && value <= 16.0) {
      _settings = _settings.copyWith(cardElevation: value);
      await _saveSettings();
    }
  }

  Future<void> setBorderRadius(double value) async {
    if (value >= 0.0 && value <= 32.0) {
      _settings = _settings.copyWith(borderRadius: value);
      await _saveSettings();
    }
  }

  Future<void> setFontSize(double value) async {
    if (value >= 0.8 && value <= 1.5) {
      _settings = _settings.copyWith(fontSize: value);
      await _saveSettings();
    }
  }

  Future<void> setGameScreenAnimations(bool value) async {
    _settings = _settings.copyWith(gameScreenAnimations: value);
    await _saveSettings();
  }

  Future<void> setCardStyle(String style) async {
    if (['elevated', 'outlined', 'filled'].contains(style)) {
      _settings = _settings.copyWith(cardStyle: style);
      await _saveSettings();
    }
  }

  /// Tüm ayarları sıfırla
  Future<void> resetToDefaults() async {
    _settings = AppSettings();
    await _saveSettings();
  }
}
