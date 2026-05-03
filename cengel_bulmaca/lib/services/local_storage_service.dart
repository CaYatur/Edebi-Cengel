import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_stats.dart';
import '../models/game_badge.dart';

/// Yerel veri saklama servisi - Puan, rozet ve istatistikleri yönetir
class LocalStorageService {
  static const String _statsKey = 'player_stats';
  static LocalStorageService? _instance;
  SharedPreferences? _prefs;
  PlayerStats? _cachedStats;

  LocalStorageService._();

  static LocalStorageService get instance {
    _instance ??= LocalStorageService._();
    return _instance!;
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _cachedStats = await _loadStats();
  }

  /// İstatistikleri yükle
  Future<PlayerStats> _loadStats() async {
    if (_prefs == null) await initialize();
    final String? jsonStr = _prefs!.getString(_statsKey);
    if (jsonStr == null) return PlayerStats();

    try {
      final Map<String, dynamic> json = jsonDecode(jsonStr);
      return PlayerStats.fromJson(json);
    } catch (e) {
      print('LocalStorageService: Stats yüklenirken hata: $e');
      return PlayerStats();
    }
  }

  /// İstatistikleri kaydet
  Future<void> _saveStats() async {
    if (_prefs == null || _cachedStats == null) return;
    final String jsonStr = jsonEncode(_cachedStats!.toJson());
    await _prefs!.setString(_statsKey, jsonStr);
  }

  /// Mevcut istatistikleri getir
  PlayerStats get stats {
    return _cachedStats ?? PlayerStats();
  }

  /// Sunucudan gelen istatistikleri yerel saklama alanına senkronize et
  Future<void> syncStatsFromServer(Map<String, dynamic>? statsData) async {
    if (statsData == null) return;
    
    try {
      _cachedStats = PlayerStats.fromJson(statsData);
      await _saveStats();
    } catch (e) {
      print('LocalStorageService: Sunucu istatistikleri senkronize edilirken hata: $e');
    }
  }

  /// Bulmaca sonucunu kaydet ve yeni rozetleri kontrol et
  Future<List<GameBadge>> recordPuzzleResult({
    required int puzzleScore,
    required int maxPossibleScore,
    required int wordsCompleted,
    required int totalWords,
    required int hintsUsed,
    required int lettersRevealed,
    required int wordsRevealed,
    required int cellsFilledByUser,
    required int durationSeconds,
    required bool usedAnyHint,
    required List<String> missedClues,
    String? categoryId,
  }) async {
    final s = _cachedStats ?? PlayerStats();

    s.totalScore += puzzleScore;
    s.totalPuzzlesCompleted += 1;
    s.totalWordsCompleted += wordsCompleted;
    s.totalHintsUsed += hintsUsed;
    s.totalLettersRevealed += lettersRevealed;
    s.totalWordsRevealed += wordsRevealed;
    s.totalCellsFilled += cellsFilledByUser;
    s.lastPlayedDate = DateTime.now();

    // Streak
    s.currentStreak += 1;
    if (s.currentStreak > s.bestStreak) {
      s.bestStreak = s.currentStreak;
    }

    // En hızlı bulmaca
    if (durationSeconds > 0 && puzzleScore > 0 &&
        (s.fastestPuzzleSeconds == 0 || durationSeconds < s.fastestPuzzleSeconds)) {
      s.fastestPuzzleSeconds = durationSeconds;
    }

    // Kategori kaydet
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'mixed') {
      s.playedCategories.add(categoryId);
      s.categoryUserScores[categoryId] =
          (s.categoryUserScores[categoryId] ?? 0) + puzzleScore;
      s.categoryMaxScores[categoryId] =
          (s.categoryMaxScores[categoryId] ?? 0) + maxPossibleScore;
      s.categoryPuzzleCounts[categoryId] =
          (s.categoryPuzzleCounts[categoryId] ?? 0) + 1;
      // Doğru / toplam kelime sayısı takibi
      s.categoryWordsCorrect[categoryId] =
          (s.categoryWordsCorrect[categoryId] ?? 0) + wordsCompleted;
      s.categoryWordsTotal[categoryId] =
          (s.categoryWordsTotal[categoryId] ?? 0) + totalWords;
      // İpucuyla açılan harf sayısı takibi
      s.categoryLettersRevealed[categoryId] =
          (s.categoryLettersRevealed[categoryId] ?? 0) + lettersRevealed;
      // Son oyundaki kaçırılan sorular (sadece son oyun saklanır)
      s.categoryLastMissedClues[categoryId] = missedClues;
    }

    // Rozetleri kontrol et
    List<GameBadge> newBadges = _checkNewBadges(
      s,
      puzzleScore: puzzleScore,
      maxPossibleScore: maxPossibleScore,
      usedAnyHint: usedAnyHint,
      durationSeconds: durationSeconds,
    );

    for (var badge in newBadges) {
      if (!s.earnedBadgeIds.contains(badge.id)) {
        s.earnedBadgeIds.add(badge.id);
      }
    }

    _cachedStats = s;
    await _saveStats();
    return newBadges;
  }

  /// Streak'i sıfırla (oyun yarım bırakıldığında)
  Future<void> resetStreak() async {
    final s = _cachedStats ?? PlayerStats();
    s.currentStreak = 0;
    _cachedStats = s;
    await _saveStats();
  }

  /// Çok oyuncu oyunu sonuçlarını kaydet
  Future<List<GameBadge>> recordMultiplayerGameResult({
    required int playerScore,
    required bool isWinner,
    required String categoryId,
  }) async {
    final s = _cachedStats ?? PlayerStats();
    
    // Çok oyuncu istatistikleri güncelle
    s.multiplayerGamesPlayed += 1;
    if (isWinner) {
      s.multiplayerGamesWon += 1;
    }
    s.multiplayerTotalScore += playerScore;
    
    // Kategori kaydı
    if (categoryId.isNotEmpty && categoryId != 'mixed') {
      s.playedCategories.add(categoryId);
    }

    // Çok oyuncu rozetlerini kontrol et
    List<GameBadge> newBadges = _checkMultiplayerBadges(s);

    for (var badge in newBadges) {
      if (!s.earnedBadgeIds.contains(badge.id)) {
        s.earnedBadgeIds.add(badge.id);
      }
    }

    _cachedStats = s;
    await _saveStats();
    return newBadges;
  }

  /// Yeni kazanılan rozetleri kontrol et
  List<GameBadge> _checkNewBadges(
    PlayerStats s, {
    required int puzzleScore,
    required int maxPossibleScore,
    required bool usedAnyHint,
    required int durationSeconds,
  }) {
    List<GameBadge> newBadges = [];

    for (var badge in BadgeDefinitions.allBadges) {
      if (s.earnedBadgeIds.contains(badge.id)) continue;

      bool earned = false;
      switch (badge.id) {
        // Tamamlama
        case 'ilk_adim':
          earned = s.totalPuzzlesCompleted >= 1;
          break;
        case 'bulmaca_cozucu':
          earned = s.totalPuzzlesCompleted >= 5;
          break;
        case 'bulmaca_20':
          earned = s.totalPuzzlesCompleted >= 20;
          break;
        case 'bulmaca_ustasi':
          earned = s.totalPuzzlesCompleted >= 25;
          break;
        case 'bulmaca_50':
          earned = s.totalPuzzlesCompleted >= 50;
          break;
        case 'bulmaca_efsanesi':
          earned = s.totalPuzzlesCompleted >= 100;
          break;
        case 'bulmaca_500':
          earned = s.totalPuzzlesCompleted >= 500;
          break;

        // Hız
        case 'hizli_bitirici':
          earned = durationSeconds > 0 && durationSeconds < 300; // 5 dakika
          break;
        case 'yildirim_hizi':
          earned = durationSeconds > 0 && durationSeconds < 120; // 2 dakika
          break;
        case 'ultrav_hiz':
          earned = durationSeconds > 0 && durationSeconds < 60; // 1 dakika
          break;
        case 'ses_hizi':
          earned = durationSeconds > 0 && durationSeconds < 30; // 30 saniye
          break;

        // Beceri
        case 'ipucusuz':
          earned = !usedAnyHint;
          break;
        case 'mukemmeliyetci':
          earned = puzzleScore == maxPossibleScore && maxPossibleScore > 0;
          break;
        case 'azimli_cozucu':
          earned = s.currentStreak >= 5;
          break;
        case '10_oyna_succeed':
          earned = s.currentStreak >= 10;
          break;
        case 'kelime_avcisi':
          earned = s.totalWordsCompleted >= 100;
          break;
        case 'kelime_ustasi':
          earned = s.totalWordsCompleted >= 500;
          break;
        case 'kelime_1000':
          earned = s.totalWordsCompleted >= 1000;
          break;
        case '10_ipucusuz':
          // Zor badge - açolarak istediğimiz kadar ipucusuz bitirilen bulmaca sayısı
          // Her bulmaca için noHintCount'a bakı. Şu an bunun tracking'i yok, basit version:
          earned = !usedAnyHint && s.totalPuzzlesCompleted >= 10;
          break;
        case '5_mukemmel':
          // Tam puan ile 5 bulmaca - şu an bunun tracking'i yok, basit version:
          earned = puzzleScore == maxPossibleScore && s.totalPuzzlesCompleted >= 10;
          break;

        // Keşif
        case 'kategori_kasifi':
          earned = s.playedCategories.length >= 5;
          break;
        case 'edebiyat_bilgini':
          earned = s.playedCategories.length >= 10;
          break;
        case 'universalci':
          earned = s.playedCategories.length >= 15;
          break;
        case 'bilgi_deryasi':
          // Tüm kategorileri oynamış - 18 adet kategori var şu an
          earned = s.playedCategories.length >= 18;
          break;

        // Puan
        case 'puan_toplayici':
          earned = s.totalScore >= 100;
          break;
        case 'puan_avcisi':
          earned = s.totalScore >= 500;
          break;
        case 'puan_krali':
          earned = s.totalScore >= 2000;
          break;
        case 'puan_10000':
          earned = s.totalScore >= 10000;
          break;
        case 'puan_50000':
          earned = s.totalScore >= 50000;
          break;

        // Çok oyuncu rozetleri - Burada CHECK ETMİYORUZ
        // Sadece _checkMultiplayerBadges() içinde kontrol edilir
      }

      if (earned) {
        newBadges.add(badge);
      }
    }

    return newBadges;
  }

  /// Çok oyuncu rozetlerini kontrol et
  List<GameBadge> _checkMultiplayerBadges(PlayerStats s) {
    List<GameBadge> newBadges = [];

    for (var badge in BadgeDefinitions.allBadges) {
      if (s.earnedBadgeIds.contains(badge.id)) continue;

      bool earned = false;
      switch (badge.id) {
        case 'oyun_arkadasi':
          earned = s.multiplayerGamesPlayed >= 1;
          break;
        case 'mp_5_oyna':
          earned = s.multiplayerGamesPlayed >= 5;
          break;
        case 'mp_25_oyna':
          earned = s.multiplayerGamesPlayed >= 25;
          break;
        case 'mp_sampiyonu':
          earned = s.multiplayerGamesWon >= 5;
          break;
        case 'mp_10_sampiyon':
          earned = s.multiplayerGamesWon >= 10;
          break;
      }

      if (earned) {
        newBadges.add(badge);
      }
    }

    return newBadges;
  }

  /// AI bulmaca sonucunu kaydet ve yeni rozetleri kontrol et
  Future<List<GameBadge>> recordAIPuzzleResult({
    required int puzzleScore,
    required int maxPossibleScore,
    required int wordsCompleted,
    required int hintsUsed,
    required int lettersRevealed,
    required int wordsRevealed,
    required int cellsFilledByUser,
    required int durationSeconds,
    required bool usedAnyHint,
  }) async {
    final s = _cachedStats ?? PlayerStats();

    s.totalScore += puzzleScore;
    s.totalPuzzlesCompleted += 1;
    s.totalWordsCompleted += wordsCompleted;
    s.totalHintsUsed += hintsUsed;
    s.totalLettersRevealed += lettersRevealed;
    s.totalWordsRevealed += wordsRevealed;
    s.totalCellsFilled += cellsFilledByUser;
    s.aiPuzzlesCompleted += 1;
    s.lastPlayedDate = DateTime.now();

    // Streak
    s.currentStreak += 1;
    if (s.currentStreak > s.bestStreak) {
      s.bestStreak = s.currentStreak;
    }

    // En hızlı bulmaca
    if (durationSeconds > 0 && puzzleScore > 0 &&
        (s.fastestPuzzleSeconds == 0 || durationSeconds < s.fastestPuzzleSeconds)) {
      s.fastestPuzzleSeconds = durationSeconds;
    }

    // AI kategorisini ekle
    s.playedCategories.add('ai_generated');

    // Normal rozetleri kontrol et
    List<GameBadge> newBadges = _checkNewBadges(
      s,
      puzzleScore: puzzleScore,
      maxPossibleScore: maxPossibleScore,
      usedAnyHint: usedAnyHint,
      durationSeconds: durationSeconds,
    );

    // AI rozetlerini kontrol et
    newBadges.addAll(_checkAIBadges(s, usedAnyHint: usedAnyHint));

    for (var badge in newBadges) {
      if (!s.earnedBadgeIds.contains(badge.id)) {
        s.earnedBadgeIds.add(badge.id);
      }
    }

    _cachedStats = s;
    await _saveStats();
    return newBadges;
  }

  /// AI rozetlerini kontrol et
  List<GameBadge> _checkAIBadges(PlayerStats s, {required bool usedAnyHint}) {
    List<GameBadge> newBadges = [];

    for (var badge in BadgeDefinitions.allBadges) {
      if (s.earnedBadgeIds.contains(badge.id)) continue;

      bool earned = false;
      switch (badge.id) {
        case 'ai_ilk_bulmaca':
          earned = s.aiPuzzlesCompleted >= 1;
          break;
        case 'ai_5_bulmaca':
          earned = s.aiPuzzlesCompleted >= 5;
          break;
        case 'ai_10_bulmaca':
          earned = s.aiPuzzlesCompleted >= 10;
          break;
        case 'ai_25_bulmaca':
          earned = s.aiPuzzlesCompleted >= 25;
          break;
        case 'ai_50_bulmaca':
          earned = s.aiPuzzlesCompleted >= 50;
          break;
        case 'ai_mukemmel':
          earned = s.aiPuzzlesCompleted >= 1 && !usedAnyHint;
          break;
      }

      if (earned) {
        newBadges.add(badge);
      }
    }

    return newBadges;
  }

  /// Tüm verileri sıfırla (debug/test için)
  Future<void> clearAllData() async {
    _cachedStats = PlayerStats();
    await _prefs?.remove(_statsKey);
  }
}
