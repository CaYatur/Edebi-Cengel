/// Rozet/Tag sistemi
class GameBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final BadgeCategory category;

  const GameBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
  });
}

enum BadgeCategory {
  completion, // Tamamlama ile ilgili
  speed, // Hız ile ilgili
  skill, // Beceri ile ilgili
  exploration, // Keşif ile ilgili
  score, // Puan ile ilgili
  multiplayer, // Çok oyuncu ile ilgili
  ai, // Yapay zeka bulmacaları ile ilgili
}

/// Tüm rozetlerin tanımı
class BadgeDefinitions {
  static const List<GameBadge> allBadges = [
    // --- Tamamlama Rozetleri ---
    GameBadge(
      id: 'ilk_adim',
      name: 'İlk Adım',
      description: 'İlk bulmacayı tamamla',
      icon: 'celebration',
      category: BadgeCategory.completion,
    ),
    GameBadge(
      id: 'bulmaca_cozucu',
      name: 'Bulmaca Çözücü',
      description: '5 bulmaca tamamla',
      icon: 'puzzle',
      category: BadgeCategory.completion,
    ),
    GameBadge(
      id: 'bulmaca_ustasi',
      name: 'Bulmaca Ustası',
      description: '25 bulmaca tamamla',
      icon: 'military_tech',
      category: BadgeCategory.completion,
    ),
    GameBadge(
      id: 'bulmaca_efsanesi',
      name: 'Bulmaca Efsanesi',
      description: '100 bulmaca tamamla',
      icon: 'emoji_events',
      category: BadgeCategory.completion,
    ),
    GameBadge(
      id: 'bulmaca_20',
      name: 'Bulmaca Yolcusu',
      description: '20 bulmaca tamamla',
      icon: 'trending_up',
      category: BadgeCategory.completion,
    ),
    GameBadge(
      id: 'bulmaca_50',
      name: 'Bulmaca Haritacısı',
      description: '50 bulmaca tamamla',
      icon: 'public',
      category: BadgeCategory.completion,
    ),
    GameBadge(
      id: 'bulmaca_500',
      name: 'Çengel Efsanesi',
      description: '500 bulmaca tamamla',
      icon: 'all_inclusive',
      category: BadgeCategory.completion,
    ),

    // --- Hız Rozetleri ---
    GameBadge(
      id: 'hizli_bitirici',
      name: 'Hızlı Bitirici',
      description: 'Bir bulmacayı 5 dakikadan kısa sürede tamamla',
      icon: 'flash_on',
      category: BadgeCategory.speed,
    ),
    GameBadge(
      id: 'yildirim_hizi',
      name: 'Yıldırım Hızı',
      description: 'Bir bulmacayı 2 dakikadan kısa sürede tamamla',
      icon: 'rocket',
      category: BadgeCategory.speed,
    ),
    GameBadge(
      id: 'ultrav_hiz',
      name: 'Ultraviyole Hızı',
      description: 'Bir bulmacayı 1 dakikadan kısa sürede tamamla',
      icon: 'electric_bolt',
      category: BadgeCategory.speed,
    ),
    GameBadge(
      id: 'ses_hizi',
      name: 'Ses Hızı Ustası',
      description: 'Bir bulmacayı 30 saniyeden kısa sürede tamamla',
      icon: 'speed',
      category: BadgeCategory.speed,
    ),

    // --- Beceri Rozetleri ---
    GameBadge(
      id: 'ipucusuz',
      name: 'İpucusuz Çözücü',
      description: 'Hiç ipucu kullanmadan bir bulmaca tamamla',
      icon: 'psychology',
      category: BadgeCategory.skill,
    ),
    GameBadge(
      id: 'mukemmeliyetci',
      name: 'Mükemmeliyetçi',
      description: 'Tam puan alarak bir bulmaca tamamla',
      icon: 'diamond',
      category: BadgeCategory.skill,
    ),
    GameBadge(
      id: 'azimli_cozucu',
      name: 'Azimli Çözücü',
      description: 'Arka arkaya 5 bulmaca tamamla',
      icon: 'local_fire_department',
      category: BadgeCategory.skill,
    ),
    GameBadge(
      id: 'kelime_avcisi',
      name: 'Kelime Avcısı',
      description: 'Toplamda 100 kelime tamamla',
      icon: 'track_changes',
      category: BadgeCategory.skill,
    ),
    GameBadge(
      id: 'kelime_ustasi',
      name: 'Kelime Ustası',
      description: 'Toplamda 500 kelime tamamla',
      icon: 'menu_book',
      category: BadgeCategory.skill,
    ),
    GameBadge(
      id: '10_ipucusuz',
      name: '10 Başarısı',
      description: 'İpucu olmadan 10 bulmaca tamamla',
      icon: 'verified',
      category: BadgeCategory.skill,
    ),
    GameBadge(
      id: '5_mukemmel',
      name: 'Mükemimiyet Sanatçısı',
      description: 'Tam puan ile 5 bulmaca tamamla',
      icon: 'grade',
      category: BadgeCategory.skill,
    ),
    GameBadge(
      id: '10_oyna_succeed',
      name: '10 Seri Başarısı',
      description: 'Arka arkaya 10 bulmaca tamamla',
      icon: 'whatshot',
      category: BadgeCategory.skill,
    ),
    GameBadge(
      id: 'kelime_1000',
      name: 'Kelime Ansiklopedisi',
      description: 'Toplamda 1000 kelime tamamla',
      icon: 'library_books',
      category: BadgeCategory.skill,
    ),

    // --- Keşif Rozetleri ---
    GameBadge(
      id: 'kategori_kasifi',
      name: 'Kategori Kaşifi',
      description: '5 farklı kategoride bulmaca oyna',
      icon: 'public',
      category: BadgeCategory.exploration,
    ),
    GameBadge(
      id: 'edebiyat_bilgini',
      name: 'Edebiyat Bilgini',
      description: '10 farklı kategoride bulmaca oyna',
      icon: 'library_books',
      category: BadgeCategory.exploration,
    ),
    GameBadge(
      id: 'universalci',
      name: 'Üniversalcı',
      description: '15 farklı kategoride bulmaca oyna',
      icon: 'explore',
      category: BadgeCategory.exploration,
    ),
    GameBadge(
      id: 'bilgi_deryasi',
      name: 'Bilgi Deryası',
      description: 'Tüm kategorilerde bulmaca oyna',
      icon: 'language',
      category: BadgeCategory.exploration,
    ),

    // --- Puan Rozetleri ---
    GameBadge(
      id: 'puan_toplayici',
      name: 'Puan Toplayıcı',
      description: 'Toplam 100 puan kazan',
      icon: 'star',
      category: BadgeCategory.score,
    ),
    GameBadge(
      id: 'puan_avcisi',
      name: 'Puan Avcısı',
      description: 'Toplam 500 puan kazan',
      icon: 'star_rate',
      category: BadgeCategory.score,
    ),
    GameBadge(
      id: 'puan_krali',
      name: 'Puan Kralı',
      description: 'Toplam 2000 puan kazan',
      icon: 'crown',
      category: BadgeCategory.score,
    ),
    GameBadge(
      id: 'puan_10000',
      name: 'Piramit Yapıcısı',
      description: 'Toplam 10000 puan kazan',
      icon: 'auto_awesome',
      category: BadgeCategory.score,
    ),
    GameBadge(
      id: 'puan_50000',
      name: 'Işık Saçan',
      description: 'Toplam 50000 puan kazan',
      icon: 'flare',
      category: BadgeCategory.score,
    ),

    // --- Çok Oyuncu Rozetleri ---
    GameBadge(
      id: 'oyun_arkadasi',
      name: 'Oyun Arkadaşı',
      description: 'İlk multiplayer oyununu oyna',
      icon: 'people',
      category: BadgeCategory.multiplayer,
    ),
    GameBadge(
      id: 'mp_5_oyna',
      name: 'Sosyal Oyuncu',
      description: '5 multiplayer oyununu oyna',
      icon: 'groups',
      category: BadgeCategory.multiplayer,
    ),
    GameBadge(
      id: 'mp_25_oyna',
      name: 'Takım Oyuncusu',
      description: '25 multiplayer oyununu oyna',
      icon: 'people_alt',
      category: BadgeCategory.multiplayer,
    ),
    GameBadge(
      id: 'mp_sampiyonu',
      name: 'Çok Oyuncu Şampiyonu',
      description: '5 multiplayer oyununu kazan',
      icon: 'sports_baseball',
      category: BadgeCategory.multiplayer,
    ),
    GameBadge(
      id: 'mp_10_sampiyon',
      name: 'Ağanın Ağası',
      description: '10 multiplayer oyununu kazan',
      icon: 'sports_kabaddi',
      category: BadgeCategory.multiplayer,
    ),

    // --- Yapay Zeka Rozetleri ---
    GameBadge(
      id: 'ai_ilk_bulmaca',
      name: 'AI Kaşifi',
      description: 'İlk yapay zeka bulmacasını tamamla',
      icon: 'smart_toy',
      category: BadgeCategory.ai,
    ),
    GameBadge(
      id: 'ai_5_bulmaca',
      name: 'AI Meraklısı',
      description: '5 yapay zeka bulmacası tamamla',
      icon: 'psychology_alt',
      category: BadgeCategory.ai,
    ),
    GameBadge(
      id: 'ai_10_bulmaca',
      name: 'AI Uzmanı',
      description: '10 yapay zeka bulmacası tamamla',
      icon: 'neurology',
      category: BadgeCategory.ai,
    ),
    GameBadge(
      id: 'ai_25_bulmaca',
      name: 'AI Ustası',
      description: '25 yapay zeka bulmacası tamamla',
      icon: 'hub',
      category: BadgeCategory.ai,
    ),
    GameBadge(
      id: 'ai_50_bulmaca',
      name: 'AI Efsanesi',
      description: '50 yapay zeka bulmacası tamamla',
      icon: 'auto_awesome',
      category: BadgeCategory.ai,
    ),
    GameBadge(
      id: 'ai_mukemmel',
      name: 'AI Mükemmeliyetçi',
      description: 'Yapay zeka bulmacasını ipucu kullanmadan tamamla',
      icon: 'workspace_premium',
      category: BadgeCategory.ai,
    ),
  ];

  /// Badge ID'sine göre badge bul
  static GameBadge? getBadgeById(String id) {
    try {
      return allBadges.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Kategoriye göre badge'leri filtrele
  static List<GameBadge> getBadgesByCategory(BadgeCategory category) {
    return allBadges.where((b) => b.category == category).toList();
  }
}
