/// Oyuncu istatistikleri ve puan takibi modeli
class PlayerStats {
  int totalScore;
  int totalPuzzlesCompleted;
  int totalWordsCompleted;
  int totalHintsUsed;
  int totalLettersRevealed;
  int totalWordsRevealed;
  int totalCellsFilled; // Kullanıcının kendi doldurduğu hücreler
  int fastestPuzzleSeconds; // En hızlı bulmaca süresi (saniye)
  int currentStreak; // Arka arkaya tamamlanan bulmaca sayısı
  int bestStreak;
  Set<String> playedCategories; // Oynanan kategori ID'leri
  List<String> earnedBadgeIds; // Kazanılan rozet ID'leri
  int multiplayerGamesPlayed; // Oynanan çok oyuncu oyun sayısı
  int multiplayerGamesWon; // Kazanılan çok oyuncu oyun sayısı
  int multiplayerTotalScore; // Çok oyuncuda kazanılan toplam puan
  int aiPuzzlesCompleted; // Tamamlanan AI bulmaca sayısı
  DateTime? lastPlayedDate;

  // Konu/kategori bazlı başarı analizi
  Map<String, int> categoryUserScores;   // categoryId -> kullanıcının kendi doldurduğu hücreler toplamı
  Map<String, int> categoryMaxScores;    // categoryId -> maksimum mümkün puan toplamı
  Map<String, int> categoryPuzzleCounts; // categoryId -> oynanan bulmaca sayısı
  Map<String, int> categoryWordsCorrect; // categoryId -> doğru tamamlanan kelime toplamı
  Map<String, int> categoryWordsTotal;   // categoryId -> toplam kelime toplamı
  Map<String, int> categoryLettersRevealed; // categoryId -> ipucuyla açılan harf sayısı
  // Son oyundaki kaçırılan sorular: "soru|||cevap" formatında stringler
  Map<String, List<String>> categoryLastMissedClues;

  PlayerStats({
    this.totalScore = 0,
    this.totalPuzzlesCompleted = 0,
    this.totalWordsCompleted = 0,
    this.totalHintsUsed = 0,
    this.totalLettersRevealed = 0,
    this.totalWordsRevealed = 0,
    this.totalCellsFilled = 0,
    this.fastestPuzzleSeconds = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    Set<String>? playedCategories,
    List<String>? earnedBadgeIds,
    this.multiplayerGamesPlayed = 0,
    this.multiplayerGamesWon = 0,
    this.multiplayerTotalScore = 0,
    this.aiPuzzlesCompleted = 0,
    this.lastPlayedDate,
    Map<String, int>? categoryUserScores,
    Map<String, int>? categoryMaxScores,
    Map<String, int>? categoryPuzzleCounts,
    Map<String, int>? categoryWordsCorrect,
    Map<String, int>? categoryWordsTotal,
    Map<String, int>? categoryLettersRevealed,
    Map<String, List<String>>? categoryLastMissedClues,
  })  : playedCategories = playedCategories ?? {},
        earnedBadgeIds = earnedBadgeIds ?? [],
        categoryUserScores = categoryUserScores ?? {},
        categoryMaxScores = categoryMaxScores ?? {},
        categoryPuzzleCounts = categoryPuzzleCounts ?? {},
        categoryWordsCorrect = categoryWordsCorrect ?? {},
        categoryWordsTotal = categoryWordsTotal ?? {},
        categoryLettersRevealed = categoryLettersRevealed ?? {},
        categoryLastMissedClues = categoryLastMissedClues ?? {};

  Map<String, dynamic> toJson() => {
        'totalScore': totalScore,
        'totalPuzzlesCompleted': totalPuzzlesCompleted,
        'totalWordsCompleted': totalWordsCompleted,
        'totalHintsUsed': totalHintsUsed,
        'totalLettersRevealed': totalLettersRevealed,
        'totalWordsRevealed': totalWordsRevealed,
        'totalCellsFilled': totalCellsFilled,
        'fastestPuzzleSeconds': fastestPuzzleSeconds,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'playedCategories': playedCategories.toList(),
        'earnedBadgeIds': earnedBadgeIds,
        'multiplayerGamesPlayed': multiplayerGamesPlayed,
        'multiplayerGamesWon': multiplayerGamesWon,
        'multiplayerTotalScore': multiplayerTotalScore,
        'aiPuzzlesCompleted': aiPuzzlesCompleted,
        'lastPlayedDate': lastPlayedDate?.toIso8601String(),
        'categoryUserScores': categoryUserScores,
        'categoryMaxScores': categoryMaxScores,
        'categoryPuzzleCounts': categoryPuzzleCounts,
        'categoryWordsCorrect': categoryWordsCorrect,
        'categoryWordsTotal': categoryWordsTotal,
        'categoryLettersRevealed': categoryLettersRevealed,
        'categoryLastMissedClues': categoryLastMissedClues.map(
            (k, v) => MapEntry(k, v)),
      };

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    Map<String, int> _readIntMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
      }
      return {};
    }

    return PlayerStats(
      totalScore: json['totalScore'] ?? 0,
      totalPuzzlesCompleted: json['totalPuzzlesCompleted'] ?? 0,
      totalWordsCompleted: json['totalWordsCompleted'] ?? 0,
      totalHintsUsed: json['totalHintsUsed'] ?? 0,
      totalLettersRevealed: json['totalLettersRevealed'] ?? 0,
      totalWordsRevealed: json['totalWordsRevealed'] ?? 0,
      totalCellsFilled: json['totalCellsFilled'] ?? 0,
      fastestPuzzleSeconds: json['fastestPuzzleSeconds'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      bestStreak: json['bestStreak'] ?? 0,
      playedCategories: json['playedCategories'] != null
          ? Set<String>.from(json['playedCategories'])
          : {},
      earnedBadgeIds: json['earnedBadgeIds'] != null
          ? List<String>.from(json['earnedBadgeIds'])
          : [],
      multiplayerGamesPlayed: json['multiplayerGamesPlayed'] ?? 0,
      multiplayerGamesWon: json['multiplayerGamesWon'] ?? 0,
      multiplayerTotalScore: json['multiplayerTotalScore'] ?? 0,
      aiPuzzlesCompleted: json['aiPuzzlesCompleted'] ?? 0,
      lastPlayedDate: json['lastPlayedDate'] != null
          ? DateTime.tryParse(json['lastPlayedDate'])
          : null,
      categoryUserScores: _readIntMap(json['categoryUserScores']),
      categoryMaxScores: _readIntMap(json['categoryMaxScores']),
      categoryPuzzleCounts: _readIntMap(json['categoryPuzzleCounts']),
      categoryWordsCorrect: _readIntMap(json['categoryWordsCorrect']),
      categoryWordsTotal: _readIntMap(json['categoryWordsTotal']),
      categoryLettersRevealed: _readIntMap(json['categoryLettersRevealed']),
      categoryLastMissedClues: json['categoryLastMissedClues'] != null
          ? (json['categoryLastMissedClues'] as Map).map(
              (k, v) => MapEntry(
                  k.toString(), List<String>.from(v as List? ?? [])))
          : {},
    );
  }

  /// Belirli bir kategori için başarı yüzdesi (0-100). Veri yoksa null.
  double? successRateFor(String categoryId) {
    final max = categoryMaxScores[categoryId] ?? 0;
    if (max <= 0) return null;
    final user = categoryUserScores[categoryId] ?? 0;
    return (user / max) * 100;
  }

  /// Rütbe seviyesini döndürür
  String get rank {
    if (totalScore >= 10000) return 'Edebiyat Efsanesi';
    if (totalScore >= 5000) return 'Edebiyat Ustası';
    if (totalScore >= 2000) return 'Çengel Uzmanı';
    if (totalScore >= 1000) return 'Kelime Avcısı';
    if (totalScore >= 500) return 'Bulmaca Tutkunu';
    if (totalScore >= 200) return 'Meraklı Çözücü';
    if (totalScore >= 50) return 'Acemi Çözücü';
    return 'Yeni Başlayan';
  }

  /// Rütbe ikonu (ikon adı string)
  String get rankIcon {
    if (totalScore >= 10000) return 'crown';
    if (totalScore >= 5000) return 'emoji_events';
    if (totalScore >= 2000) return 'star';
    if (totalScore >= 1000) return 'target';
    if (totalScore >= 500) return 'local_fire_department';
    if (totalScore >= 200) return 'library_books';
    if (totalScore >= 50) return 'edit';
    return 'sprout';
  }
}
