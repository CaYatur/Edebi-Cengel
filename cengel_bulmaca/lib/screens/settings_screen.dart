import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/theme_selector.dart';
import '../services/sound_service.dart';

/// Uygulama ayarları ekranı
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer2<SettingsProvider, ThemeProvider>(
        builder: (context, settings, themeProvider, _) {
          final isSettingsProvider = context.read<SettingsProvider>();
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // === TEMA AYARLARI ===
              _buildSectionTitle('🎨 Tema Ayarları'),
              
              // Tema Seçici Butonu
              _buildSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tema Seç',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                themeProvider.currentAppTheme.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: themeProvider.currentAppTheme.appBarGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const ThemeSelector(),
                        );
                      },
                      icon: const Icon(Icons.palette),
                      label: const Text('Temaları Gör'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Gelişmiş Tema Modu
              _buildSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '✨ Gelişmiş Tema Modu',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tüm ekranlarda temaya uygun renkler',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: themeProvider.advancedThemeEnabled,
                          onChanged: (value) {
                            SoundService.instance.playButtonClick();
                            themeProvider.setAdvancedThemeEnabled(value);
                          },
                          activeColor: themeProvider.currentAppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Renk Canlılığı Slider (Sadece Gelişmiş Mod Aktifken)
              if (themeProvider.advancedThemeEnabled) ...[
                const SizedBox(height: 12),
                _buildSettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Renk Canlılığı',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${(themeProvider.colorVibrancy * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: themeProvider.currentAppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: themeProvider.currentAppTheme.primaryColor,
                          thumbColor: themeProvider.currentAppTheme.primaryColor,
                          inactiveTrackColor: Colors.grey.shade300,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8.0,
                            elevation: 4.0,
                          ),
                        ),
                        child: Slider(
                          value: themeProvider.colorVibrancy,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          onChanged: (value) {
                            themeProvider.setColorVibrancy(value);
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Grileş', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          Text('Normal', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          Text('Canlı', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // === SES AYARLARI ===
              _buildSectionTitle('Ses Ayarları'),
              _buildSettingsCard(
                child: SwitchListTile(
                  title: const Text('Oyun Sesleri'),
                  subtitle: const Text('Buton sesleri ve oyun efektleri'),
                  value: settings.soundEnabled,
                  onChanged: (value) {
                    isSettingsProvider.setSoundEnabled(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 24),

              // === GRAFİK AYARLARI ===
              _buildSectionTitle('Grafik Ayarları'),
              
              // Animasyonlar
              _buildSettingsCard(
                child: SwitchListTile(
                  title: const Text('Animasyonları Aç'),
                  subtitle: const Text('UI geçişleri ve efektler'),
                  value: settings.animationsEnabled,
                  onChanged: (value) {
                    isSettingsProvider.setAnimationsEnabled(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 12),

              // Partiküller (yıldızlar, konfeti)
              _buildSettingsCard(
                child: SwitchListTile(
                  title: const Text('Dekoratif Efektler'),
                  subtitle: const Text('Yıldızlar, konfeti, partiküller'),
                  value: settings.particlesEnabled,
                  onChanged: (value) {
                    isSettingsProvider.setParticlesEnabled(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 12),

              // Animasyon Hızı
              if (settings.animationsEnabled)
                _buildSettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Animasyon Hızı',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: settings.animationSpeed.toDouble(),
                        min: 1,
                        max: 3,
                        divisions: 2,
                        label: _getSpeedLabel(settings.animationSpeed),
                        onChanged: (value) {
                          isSettingsProvider.setAnimationSpeed(value.toInt());
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Yavaş',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _getSpeedLabel(settings.animationSpeed),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              'Hızlı',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Reduced Motion (Engelli Mod)
              _buildSettingsCard(
                child: SwitchListTile(
                  title: const Text('Hareket Engelli Mod'),
                  subtitle: const Text(
                    'Hareketli efektleri azalt (erişilebilirlik)',
                  ),
                  value: settings.reducedMotion,
                  onChanged: (value) {
                    isSettingsProvider.setReducedMotion(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 12),

              // Her Zaman Hamburger Menüsünü Kullan
              _buildSettingsCard(
                child: SwitchListTile(
                  title: const Text('Her Zaman Hamburger Menüsünü Kullan'),
                  subtitle: const Text(
                    'Ekran boyutu ne olursa olsun hamburger menüsü göster',
                  ),
                  value: settings.alwaysUseHamburger,
                  onChanged: (value) {
                    isSettingsProvider.setAlwaysUseHamburger(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 32),

              // === GELIŞMIŞ TEMA KUSTOMİZASYONU ===
              _buildSectionTitle('🎯 Gelişmiş Tema Özelleştirmesi'),
              
              // Renk Canlılığı
              _buildSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Renk Canlılığı',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(settings.colorVibrancy * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeProvider.currentAppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: settings.colorVibrancy,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      onChanged: (value) {
                        isSettingsProvider.setColorVibrancy(value);
                      },
                      activeColor: themeProvider.currentAppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Arka Plan Stili
              _buildSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Arka Plan Stili',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStyleButton(
                            'Degrade',
                            'gradient',
                            settings.backgroundStyle,
                            isSettingsProvider,
                            context,
                          ),
                          const SizedBox(width: 8),
                          _buildStyleButton(
                            'Düz Renk',
                            'solid',
                            settings.backgroundStyle,
                            isSettingsProvider,
                            context,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Kart Stili
              _buildSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kart Tasarımı',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStyleButton(
                            'Kabarık',
                            'elevated',
                            settings.cardStyle,
                            isSettingsProvider,
                            context,
                            isCardStyle: true,
                          ),
                          const SizedBox(width: 8),
                          _buildStyleButton(
                            'Çerçeveli',
                            'outlined',
                            settings.cardStyle,
                            isSettingsProvider,
                            context,
                            isCardStyle: true,
                          ),
                          const SizedBox(width: 8),
                          _buildStyleButton(
                            'Dolu',
                            'filled',
                            settings.cardStyle,
                            isSettingsProvider,
                            context,
                            isCardStyle: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Kart Gölge Yüksekliği
              _buildSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kart Gölgesi',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          settings.cardElevation.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeProvider.currentAppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: settings.cardElevation,
                      min: 0.0,
                      max: 16.0,
                      divisions: 16,
                      onChanged: (value) {
                        isSettingsProvider.setCardElevation(value);
                      },
                      activeColor: themeProvider.currentAppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Köşe Yuvarlaklığı
              _buildSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Köşe Yuvarlaklığı',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          settings.borderRadius.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeProvider.currentAppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: settings.borderRadius,
                      min: 0.0,
                      max: 32.0,
                      divisions: 32,
                      onChanged: (value) {
                        isSettingsProvider.setBorderRadius(value);
                      },
                      activeColor: themeProvider.currentAppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Yazı Boyutu
              _buildSettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Yazı Boyutu',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(settings.fontSize * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeProvider.currentAppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: settings.fontSize,
                      min: 0.8,
                      max: 1.5,
                      divisions: 14,
                      onChanged: (value) {
                        isSettingsProvider.setFontSize(value);
                      },
                      activeColor: themeProvider.currentAppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Oyun Ekranı Animasyonları
              _buildSettingsCard(
                child: SwitchListTile(
                  title: const Text('Oyun Ekranı Efektleri'),
                  subtitle: const Text(
                    'Oyun ekranlarında particle ve visual efektler',
                  ),
                  value: settings.gameScreenAnimations,
                  onChanged: (value) {
                    isSettingsProvider.setGameScreenAnimations(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 32),

              // === PERFORMANS BİLGİSİ ===
              _buildPerformanceTips(settings),
              const SizedBox(height: 32),

              // === SIFIRLA BUTONU ===
              ElevatedButton.icon(
                onPressed: () {
                  _showResetDialog(context, isSettingsProvider);
                },
                icon: const Icon(Icons.restore),
                label: const Text('Varsayılan Ayarlara Dön'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  String _getSpeedLabel(int speed) {
    return switch (speed) {
      1 => 'Yavaş',
      2 => 'Normal',
      3 => 'Hızlı',
      _ => 'Normal',
    };
  }

  Widget _buildStyleButton(
    String label,
    String value,
    String currentValue,
    SettingsProvider provider,
    BuildContext context, {
    bool isCardStyle = false,
  }) {
    final isSelected = currentValue == value;
    return ElevatedButton(
      onPressed: () {
        if (isCardStyle) {
          provider.setCardStyle(value);
        } else {
          provider.setBackgroundStyle(value);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade300,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildPerformanceTips(SettingsProvider settings) {
    final tips = <String>[];
    
    if (!settings.soundEnabled) {
      tips.add('Ses kapalı (pil tasarrufu ✓)');
    }
    if (!settings.animationsEnabled) {
      tips.add('Animasyonlar devre dışı (daha hızlı)');
    }
    if (!settings.particlesEnabled) {
      tips.add('Efektler kapalı (bellek tasarrufu)');
    }
    if (settings.reducedMotion) {
      tips.add('Reduced motion modu açık');
    }

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Aktif Optimizasyonlar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tips.isEmpty)
              Text(
                'Tüm ayarlar varsayılana ayarlı',
                style: TextStyle(color: Colors.blue.shade600),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: tips
                    .map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(tip),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ayarları Sıfırla'),
        content: const Text(
          'Tüm ayarlar varsayılan değerlere döner. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              settings.resetToDefaults();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ayarlar varsayılana döndürüldü'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
  }
}
