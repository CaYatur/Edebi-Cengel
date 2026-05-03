/// Uygulama ayarları modeli
class AppSettings {
  bool soundEnabled; // Ses açık/kapalı
  bool animationsEnabled; // Animasyonlar açık/kapalı
  bool particlesEnabled; // Partiküller (yıldızlar, konfeti) açık/kapalı
  int animationSpeed; // Animasyon hızı: 1 (yavaş), 2 (normal), 3 (hızlı)
  bool reducedMotion; // Hareket engelli mod
  bool alwaysUseHamburger; // Her zaman hamburger menüsünü kullan

  // ===== Tema Ayarları =====
  bool advancedThemeEnabled; // Gelişmiş tema modu
  double colorVibrancy; // Renk canlılığı (0.0-1.0)
  String backgroundStyle; // Arka plan stili: 'gradient', 'solid', 'pattern'
  double cardElevation; // Kart gölge yüksekliği (0.0-16.0)
  double borderRadius; // Köşe yuvarlaklığı (0.0-32.0)
  double fontSize; // Yazı boyutu çarpanı (0.8-1.5)
  bool gameScreenAnimations; // Oyun ekranında particle efektler
  String cardStyle; // Kart stili: 'elevated', 'outlined', 'filled'

  AppSettings({
    this.soundEnabled = true,
    this.animationsEnabled = true,
    this.particlesEnabled = true,
    this.animationSpeed = 2,
    this.reducedMotion = false,
    this.alwaysUseHamburger = true,
    // Tema ayarları varsayılanları
    this.advancedThemeEnabled = true,
    this.colorVibrancy = 1.0,
    this.backgroundStyle = 'gradient',
    this.cardElevation = 4.0,
    this.borderRadius = 16.0,
    this.fontSize = 1.0,
    this.gameScreenAnimations = true,
    this.cardStyle = 'elevated',
  });

  Map<String, dynamic> toJson() => {
        'soundEnabled': soundEnabled,
        'animationsEnabled': animationsEnabled,
        'particlesEnabled': particlesEnabled,
        'animationSpeed': animationSpeed,
        'reducedMotion': reducedMotion,
        'alwaysUseHamburger': alwaysUseHamburger,
        'advancedThemeEnabled': advancedThemeEnabled,
        'colorVibrancy': colorVibrancy,
        'backgroundStyle': backgroundStyle,
        'cardElevation': cardElevation,
        'borderRadius': borderRadius,
        'fontSize': fontSize,
        'gameScreenAnimations': gameScreenAnimations,
        'cardStyle': cardStyle,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      soundEnabled: json['soundEnabled'] ?? true,
      animationsEnabled: json['animationsEnabled'] ?? true,
      particlesEnabled: json['particlesEnabled'] ?? true,
      animationSpeed: json['animationSpeed'] ?? 2,
      reducedMotion: json['reducedMotion'] ?? false,
      alwaysUseHamburger: json['alwaysUseHamburger'] ?? true,
      advancedThemeEnabled: json['advancedThemeEnabled'] ?? true,
      colorVibrancy: (json['colorVibrancy'] as num?)?.toDouble() ?? 1.0,
      backgroundStyle: json['backgroundStyle'] ?? 'gradient',
      cardElevation: (json['cardElevation'] as num?)?.toDouble() ?? 4.0,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 16.0,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 1.0,
      gameScreenAnimations: json['gameScreenAnimations'] ?? true,
      cardStyle: json['cardStyle'] ?? 'elevated',
    );
  }

  /// Ayarları kopyala ve değişiklikleri uygula
  AppSettings copyWith({
    bool? soundEnabled,
    bool? animationsEnabled,
    bool? particlesEnabled,
    int? animationSpeed,
    bool? reducedMotion,
    bool? alwaysUseHamburger,
    bool? advancedThemeEnabled,
    double? colorVibrancy,
    String? backgroundStyle,
    double? cardElevation,
    double? borderRadius,
    double? fontSize,
    bool? gameScreenAnimations,
    String? cardStyle,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      particlesEnabled: particlesEnabled ?? this.particlesEnabled,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      alwaysUseHamburger: alwaysUseHamburger ?? this.alwaysUseHamburger,
      advancedThemeEnabled: advancedThemeEnabled ?? this.advancedThemeEnabled,
      colorVibrancy: colorVibrancy ?? this.colorVibrancy,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      cardElevation: cardElevation ?? this.cardElevation,
      borderRadius: borderRadius ?? this.borderRadius,
      fontSize: fontSize ?? this.fontSize,
      gameScreenAnimations: gameScreenAnimations ?? this.gameScreenAnimations,
      cardStyle: cardStyle ?? this.cardStyle,
    );
  }
}
