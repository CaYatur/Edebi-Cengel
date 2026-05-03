import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';

/// Uygulama genelinde ses efektleri yönetimi
/// Aynı anda birden fazla ses çalabilir (paralel)
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  // Ses çalıcılarının havuzu - aynı anda max 10 ses çalabilir
  final List<AudioPlayer> _playerPool = List.generate(10, (_) => AudioPlayer());
  int _currentPlayerIndex = 0;
  bool _enabled = true;

  bool get enabled => _enabled;
  set enabled(bool value) => _enabled = value;

  /// Bir sonraki müsait ses çalıcısını al (pool'dan döngüsel olarak)
  AudioPlayer _getNextPlayer() {
    final player = _playerPool[_currentPlayerIndex];
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerPool.length;
    return player;
  }

  /// Ses dosyası çal (assets/sounds/ altından) - Asenkron, beklemeden
  void play(String fileName) {
    // Hem local _enabled hem de SettingsService'den kontrol et
    if (!_enabled || !SettingsService.instance.soundEnabled) return;
    
    // Asenkron çalıştır (fire and forget)
    _playAsync(fileName);
  }

  /// İç metod: Asenkron ses çalma
  Future<void> _playAsync(String fileName) async {
    try {
      final player = _getNextPlayer();
      await player.play(AssetSource('sounds/$fileName'));
    } catch (_) {
      // Ses dosyası yoksa sessizce devam et
    }
  }

  // ── Kısa yol metodları (asenkron, fire-and-forget) ──
  void playTabSwitch() => play('tab_switch.wav');
  void playButtonClick() => play('button_click.wav');
  void playSuccess() => play('success.wav');
  void playError() => play('error.wav');
  void playWelcome() => play('welcome.wav');
  void playKeystroke() => play('keystroke.wav');
  void playGameStart() => play('game_start.wav');
  void playWordComplete() => play('word_complete.wav');
  void playCellTap() => play('cell_tap.wav');
  void playHint() => play('hint.wav');
  void playNavigation() => play('navigation.wav');
  void playGameComplete() => play('game_complete.wav');
  void playCategorySelect() => play('category_select.wav');
  void playBadgeEarned() => play('badge_earned.wav');

  void dispose() {
    for (final player in _playerPool) {
      player.dispose();
    }
  }
}
