import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';

/// Ayarlar Provider - ChangeNotifier ile state management
class SettingsProvider extends ChangeNotifier {
  final SettingsService _service = SettingsService.instance;
  final SoundService _soundService = SoundService.instance;

  SettingsProvider() {
    // Başlangıçta SoundService'i ayarlarla senkron et
    _soundService.enabled = _service.soundEnabled;
  }

  AppSettings get settings => _service.settings;
  bool get soundEnabled => _service.soundEnabled;
  bool get animationsEnabled => _service.animationsEnabled;
  bool get particlesEnabled => _service.particlesEnabled;
  int get animationSpeed => _service.animationSpeed;
  bool get reducedMotion => _service.reducedMotion;
  bool get alwaysUseHamburger => _service.alwaysUseHamburger;
  
  // ===== Tema Getter'ları =====
  bool get advancedThemeEnabled => _service.advancedThemeEnabled;
  double get colorVibrancy => _service.colorVibrancy;
  String get backgroundStyle => _service.backgroundStyle;
  double get cardElevation => _service.cardElevation;
  double get borderRadius => _service.borderRadius;
  double get fontSize => _service.fontSize;
  bool get gameScreenAnimations => _service.gameScreenAnimations;
  String get cardStyle => _service.cardStyle;

  /// Animasyon hızı için duration hesapla
  Duration getAnimationDuration({Duration defaultDuration = const Duration(milliseconds: 300)}) {
    return _service.getAnimationDuration(defaultDuration: defaultDuration);
  }

  Future<void> setSoundEnabled(bool value) async {
    await _service.setSoundEnabled(value);
    _soundService.enabled = value;
    notifyListeners();
  }

  Future<void> setAnimationsEnabled(bool value) async {
    await _service.setAnimationsEnabled(value);
    notifyListeners();
  }

  Future<void> setParticlesEnabled(bool value) async {
    await _service.setParticlesEnabled(value);
    notifyListeners();
  }

  Future<void> setAnimationSpeed(int value) async {
    await _service.setAnimationSpeed(value);
    notifyListeners();
  }

  Future<void> setReducedMotion(bool value) async {
    await _service.setReducedMotion(value);
    notifyListeners();
  }

  Future<void> setAlwaysUseHamburger(bool value) async {
    await _service.setAlwaysUseHamburger(value);
    notifyListeners();
  }

  // ===== Tema Setter'ları =====
  Future<void> setAdvancedThemeEnabled(bool value) async {
    await _service.setAdvancedThemeEnabled(value);
    notifyListeners();
  }

  Future<void> setColorVibrancy(double value) async {
    await _service.setColorVibrancy(value);
    notifyListeners();
  }

  Future<void> setBackgroundStyle(String style) async {
    await _service.setBackgroundStyle(style);
    notifyListeners();
  }

  Future<void> setCardElevation(double value) async {
    await _service.setCardElevation(value);
    notifyListeners();
  }

  Future<void> setBorderRadius(double value) async {
    await _service.setBorderRadius(value);
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    await _service.setFontSize(value);
    notifyListeners();
  }

  Future<void> setGameScreenAnimations(bool value) async {
    await _service.setGameScreenAnimations(value);
    notifyListeners();
  }

  Future<void> setCardStyle(String style) async {
    await _service.setCardStyle(style);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await _service.resetToDefaults();
    _soundService.enabled = _service.soundEnabled;
    notifyListeners();
  }
}
