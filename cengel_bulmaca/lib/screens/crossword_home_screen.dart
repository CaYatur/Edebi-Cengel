import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crossword_provider.dart';
import '../providers/theme_provider.dart';
import '../models/crossword_category.dart';
import '../models/game_badge.dart';
import '../models/player_stats.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import '../widgets/theme_selector.dart';
import 'crossword_game_screen.dart';
import 'ai_puzzle_screen.dart';
import 'auth_screen.dart';
import 'author_portraits_screen.dart';
import 'grammar_home_screen.dart';
import 'literature_periods_screen.dart';
import 'leaderboard_screen.dart';
import 'multiplayer_lobby_screen.dart';
import 'classroom/classroom_lobby_screen.dart';
import 'settings_screen.dart';
import 'success_analysis_screen.dart';

class CrosswordHomeScreen extends StatefulWidget {
  const CrosswordHomeScreen({Key? key}) : super(key: key);

  @override
  State<CrosswordHomeScreen> createState() => _CrosswordHomeScreenState();
}

class _CrosswordHomeScreenState extends State<CrosswordHomeScreen> with TickerProviderStateMixin {
  int _selectedDifficulty = 0; // Varsayılan: Karışık
  int _wordCount = 10;
  final _sound = SoundService.instance;

  bool _aiStatusReady = false;
  bool _aiEnabled = false;
  bool _aiChecking = false;
  Timer? _aiStatusTimer;

  bool _previousUseHamburger = false; // Responsive durum takibi
  int _drawerKeyCounter = 0; // Drawer'ı key değiştirerek reset et

  late AnimationController _headerAnimCtrl;
  late AnimationController _cardAnimCtrl;
  late AnimationController _fabAnimCtrl;
  late Animation<double> _headerFade;
  late Animation<double> _fabScale;

  final ScrollController _gridScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final _animEnabled = SettingsService.instance.animationsEnabled;

    _headerAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _headerFade = CurvedAnimation(parent: _headerAnimCtrl, curve: Curves.easeOutCubic);

    _cardAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fabAnimCtrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fabScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _fabAnimCtrl, curve: Curves.easeInOut),
    );

    if (_animEnabled) {
      _headerAnimCtrl.forward();
      _cardAnimCtrl.forward();
      _fabAnimCtrl.repeat(reverse: true);
    } else {
      _headerAnimCtrl.value = 1.0;
      _cardAnimCtrl.value = 1.0;
      _fabAnimCtrl.value = 0.0; // Scale = 1.0 (no pulse)
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CrosswordProvider>();
      // Eski oyun state'ini temizle
      provider.clearLastCompletedWord();
      // Provider initialize et
      provider.initialize();
      _sound.playWelcome();
      _checkAIStatus();
    });
  }

  @override
  void dispose() {
    _headerAnimCtrl.dispose();
    _cardAnimCtrl.dispose();
    _fabAnimCtrl.dispose();
    _aiStatusTimer?.cancel();
    _gridScrollCtrl.dispose();
    super.dispose();
  }

  /// Ayarlara göre sayfa geçiş route'u oluşturur
  Route _buildPageRoute(Widget page) {
    if (!SettingsService.instance.animationsEnabled) {
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AuthService'i watch ederek giriş/çıkışta otomatik yeniden çizilmesini sağla
    final auth = context.watch<AuthService>();
    
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final currentTheme = themeProvider.currentAppTheme;
        
        final screenWidth = MediaQuery.of(context).size.width;
        final useHamburger = SettingsService.instance.alwaysUseHamburger || screenWidth < 600;
        
        // Responsive durum değiştiğinde drawer'ı kapat
        if (_previousUseHamburger != useHamburger) {
          _previousUseHamburger = useHamburger;
          _drawerKeyCounter++;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              final scaffold = Scaffold.maybeOf(context);
              if (scaffold != null && scaffold.isEndDrawerOpen) {
                scaffold.closeEndDrawer();
              }
            } catch (e) {
              // Hata varsa devam et
            }
          });
        }
        
        return Scaffold(
          endDrawer: _buildHamburgerDrawer(auth, currentTheme, ValueKey(_drawerKeyCounter)),
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/media/logo.png',
                    height: 36,
                    width: 36,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.grid_on, size: 36),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Edebi Çengel',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            backgroundColor: currentTheme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: currentTheme.appBarGradient,
              ),
            ),
        actions: useHamburger
          ? [
              Builder(
                builder: (ctx) => _buildLabeledMenuButton(ctx),
              ),
            ]
          : [
          // Tema Seçici
          Tooltip(
            message: 'Temayı Değiştir',
            child: IconButton(
              icon: const Icon(Icons.palette_outlined),
              onPressed: () {
                _sound.playNavigation();
                showDialog(
                  context: context,
                  builder: (context) => const ThemeSelector(),
                );
              },
            ),
          ),
          // Yazar Portreleri
          Tooltip(
            message: 'Yazar Portreleri',
            child: IconButton(
              icon: const Icon(Icons.person_search),
              onPressed: () {
                _sound.playNavigation();
                Navigator.push(context, _buildPageRoute(const AuthorPortraitsScreen()));
              },
            ),
          ),
          // Dil Bilgisi
          Tooltip(
            message: 'Dil Bilgisi Soruları',
            child: IconButton(
              icon: const Icon(Icons.spellcheck),
              onPressed: () {
                _sound.playNavigation();
                Navigator.push(context, _buildPageRoute(const GrammarHomeScreen()));
              },
            ),
          ),
          // Edebiyat Donemleri
          Tooltip(
            message: 'Edebiyat Dönemleri',
            child: IconButton(
              icon: const Icon(Icons.menu_book_rounded),
              onPressed: () {
                _sound.playNavigation();
                Navigator.push(context, _buildPageRoute(const LiteraturePeriodsScreen()));
              },
            ),
          ),
          // Çoklu Oyuncu
          Tooltip(
            message: 'Çoklu Oyuncu',
            child: IconButton(
              icon: const Icon(Icons.groups_rounded),
              onPressed: () {
                _sound.playNavigation();
                Navigator.push(context, _buildPageRoute(const MultiplayerLobbyScreen()));
              },
            ),
          ),
          // Sınıf Modu
          Tooltip(
            message: 'Sınıf Modu',
            child: IconButton(
              icon: const Icon(Icons.school_rounded),
              onPressed: () {
                _sound.playNavigation();
                Navigator.push(context, _buildPageRoute(const ClassroomLobbyScreen()));
              },
            ),
          ),
          // Sıralama Tablosu
          Tooltip(
            message: 'Sıralama',
            child: IconButton(
              icon: const Icon(Icons.leaderboard),
              onPressed: () {
                _sound.playNavigation();
                Navigator.push(context, _buildPageRoute(const LeaderboardScreen()));
              },
            ),
          ),
          // Çözülen Bulmacalar
          Tooltip(
            message: 'Çözülen Bulmacalar',
            child: IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                _sound.playButtonClick();
                _showSolvedPuzzlesDialog();
              },
            ),
          ),
          // Konu Bazlı Başarı Analizi
          Tooltip(
            message: 'Konu Bazlı Başarı',
            child: IconButton(
              icon: const Icon(Icons.insights),
              onPressed: () {
                _sound.playNavigation();
                Navigator.push(context, _buildPageRoute(const SuccessAnalysisScreen()));
              },
            ),
          ),
          // Ayarlar
          Tooltip(
            message: 'Ayarlar',
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                _sound.playNavigation();
                Navigator.push(context, _buildPageRoute(const SettingsScreen())).then((_) {
                  setState(() {});
                });
              },
            ),
          ),
          // Profil / Giriş butonu
          Tooltip(
            message: auth.isLoggedIn ? 'Profil' : 'Giriş Yap',
            child: IconButton(
              icon: Icon(
                auth.isLoggedIn ? Icons.account_circle : Icons.login,
              ),
              onPressed: () {
                _sound.playButtonClick();
                _handleProfileOrLogin();
              },
            ),
          ),
        ],
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final currentTheme = themeProvider.currentAppTheme;
          final settings = SettingsService.instance;
          
          // Arka plan stilini ayarlardan al
          BoxDecoration buildBackgroundDecoration() {
            switch (settings.backgroundStyle) {
              case 'solid':
                return BoxDecoration(
                  color: currentTheme.primaryColor.withOpacity(0.05),
                );
              case 'gradient':
              default:
                return BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      currentTheme.primaryColor.withOpacity(0.05),
                      Colors.white,
                      const Color(0xFFFFF8E1),
                    ],
                  ),
                );
            }
          }
          
          return Container(
            decoration: buildBackgroundDecoration(),
            child: Consumer<CrosswordProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              currentTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Bulmacalar yükleniyor...', 
                          style: TextStyle(fontSize: 16 * settings.fontSize)),
                      ],
                    ),
                  );
                }

                if (provider.error != null) {
                  return _buildErrorWidget(provider);
                }

                return _buildCategoriesTab(provider);
              },
            ),
          );
        },
      ),
      bottomNavigationBar: _buildQuickAccessBar(currentTheme),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: themeProvider.currentAppTheme.fabColor.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () {
              _sound.playGameStart();
              _startMixedGame();
            },
            icon: const Icon(Icons.shuffle),
            label: const Text('Karışık Bulmaca', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: themeProvider.currentAppTheme.fabColor,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
    },
    );
  }

  Widget _buildLabeledMenuButton(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Scaffold.of(ctx).openEndDrawer(),
          borderRadius: BorderRadius.circular(10),
          child: Tooltip(
            message: 'Menü',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.menu, color: Colors.white, size: 24),
                  SizedBox(height: 2),
                  Text(
                    'Menü',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessBar(dynamic currentTheme) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            return Row(
              children: [
                Expanded(
                  child: _quickAccessItem(
                    icon: Icons.person_search,
                    label: compact ? 'Yazarlar' : 'Yazar Portreleri',
                    color: currentTheme.primaryColor,
                    onTap: () {
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const AuthorPortraitsScreen()));
                    },
                  ),
                ),
                Expanded(
                  child: _quickAccessItem(
                    icon: Icons.spellcheck,
                    label: compact ? 'Dil Bilgisi' : 'Dil Bilgisi Soruları',
                    color: currentTheme.primaryColor,
                    onTap: () {
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const GrammarHomeScreen()));
                    },
                  ),
                ),
                Expanded(
                  child: _quickAccessItem(
                    icon: Icons.menu_book_rounded,
                    label: compact ? 'Dönemler' : 'Edebiyat Dönemleri',
                    color: currentTheme.primaryColor,
                    onTap: () {
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const LiteraturePeriodsScreen()));
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _quickAccessItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHamburgerDrawer(AuthService auth, dynamic currentTheme, Key? drawerKey) {
    return Drawer(
      key: drawerKey,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: currentTheme.appBarGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/media/logo.png',
                      height: 48,
                      width: 48,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.grid_on, size: 48, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Edebi Çengel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  if (auth.isLoggedIn)
                    Text(
                      auth.displayName ?? auth.username ?? '',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Temayı Değiştir'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playNavigation();
                      showDialog(
                        context: context,
                        builder: (context) => const ThemeSelector(),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_search),
                    title: const Text('Yazar Portreleri'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const AuthorPortraitsScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.spellcheck),
                    title: const Text('Dil Bilgisi Soruları'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const GrammarHomeScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.menu_book_rounded),
                    title: const Text('Edebiyat Dönemleri'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const LiteraturePeriodsScreen()));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.groups_rounded),
                    title: const Text('Çoklu Oyuncu'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const MultiplayerLobbyScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.school_rounded),
                    title: const Text('Sınıf Modu'),
                    subtitle: const Text('Öğretmen & Öğrenci'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const ClassroomLobbyScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.leaderboard),
                    title: const Text('Sıralama Tablosu'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const LeaderboardScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Çözülen Bulmacalar'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playButtonClick();
                      _showSolvedPuzzlesDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.insights),
                    title: const Text('Konu Bazlı Başarı'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const SuccessAnalysisScreen()));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Ayarlar'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playNavigation();
                      Navigator.push(context, _buildPageRoute(const SettingsScreen())).then((_) {
                        setState(() {});
                      });
                    },
                  ),
                  ListTile(
                    leading: Icon(auth.isLoggedIn ? Icons.account_circle : Icons.login),
                    title: Text(auth.isLoggedIn ? 'Profil' : 'Giriş Yap'),
                    onTap: () {
                      Navigator.pop(context);
                      _sound.playButtonClick();
                      _handleProfileOrLogin();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(CrosswordProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Hata!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.initialize(),
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab(CrosswordProvider provider) {
    if (provider.categories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Henüz kategori yüklenmemiş',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildPlayerStatsHeader(provider),
        _buildSettingsBar(),
        if (_canShowAIButton) _buildAIPuzzleButton(),
        Expanded(
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.03, 0.97, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isLandscape =
                    MediaQuery.of(context).orientation == Orientation.landscape;

                // Dinamik olarak sütun sayısı, kenar boşluğu ve oranı hesapla
                int crossAxisCount;
                double leftPad = 16;
                double rightPad = 22; // Scrollbar payı dahil
                double spacing = 12;
                double aspectRatio = 1.0;

                if (isLandscape) {
                  crossAxisCount = (width / 150).toInt().clamp(3, 6);
                } else if (width < 340) {
                  // Çok dar (küçük telefon / bölünmüş ekran)
                  crossAxisCount = 2;
                  leftPad = 8;
                  rightPad = 14;
                  spacing = 8;
                  aspectRatio = 0.9;
                } else if (width < 420) {
                  // Standart telefon
                  crossAxisCount = 2;
                  leftPad = 12;
                  rightPad = 18;
                  spacing = 10;
                  aspectRatio = 0.95;
                } else {
                  // Geniş portre / tablet
                  crossAxisCount = 2;
                }

                return Scrollbar(
                  controller: _gridScrollCtrl,
                  thumbVisibility: false,
                  thickness: 6,
                  radius: const Radius.circular(8),
                  child: GridView.builder(
                    controller: _gridScrollCtrl,
                    padding: EdgeInsets.fromLTRB(leftPad, 16, rightPad, 110),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: aspectRatio,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                    ),
                    itemCount: provider.categories.length,
                    itemBuilder: (context, index) {
                      return _buildAnimatedCategoryCard(provider.categories[index], index);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIPuzzleButton() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final currentTheme = themeProvider.currentAppTheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () {
              _sound.playNavigation();
              Navigator.push(context, _buildPageRoute(const AIPuzzleScreen()));
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    currentTheme.primaryColor.withOpacity(0.85),
                    currentTheme.primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: currentTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI ile Bulmaca Oluştur',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Yapay zeka sana özel bulmaca hazırlasın!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _canShowAIButton => _aiStatusReady && _aiEnabled;

  Future<void> _checkAIStatus() async {
    if (_aiChecking) return;
    setState(() {
      _aiChecking = true;
    });

    final response = await ApiService.instance.checkAIStatus();

    if (!mounted) return;

    setState(() {
      _aiChecking = false;
      _aiStatusReady = response.isSuccess;
      _aiEnabled = response.isSuccess && (response.data?['aiEnabled'] == true);
    });

    if (!response.isSuccess) {
      _scheduleAIStatusRetry();
    } else {
      _aiStatusTimer?.cancel();
    }
  }

  void _scheduleAIStatusRetry() {
    _aiStatusTimer?.cancel();
    _aiStatusTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        _checkAIStatus();
      }
    });
  }

  Widget _buildSettingsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // Zorluk seçici
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Zorluk',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Hepsi', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 1, label: Text('Kolay', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 2, label: Text('Orta', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 3, label: Text('Zor', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_selectedDifficulty},
                  onSelectionChanged: (Set<int> selection) {
                    setState(() {
                      _selectedDifficulty = selection.first;
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Kelime sayısı seçici
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kelime',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              DropdownButton<int>(
                value: _wordCount,
                items: [6, 8, 10, 12, 15]
                    .map((c) => DropdownMenuItem(value: c, child: Text('$c')))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _wordCount = value;
                    });
                  }
                },
                isDense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCategoryCard(CrosswordCategory category, int index) {
    if (!SettingsService.instance.animationsEnabled) {
      return _buildCategoryCard(category, index);
    }
    final delay = index * 80;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Transform.scale(scale: 0.8 + 0.2 * value, child: child),
          ),
        );
      },
      child: _buildCategoryCard(category, index),
    );
  }

  Widget _buildCategoryCard(CrosswordCategory category, int categoryIndex) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final settings = SettingsService.instance;
        
        // Kategori için renk belirleme
        List<Color> colors;
        if (themeProvider.advancedThemeEnabled) {
          // Gelişmiş tema modunda: temaya uygun renkler
          colors = themeProvider.currentAppTheme.getCategoryColors(
            categoryIndex,
            themeProvider.colorVibrancy,
          );
        } else {
          // Normal modes: eski sistem
          colors = _getCategoryColors(category.id);
        }
        
        // Seçilen zorlukta kaç soru var
        int clueCount = _getClueCountForDifficulty(category, _selectedDifficulty);
        bool hasEnoughClues = clueCount >= 3; // En az 3 soru olmalı

        // Kart stiline göre Card oluştur
        Widget buildCard(Widget child) {
          final roundedBorder = RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(settings.borderRadius),
          );
          
          switch (settings.cardStyle) {
            case 'outlined':
              return Card(
                shape: roundedBorder.copyWith(
                  side: BorderSide(
                    color: hasEnoughClues ? colors.first : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                elevation: 0,
                child: child,
              );
            case 'filled':
              return Card(
                color: hasEnoughClues ? colors.first.withOpacity(0.15) : Colors.grey.shade200,
                shape: roundedBorder,
                elevation: 0,
                child: child,
              );
            case 'elevated':
            default:
              return Card(
                elevation: hasEnoughClues ? settings.cardElevation : 1,
                shape: roundedBorder,
                child: child,
              );
          }
        }

        return buildCard(
          InkWell(
            onTap: hasEnoughClues ? () {
              _sound.playCategorySelect();
              // Eğer hamburger menü açıksa kapat
              if (Scaffold.of(context).hasEndDrawer) {
                Navigator.maybePop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startCategoryGame(category);
                });
              } else {
                _startCategoryGame(category);
              }
            } : () => _showNoCluesWarning(category),
            borderRadius: BorderRadius.circular(settings.borderRadius),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(settings.borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: hasEnoughClues ? colors : [Colors.grey.shade400, Colors.grey.shade600],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(settings.borderRadius),
                  color: Colors.white.withOpacity(0.08),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getCategoryIcon(category.id),
                        size: 40,
                        color: Colors.white.withOpacity(hasEnoughClues ? 1.0 : 0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14 * settings.fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(hasEnoughClues ? 1.0 : 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasEnoughClues ? Colors.white24 : Colors.red.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hasEnoughClues ? '$clueCount soru' : 'Soru yok',
                          style: TextStyle(
                            fontSize: 11 * settings.fontSize,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _getClueCountForDifficulty(CrosswordCategory category, int difficulty) {
    switch (difficulty) {
      case 0: return category.totalClues;
      case 1: return category.easyClues.length;
      case 2: return category.mediumClues.length;
      case 3: return category.hardClues.length;
      default: return category.totalClues;
    }
  }

  void _showNoCluesWarning(CrosswordCategory category) {
    String difficultyName = _getDifficultyName(_selectedDifficulty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${category.name} kategorisinde $difficultyName zorlukta yeterli soru yok.'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'Karışık Dene',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _selectedDifficulty = 0;
            });
          },
        ),
      ),
    );
  }

  String _getDifficultyName(int difficulty) {
    switch (difficulty) {
      case 0: return 'Hepsi';
      case 1: return 'Kolay';
      case 2: return 'Orta';
      case 3: return 'Zor';
      default: return 'Hepsi';
    }
  }

  List<Color> _getCategoryColors(String categoryId) {
    final colorMap = {
      'islamiyet_oncesi': [Colors.amber.shade600, Colors.orange.shade800],
      'ilk_islami_eserler': [Colors.green.shade600, Colors.teal.shade800],
      '13_14_yuz_yil': [Colors.indigo.shade500, Colors.indigo.shade800],
      'asik_tekke_edebiyati': [Colors.red.shade600, Colors.pink.shade800],
      'genel_1': [Colors.blue.shade600, Colors.indigo.shade800],
      'genel_2': [Colors.cyan.shade600, Colors.blue.shade800],
      'divan_edebiyati_1': [Colors.brown.shade600, Colors.brown.shade900],
      'divan_edebiyati_2': [Colors.deepOrange.shade600, Colors.deepOrange.shade900],
      'divan_edebiyati_3': [Colors.amber.shade700, Colors.brown.shade800],
      'tanzimat_edebiyati_1': [Colors.teal.shade600, Colors.green.shade900],
      'tanzimat_edebiyati_2': [Colors.lightGreen.shade600, Colors.green.shade800],
      'serveti_funun': [Colors.indigo.shade600, Colors.blue.shade900],
      'fecri_ati': [Colors.pink.shade600, Colors.pink.shade900],
      'milli_edebiyat': [Colors.red.shade700, Colors.red.shade900],
      'cumhuriyet_donemi_1': [Colors.blueGrey.shade600, Colors.blueGrey.shade900],
      'cumhuriyet_donemi_2': [Colors.grey.shade700, Colors.grey.shade900],
    };

    return colorMap[categoryId] ?? [Colors.blue.shade600, Colors.blue.shade900];
  }

  IconData _getCategoryIcon(String categoryId) {
    final iconMap = {
      'islamiyet_oncesi': Icons.auto_stories,
      'ilk_islami_eserler': Icons.menu_book,
      '13_14_yuz_yil': Icons.history_edu,
      'asik_tekke_edebiyati': Icons.music_note,
      'genel_1': Icons.school,
      'genel_2': Icons.school,
      'divan_edebiyati_1': Icons.edit_note,
      'divan_edebiyati_2': Icons.edit_note,
      'divan_edebiyati_3': Icons.edit_note,
      'tanzimat_edebiyati_1': Icons.bookmark,
      'tanzimat_edebiyati_2': Icons.bookmark,
      'serveti_funun': Icons.library_books,
      'fecri_ati': Icons.wb_sunny,
      'milli_edebiyat': Icons.flag,
      'cumhuriyet_donemi_1': Icons.account_balance,
      'cumhuriyet_donemi_2': Icons.account_balance,
    };

    return iconMap[categoryId] ?? Icons.category;
  }

  Future<void> _startCategoryGame(CrosswordCategory category) async {
    final provider = context.read<CrosswordProvider>();
    await provider.startGameFromCategory(
      category.id,
      wordCount: _wordCount,
      difficulty: _selectedDifficulty,
      gridSize: 15,
    );

    if (mounted && provider.currentPuzzle != null) {
      Navigator.push(context, _buildGamePageRoute());
    }
  }

  Future<void> _startMixedGame() async {
    final provider = context.read<CrosswordProvider>();
    await provider.startMixedGame(
      wordCount: _wordCount,
      gridSize: 15,
    );

    if (mounted && provider.currentPuzzle != null) {
      Navigator.push(context, _buildGamePageRoute());
    }
  }

  /// Oyun ekranına geçiş route'u (animasyonlu veya instant)
  Route _buildGamePageRoute() {
    if (!SettingsService.instance.animationsEnabled) {
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const CrosswordGameScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const CrosswordGameScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  // === Oyuncu İstatistik Başlığı ===
  Widget _buildPlayerStatsHeader(CrosswordProvider provider) {
    final auth = AuthService.instance;
    final stats = provider.playerStats;
    return FadeTransition(
      opacity: _headerFade,
      child: GestureDetector(
        onTap: () {
          _sound.playButtonClick();
          _showPlayerProfileDialog(stats);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
                Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
          children: [
            // Rütbe ikonu
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getRankIconData(stats.rankIcon),
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            // Rütbe ve puan
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          stats.rank,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (auth.isLoggedIn) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            auth.displayName ?? auth.username ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stats.totalPuzzlesCompleted} bulmaca çözüldü',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Toplam puan
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${stats.totalScore}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Rozet sayısı
            if (stats.earnedBadgeIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech, color: Colors.amber, size: 18),
                    const SizedBox(width: 2),
                    Text(
                      '${stats.earnedBadgeIds.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  // === Profil veya Giriş İşlemi ===
  void _handleProfileOrLogin() async {
    final auth = AuthService.instance;
    if (auth.isLoggedIn) {
      _showAccountDialog();
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
      if (result == true && mounted) {
        setState(() {}); // Giriş başarılı, UI güncelle
        // Giriş sonrası istatistikleri sunucuya senkronize et
        auth.syncAfterPuzzle();
      }
    }
  }

  // === Hesap Dialog (Giriş yapılmışken) ===
  void _showAccountDialog() {
    final auth = AuthService.instance;
    showDialog(
      context: context,
      builder: (context) {
        final primaryColor = Theme.of(context).colorScheme.primary;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.account_circle, color: primaryColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.displayName ?? auth.username ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (auth.username != null)
                      Text(
                        '@${auth.username}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.leaderboard, color: Colors.amber),
                title: const Text('Sıralama Tablosu'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync, color: Colors.blue),
                title: const Text('İstatistikleri Senkronize Et'),
                onTap: () async {
                  Navigator.pop(context);
                  await auth.syncAfterPuzzle();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('İstatistikler senkronize edildi'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Çıkış Yap'),
                onTap: () async {
                  Navigator.pop(context);
                  await auth.logout();
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Çıkış yapıldı'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  // === Oyuncu Profil Dialog ===
  void _showPlayerProfileDialog(PlayerStats stats) {
    final screenSize = MediaQuery.of(context).size;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenSize.width > 500 ? 400 : screenSize.width - 40,
              maxHeight: screenSize.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _getRankIconData(stats.rankIcon),
                        size: 40,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stats.rank,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade600,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '${stats.totalScore} Puan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // İstatistikler
                        _buildStatRow(Icons.extension, 'Çözülen Bulmaca', '${stats.totalPuzzlesCompleted}'),
                        _buildStatRow(Icons.text_fields, 'Tamamlanan Kelime', '${stats.totalWordsCompleted}'),
                        _buildStatRow(Icons.grid_on, 'Doldurulan Hücre', '${stats.totalCellsFilled}'),
                        _buildStatRow(Icons.lightbulb_outline, 'Kullanılan İpucu', '${stats.totalHintsUsed}'),
                        if (stats.fastestPuzzleSeconds > 0)
                          _buildStatRow(Icons.timer, 'En Hızlı Çözüm', _formatDuration(stats.fastestPuzzleSeconds)),
                        _buildStatRow(Icons.local_fire_department, 'En İyi Seri', '${stats.bestStreak}'),
                        // Rozetler
                        if (stats.earnedBadgeIds.isNotEmpty) ...[
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.military_tech, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Rozetler (${stats.earnedBadgeIds.length}/${BadgeDefinitions.allBadges.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: BadgeDefinitions.allBadges.map((badge) {
                                  final isEarned = stats.earnedBadgeIds.contains(badge.id);
                                  return _buildBadgeChip(badge, isEarned);
                                }).toList(),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Kapat butonu
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(GameBadge badge, bool isEarned) {
    return Container(
      width: 90,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isEarned ? Colors.amber.shade50 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEarned ? Colors.amber.shade400 : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                _getBadgeIcon(isEarned ? badge.icon : '🔒'),
                size: 28,
                color: isEarned ? Colors.amber.shade700 : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isEarned ? Colors.black87 : Colors.grey,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Rütbe/rozet emoji'sini ikon'a dönüştür
  IconData _getRankIconData(String rankStr) {
    switch (rankStr) {
      case 'crown': return Icons.grade;
      case 'emoji_events': return Icons.emoji_events;
      case 'star': return Icons.star;
      case 'target': return Icons.gps_fixed;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'library_books': return Icons.library_books;
      case 'edit': return Icons.edit_note;
      case 'sprout': return Icons.nature;
      default: return Icons.nature;
    }
  }

  /// Rozet emoji'sini ikon'a dönüştür
  IconData _getBadgeIcon(String badgeIcon) {
    switch (badgeIcon) {
      case '🎉':
      case 'celebration':
        return Icons.celebration;
      case '🧩':
      case 'puzzle':
        return Icons.extension_rounded;
      case '🏅':
      case 'military_tech':
        return Icons.military_tech;
      case '🏆':
      case 'emoji_events':
        return Icons.emoji_events;
      case '⚡':
      case 'flash_on':
        return Icons.flash_on;
      case '🚀':
      case 'rocket':
        return Icons.rocket;
      case '🧠':
      case 'psychology':
        return Icons.psychology;
      case '💎':
      case 'diamond':
        return Icons.diamond;
      case '🔥':
      case 'local_fire_department':
        return Icons.local_fire_department;
      case '🎯':
      case 'track_changes':
        return Icons.track_changes;
      case '📖':
      case 'menu_book':
        return Icons.menu_book;
      case '🗺️':
      case 'public':
        return Icons.public;
      case '📚':
      case 'library_books':
        return Icons.library_books;
      case '⭐':
      case 'star':
        return Icons.star;
      case '🌟':
      case 'star_rate':
        return Icons.star_rate;
      case '👑':
      case 'crown':
        return Icons.grade;
      case '🔒':
      case 'lock':
        return Icons.lock_outline;
      default:
        return Icons.emoji_events;
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return '${min}dk ${sec}s';
  }

  /// Çözülen bulmacaları ve istatistikleri gösteren dialog
  void _showSolvedPuzzlesDialog() {
    final stats = context.read<CrosswordProvider>().playerStats;
    final screenSize = MediaQuery.of(context).size;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenSize.width > 500 ? 450 : screenSize.width - 40,
              maxHeight: screenSize.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Çözülen Bulmacalar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Toplam ${stats.totalPuzzlesCompleted} bulmaca',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // İstatistikler
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        // Ana İstatistikler
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              _buildStatItem(
                                Icons.extension,
                                'Tamamlanan Bulmaca',
                                '${stats.totalPuzzlesCompleted}',
                                Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 8),
                              _buildStatItem(
                                Icons.text_fields,
                                'Tamamlanan Kelime',
                                '${stats.totalWordsCompleted}',
                                Colors.green,
                              ),
                              const SizedBox(height: 8),
                              _buildStatItem(
                                Icons.grid_on,
                                'Doldurulan Hücre',
                                '${stats.totalCellsFilled}',
                                Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Ek İstatistikler
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Column(
                            children: [
                              _buildStatItem(
                                Icons.lightbulb_outline,
                                'Kullanılan İpucu',
                                '${stats.totalHintsUsed}',
                                Colors.orange,
                              ),
                              const SizedBox(height: 8),
                              if (stats.fastestPuzzleSeconds > 0)
                                _buildStatItem(
                                  Icons.timer,
                                  'En Hızlı Çözüm',
                                  _formatDuration(stats.fastestPuzzleSeconds),
                                  Colors.red,
                                ),
                              if (stats.fastestPuzzleSeconds > 0)
                                const SizedBox(height: 8),
                              _buildStatItem(
                                Icons.local_fire_department,
                                'En İyi Seri',
                                '${stats.bestStreak} bulmaca',
                                Colors.deepOrange,
                              ),
                              const SizedBox(height: 8),
                              _buildStatItem(
                                Icons.category,
                                'Oynanan Kategori',
                                '${stats.playedCategories.length}',
                                Colors.teal,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Kapat Butonu
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Kapat'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// İstatistik satırını oluşturan helper widget
  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
