import 'package:flutter/material.dart';

enum AppThemeType {
  teal,
  deepOrange,
  deepPurple,
  blue,
  pink,
  green,
  indigo,
}

class AppTheme {
  final AppThemeType type;
  final String name;
  final Color seedColor;
  final Color primaryColor;
  final Color accentColor;
  final LinearGradient appBarGradient;
  final Color fabColor;
  final Color backgroundColor;
  
  // Kategori kartları için renk paletleri (Gelişmiş Tema Modu)
  final List<List<Color>> categoryColorPalettes;

  const AppTheme({
    required this.type,
    required this.name,
    required this.seedColor,
    required this.primaryColor,
    required this.accentColor,
    required this.appBarGradient,
    required this.fabColor,
    required this.backgroundColor,
    required this.categoryColorPalettes,
  });

  static const Map<AppThemeType, AppTheme> themes = {
    AppThemeType.teal: AppTheme(
      type: AppThemeType.teal,
      name: '🌊 Teal (Orijinal)',
      seedColor: Color(0xFF00897B),
      primaryColor: Color(0xFF00897B),
      accentColor: Color(0xFFFF6B35),
      appBarGradient: LinearGradient(
        colors: [Color(0xFF00695C), Color(0xFF00897B), Color(0xFF26A69A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      fabColor: Color(0xFFFF6B35),
      backgroundColor: Color(0xFF00897B),
      categoryColorPalettes: [
        [Color(0xFF00897B), Color(0xFF26A69A)],
        [Color(0xFF00695C), Color(0xFF004D40)],
        [Color(0xFF26C6DA), Color(0xFF00BCD4)],
        [Color(0xFF004D40), Color(0xFF00897B)],
        [Color(0xFF00838F), Color(0xFF0097A7)],
        [Color(0xFF00ACC1), Color(0xFF0097A7)],
        [Color(0xFF00796B), Color(0xFF00695C)],
        [Color(0xFF26A69A), Color(0xFF009688)],
        [Color(0xFF009688), Color(0xFF00897B)],
        [Color(0xFF00897B), Color(0xFF00695C)],
        [Color(0xFF1DE9B6), Color(0xFF00C9A7)],
        [Color(0xFF00BFA5), Color(0xFF009688)],
        [Color(0xFF26C6DA), Color(0xFF14BEB4)],
        [Color(0xFF006064), Color(0xFF00838F)],
        [Color(0xFF00868B), Color(0xFF00838F)],
        [Color(0xFF004D40), Color(0xFF00695C)],
      ],
    ),
    AppThemeType.deepOrange: AppTheme(
      type: AppThemeType.deepOrange,
      name: '🔥 Turuncu',
      seedColor: Color(0xFFFF6F00),
      primaryColor: Color(0xFFFF6F00),
      accentColor: Color(0xFFFFB74D),
      appBarGradient: LinearGradient(
        colors: [Color(0xFFE65100), Color(0xFFFF6F00), Color(0xFFFFB74D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      fabColor: Color(0xFFFFB74D),
      backgroundColor: Color(0xFFFF6F00),
      categoryColorPalettes: [
        [Color(0xFFFF6F00), Color(0xFFFF8F00)],
        [Color(0xFFE65100), Color(0xFFD84315)],
        [Color(0xFFFFB300), Color(0xFFFFA000)],
        [Color(0xFFFF5722), Color(0xFFFF6E40)],
        [Color(0xFFFF7043), Color(0xFFFF5722)],
        [Color(0xFFFF8A65), Color(0xFFFF7043)],
        [Color(0xFFD84315), Color(0xFFC62828)],
        [Color(0xFFFF9100), Color(0xFFFF6F00)],
        [Color(0xFFFFB74D), Color(0xFFFFA726)],
        [Color(0xFF6D4C41), Color(0xFF8D6E63)],
        [Color(0xFFFFCC80), Color(0xFFFFB74D)],
        [Color(0xFFFF8A50), Color(0xFFFF7043)],
        [Color(0xFFFF9100), Color(0xFFFF6D00)],
        [Color(0xFFF57C00), Color(0xFFE65100)],
        [Color(0xFFFF9100), Color(0xFFFF8F00)],
        [Color(0xFFBF360C), Color(0xFF6D4C41)],
      ],
    ),
    AppThemeType.deepPurple: AppTheme(
      type: AppThemeType.deepPurple,
      name: '💜 Mor',
      seedColor: Color(0xFF7B1FA2),
      primaryColor: Color(0xFF7B1FA2),
      accentColor: Color(0xFFCE93D8),
      appBarGradient: LinearGradient(
        colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFCE93D8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      fabColor: Color(0xFFCE93D8),
      backgroundColor: Color(0xFF7B1FA2),
      categoryColorPalettes: [
        [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
        [Color(0xFF4A148C), Color(0xFF6A1B9A)],
        [Color(0xFFAB47BC), Color(0xFF9C27B0)],
        [Color(0xFFBA68C8), Color(0xFFAB47BC)],
        [Color(0xFF8E24AA), Color(0xFF7B1FA2)],
        [Color(0xFFCE93D8), Color(0xFFBB86FC)],
        [Color(0xFF6A1B9A), Color(0xFF4A148C)],
        [Color(0xFF9C27B0), Color(0xFF8E24AA)],
        [Color(0xFFE1BEE7), Color(0xFFCE93D8)],
        [Color(0xFF512DA8), Color(0xFF4527A0)],
        [Color(0xFF7B1FA2), Color(0xFF6A1B9A)],
        [Color(0xFFB39DDB), Color(0xFF9575CD)],
        [Color(0xFFD1C4E9), Color(0xFFCE93D8)],
        [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
        [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
        [Color(0xFF4A148C), Color(0xFF512DA8)],
      ],
    ),
    AppThemeType.blue: AppTheme(
      type: AppThemeType.blue,
      name: '💙 Mavi',
      seedColor: Color(0xFF1976D2),
      primaryColor: Color(0xFF1976D2),
      accentColor: Color(0xFF42A5F5),
      appBarGradient: LinearGradient(
        colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      fabColor: Color(0xFF42A5F5),
      backgroundColor: Color(0xFF1976D2),
      categoryColorPalettes: [
        [Color(0xFF1976D2), Color(0xFF1E88E5)],
        [Color(0xFF0D47A1), Color(0xFF1565C0)],
        [Color(0xFF42A5F5), Color(0xFF64B5F6)],
        [Color(0xFF2196F3), Color(0xFF1E88E5)],
        [Color(0xFF1565C0), Color(0xFF0D47A1)],
        [Color(0xFF64B5F6), Color(0xFF42A5F5)],
        [Color(0xFF0D47A1), Color(0xFF1976D2)],
        [Color(0xFF1E88E5), Color(0xFF1976D2)],
        [Color(0xFF90CAF9), Color(0xFF64B5F6)],
        [Color(0xFF1E88E5), Color(0xFF1565C0)],
        [Color(0xFF2196F3), Color(0xFF1976D2)],
        [Color(0xFF82B1FF), Color(0xFF64B5F6)],
        [Color(0xFFBBDEFB), Color(0xFF90CAF9)],
        [Color(0xFF42A5F5), Color(0xFF1E88E5)],
        [Color(0xFF1976D2), Color(0xFF1565C0)],
        [Color(0xFF0D47A1), Color(0xFF0B3FA1)],
      ],
    ),
    AppThemeType.pink: AppTheme(
      type: AppThemeType.pink,
      name: '🌹 Pembe',
      seedColor: Color(0xFFC2185B),
      primaryColor: Color(0xFFC2185B),
      accentColor: Color(0xFFE91E63),
      appBarGradient: LinearGradient(
        colors: [Color(0xFF880E4F), Color(0xFFC2185B), Color(0xFFE91E63)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      fabColor: Color(0xFFE91E63),
      backgroundColor: Color(0xFFC2185B),
      categoryColorPalettes: [
        [Color(0xFFC2185B), Color(0xFFD81B60)],
        [Color(0xFF880E4F), Color(0xFFAD1457)],
        [Color(0xFFE91E63), Color(0xFFF48FB1)],
        [Color(0xFFE91E63), Color(0xFFD81B60)],
        [Color(0xFFAD1457), Color(0xFF880E4F)],
        [Color(0xFFF06292), Color(0xFFE91E63)],
        [Color(0xFF6A0DAD), Color(0xFF880E4F)],
        [Color(0xFFD81B60), Color(0xFFC2185B)],
        [Color(0xFFF48FB1), Color(0xFFF06292)],
        [Color(0xFFD81B60), Color(0xFFAD1457)],
        [Color(0xFFE91E63), Color(0xFFC2185B)],
        [Color(0xFFFF80AB), Color(0xFFF06292)],
        [Color(0xFFFCE4EC), Color(0xFFF48FB1)],
        [Color(0xFFF06292), Color(0xFFD81B60)],
        [Color(0xFFC2185B), Color(0xFFAD1457)],
        [Color(0xFF880E4F), Color(0xFF6A0DAD)],
      ],
    ),
    AppThemeType.green: AppTheme(
      type: AppThemeType.green,
      name: '💚 Yeşil',
      seedColor: Color(0xFF388E3C),
      primaryColor: Color(0xFF388E3C),
      accentColor: Color(0xFF66BB6A),
      appBarGradient: LinearGradient(
        colors: [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF66BB6A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      fabColor: Color(0xFF66BB6A),
      backgroundColor: Color(0xFF388E3C),
      categoryColorPalettes: [
        [Color(0xFF388E3C), Color(0xFF43A047)],
        [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        [Color(0xFF66BB6A), Color(0xFF81C784)],
        [Color(0xFF4CAF50), Color(0xFF43A047)],
        [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        [Color(0xFF81C784), Color(0xFF66BB6A)],
        [Color(0xFF1B5E20), Color(0xFF388E3C)],
        [Color(0xFF43A047), Color(0xFF388E3C)],
        [Color(0xFFA5D6A7), Color(0xFF81C784)],
        [Color(0xFF43A047), Color(0xFF2E7D32)],
        [Color(0xFF4CAF50), Color(0xFF388E3C)],
        [Color(0xFFB8E6B8), Color(0xFF81C784)],
        [Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
        [Color(0xFF81C784), Color(0xFF43A047)],
        [Color(0xFF388E3C), Color(0xFF2E7D32)],
        [Color(0xFF1B5E20), Color(0xFF0B3E1E)],
      ],
    ),
    AppThemeType.indigo: AppTheme(
      type: AppThemeType.indigo,
      name: '🎨 İndigo',
      seedColor: Color(0xFF303F9F),
      primaryColor: Color(0xFF303F9F),
      accentColor: Color(0xFF5C6BC0),
      appBarGradient: LinearGradient(
        colors: [Color(0xFF1A237E), Color(0xFF303F9F), Color(0xFF5C6BC0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      fabColor: Color(0xFF5C6BC0),
      backgroundColor: Color(0xFF303F9F),
      categoryColorPalettes: [
        [Color(0xFF303F9F), Color(0xFF3949AB)],
        [Color(0xFF1A237E), Color(0xFF283593)],
        [Color(0xFF5C6BC0), Color(0xFF7986CB)],
        [Color(0xFF4048DC), Color(0xFF3949AB)],
        [Color(0xFF283593), Color(0xFF1A237E)],
        [Color(0xFF7986CB), Color(0xFF5C6BC0)],
        [Color(0xFF1A237E), Color(0xFF303F9F)],
        [Color(0xFF3949AB), Color(0xFF303F9F)],
        [Color(0xFF9FA8DA), Color(0xFF7986CB)],
        [Color(0xFF3949AB), Color(0xFF283593)],
        [Color(0xFF4048DC), Color(0xFF303F9F)],
        [Color(0xFFC5CAE9), Color(0xFFA1A7E8)],
        [Color(0xFFE8EAF6), Color(0xFFC5CAE9)],
        [Color(0xFF7986CB), Color(0xFF3949AB)],
        [Color(0xFF303F9F), Color(0xFF283593)],
        [Color(0xFF1A237E), Color(0xFF0F146F)],
      ],
    ),
  };

  /// Canlılık seviyesine göre rengi ayarla (0.0 - 1.0)
  Color adjustColorVibrancy(Color color, double vibrancyLevel) {
    // vibrancyLevel: 0.0 = gri, 0.5 = normal, 1.0 = çok canlı
    final hsvColor = HSVColor.fromColor(color);
    final adjustedSaturation = (hsvColor.saturation * vibrancyLevel).clamp(0.0, 1.0);
    final adjustedValue = (hsvColor.value * (0.7 + 0.3 * vibrancyLevel)).clamp(0.0, 1.0);
    
    return hsvColor
        .withSaturation(adjustedSaturation)
        .withValue(adjustedValue)
        .toColor();
  }

  /// Canlılık seviyesine göre gradient renkleri ayarla
  LinearGradient adjustGradientVibrancy(LinearGradient gradient, double vibrancyLevel) {
    final adjustedColors = gradient.colors
        .map((color) => adjustColorVibrancy(color, vibrancyLevel))
        .toList();
    
    return LinearGradient(
      colors: adjustedColors,
      begin: gradient.begin,
      end: gradient.end,
    );
  }

  /// Kategori ID'sine göre renk paletinden bir renk pair'i al
  List<Color> getCategoryColors(int categoryIndex, double vibrancyLevel) {
    final colors = categoryColorPalettes[categoryIndex % categoryColorPalettes.length];
    return [
      adjustColorVibrancy(colors[0], vibrancyLevel),
      adjustColorVibrancy(colors[1], vibrancyLevel),
    ];
  }

  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fabColor,
      ),
      extensions: [
        AppThemeExtension(
          appBarGradient: appBarGradient,
          fabColor: fabColor,
          backgroundColor: backgroundColor,
          categoryColorPalettes: categoryColorPalettes,
        ),
      ],
    );
  }
}

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final LinearGradient appBarGradient;
  final Color fabColor;
  final Color backgroundColor;
  final List<List<Color>>? categoryColorPalettes;
  final double vibrancyLevel;

  AppThemeExtension({
    required this.appBarGradient,
    required this.fabColor,
    required this.backgroundColor,
    this.categoryColorPalettes,
    this.vibrancyLevel = 0.5,
  });

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    LinearGradient? appBarGradient,
    Color? fabColor,
    Color? backgroundColor,
    List<List<Color>>? categoryColorPalettes,
    double? vibrancyLevel,
  }) {
    return AppThemeExtension(
      appBarGradient: appBarGradient ?? this.appBarGradient,
      fabColor: fabColor ?? this.fabColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      categoryColorPalettes: categoryColorPalettes ?? this.categoryColorPalettes,
      vibrancyLevel: vibrancyLevel ?? this.vibrancyLevel,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      appBarGradient: other.appBarGradient,
      fabColor: Color.lerp(fabColor, other.fabColor, t) ?? fabColor,
      backgroundColor:
          Color.lerp(backgroundColor, other.backgroundColor, t) ?? backgroundColor,
      categoryColorPalettes: other.categoryColorPalettes ?? categoryColorPalettes,
      vibrancyLevel: t > 0.5 ? (other.vibrancyLevel) : vibrancyLevel,
    );
  }
}
