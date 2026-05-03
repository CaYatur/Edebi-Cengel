import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crossword_provider.dart';
import '../providers/theme_provider.dart';
import '../models/crossword_category.dart';
import '../models/crossword_puzzle.dart';
import '../models/crossword_word.dart';
import '../models/player_stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import 'crossword_game_screen.dart';

/// Konu (kategori) bazlı başarı analiz ekranı
/// Edebiyat + Dil Bilgisi tüm kategorileri gösterir
/// Doğru/yanlış kelime sayısı, zayıf konu önerisi ve detay görünümü içerir
/// Her konu için AI destekli 5 soruluk çengel bulmaca oluşturma seçeneği sunar
class SuccessAnalysisScreen extends StatefulWidget {
  const SuccessAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<SuccessAnalysisScreen> createState() => _SuccessAnalysisScreenState();
}

class _SuccessAnalysisScreenState extends State<SuccessAnalysisScreen> {
  bool _aiCanGenerate = true;
  int _aiRemainingSeconds = 0;
  bool _isAIGenerating = false;
  Timer? _countdownTimer;

  // AI özelliği yalnızca sunucu aiEnabled döndürdüğünde görünür
  bool _aiStatusReady = false;
  bool _aiEnabled = false;
  bool _aiChecking = false;
  Timer? _aiStatusTimer;

  bool get _canShowAI => _aiStatusReady && _aiEnabled;

  @override
  void initState() {
    super.initState();
    _checkAIStatus();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _aiStatusTimer?.cancel();
    super.dispose();
  }

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
      if (_aiEnabled) {
        _refreshAIRateLimit();
      }
    }
  }

  void _scheduleAIStatusRetry() {
    _aiStatusTimer?.cancel();
    _aiStatusTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) _checkAIStatus();
    });
  }

  Future<void> _refreshAIRateLimit() async {
    if (!AuthService.instance.isLoggedIn) return;
    final response = await ApiService.instance.checkAIRateLimit();
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() {
        _aiCanGenerate = response.data!['canGenerate'] ?? true;
        _aiRemainingSeconds = response.data!['remainingSeconds'] ?? 0;
      });
      if (!_aiCanGenerate && _aiRemainingSeconds > 0) {
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _aiRemainingSeconds--;
        if (_aiRemainingSeconds <= 0) {
          _aiCanGenerate = true;
          _aiRemainingSeconds = 0;
          t.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, CrosswordProvider>(
      builder: (context, themeProvider, provider, _) {
        final currentTheme = themeProvider.currentAppTheme;
        final stats = provider.playerStats;
        final litCats = provider.categories;
        final grammarCats = provider.grammarCategories;
        final allCats = provider.allCategories;

        List<CrosswordCategory> _sortGroup(List<CrosswordCategory> group) {
          final sorted = List<CrosswordCategory>.from(group);
          sorted.sort((a, b) {
            final ra = stats.successRateFor(a.id);
            final rb = stats.successRateFor(b.id);
            if (ra == null && rb == null) return a.name.compareTo(b.name);
            if (ra == null) return 1;
            if (rb == null) return -1;
            return rb.compareTo(ra);
          });
          return sorted;
        }

        final sortedLit = _sortGroup(litCats);
        final sortedGrammar = _sortGroup(grammarCats);

        final weakCategories = allCats
            .where((c) {
              final r = stats.successRateFor(c.id);
              return r != null && r < 50;
            })
            .toList()
          ..sort((a, b) {
            final ra = stats.successRateFor(a.id)!;
            final rb = stats.successRateFor(b.id)!;
            return ra.compareTo(rb);
          });
        final top3Weak = weakCategories.take(3).toList();

        final List<dynamic> items = [
          if (_canShowAI) '__ai_banner__',
          if (top3Weak.isNotEmpty) '__weak__',
          if (sortedLit.isNotEmpty) ...['__lit__', ...sortedLit],
          if (sortedGrammar.isNotEmpty) ...['__grammar__', ...sortedGrammar],
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Konu Bazlı Başarı',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            centerTitle: true,
            backgroundColor: currentTheme.primaryColor,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: BoxDecoration(gradient: currentTheme.appBarGradient),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  currentTheme.primaryColor.withOpacity(0.05),
                  Colors.white,
                  const Color(0xFFFFF8E1),
                ],
              ),
            ),
            child: allCats.isEmpty
                ? const Center(child: Text('Henüz kategori yüklenmemiş'))
                : Column(
                    children: [
                      _buildSummaryCard(
                          context, stats, allCats, currentTheme.primaryColor),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item == '__ai_banner__') {
                              return _buildAIBanner(
                                context,
                                top3Weak,
                                currentTheme.primaryColor,
                                provider,
                              );
                            }
                            if (item == '__weak__') {
                              return _buildWeakSection(
                                  context, top3Weak, stats,
                                  currentTheme.primaryColor, provider);
                            }
                            if (item is String) {
                              return _buildSectionHeader(
                                item == '__lit__'
                                    ? 'Edebiyat Kategorileri'
                                    : 'Dil Bilgisi Kategorileri',
                                item == '__lit__'
                                    ? Icons.menu_book
                                    : Icons.spellcheck,
                                currentTheme.primaryColor,
                              );
                            }
                            return _buildCategoryRow(
                              context,
                              item as CrosswordCategory,
                              stats,
                              currentTheme.primaryColor,
                              provider,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    PlayerStats stats,
    List<CrosswordCategory> allCats,
    Color primaryColor,
  ) {
    final played = allCats.where((c) => stats.successRateFor(c.id) != null).length;
    final overallRate = _overallRate(stats, allCats);

    int totalCorrect = 0;
    int totalLetters = 0;
    for (final c in allCats) {
      totalCorrect += stats.categoryWordsCorrect[c.id] ?? 0;
      totalLetters += stats.categoryLettersRevealed[c.id] ?? 0;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, color: Colors.white, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Genel Başarı Ortalaması',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  overallRate == null
                      ? 'Henüz veri yok'
                      : '%${overallRate.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 26),
                ),
                const SizedBox(height: 2),
                Text(
                  '$played / ${allCats.length} kategori oynandı',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 12),
                ),
                if (totalCorrect > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$totalCorrect doğru  •  $totalLetters ipucu harfi',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeakSection(
    BuildContext context,
    List<CrosswordCategory> weak,
    PlayerStats stats,
    Color primaryColor,
    CrosswordProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Çalışman Gereken Konular',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          ...weak.map((cat) {
            final rate = stats.successRateFor(cat.id)!;
            final correct = stats.categoryWordsCorrect[cat.id] ?? 0;
            final letters = stats.categoryLettersRevealed[cat.id] ?? 0;
            return ListTile(
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '%${rate.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700),
                  ),
                ),
              ),
              title: Text(
                _prettifyName(cat.name),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '$correct doğru • $letters ipucu harfi',
                style: TextStyle(fontSize: 11, color: Colors.red.shade600),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canShowAI) ...[
                    Tooltip(
                      message: 'AI ile 5 soruluk bulmaca',
                      child: InkWell(
                        onTap: () => _generateAIPuzzleForCategory(
                            context, cat, provider),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade400,
                                Colors.purple.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_toy,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('AI',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  TextButton(
                    onPressed: () =>
                        _startGameForCategory(context, cat, provider),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Çalış',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5)),
          const SizedBox(width: 8),
          Expanded(
              child: Divider(color: color.withOpacity(0.3), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    CrosswordCategory category,
    PlayerStats stats,
    Color primaryColor,
    CrosswordProvider provider,
  ) {
    final rate = stats.successRateFor(category.id);
    final played = stats.categoryPuzzleCounts[category.id] ?? 0;
    final correct = stats.categoryWordsCorrect[category.id] ?? 0;
    final letters = stats.categoryLettersRevealed[category.id] ?? 0;
    final color = _rateColor(rate);
    final displayName = _prettifyName(category.name);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCategoryDetail(
            context, category, stats, primaryColor, provider),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      rate == null
                          ? Icons.help_outline
                          : (rate == 0
                              ? Icons.trending_flat
                              : Icons.trending_up),
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (rate == null)
                          Text('Henüz oynanmadı',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600))
                        else
                          Text(
                            '$played bulmaca  •  $correct doğru • $letters ipucu harfi',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          rate == null ? '—' : '%${rate.toStringAsFixed(0)}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
              if (rate != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (rate / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryDetail(
    BuildContext context,
    CrosswordCategory category,
    PlayerStats stats,
    Color primaryColor,
    CrosswordProvider provider,
  ) {
    final rate = stats.successRateFor(category.id) ?? 0;
    final played = stats.categoryPuzzleCounts[category.id] ?? 0;
    final correct = stats.categoryWordsCorrect[category.id] ?? 0;
    final letters = stats.categoryLettersRevealed[category.id] ?? 0;
    final color = _rateColor(rate);
    final displayName = _prettifyName(category.name);

    final rawMissed = stats.categoryLastMissedClues[category.id] ?? [];
    final missedPairs = rawMissed
        .map((s) {
          final parts = s.split('|||');
          return parts.length == 2
              ? <String, String>{'q': parts[0], 'a': parts[1]}
              : null;
        })
        .whereType<Map<String, String>>()
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.trending_up, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statBox('Oynanan', '$played bulmaca',
                      Icons.gamepad_outlined, primaryColor),
                  const SizedBox(width: 8),
                  _statBox('Başarı', '%${rate.toStringAsFixed(0)}',
                      Icons.star_outline, color),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statBox('Doğru', '$correct kelime',
                      Icons.check_circle_outline, Colors.green.shade600),
                  const SizedBox(width: 8),
                  _statBox('İpucu Harfi', '$letters harf',
                      Icons.lightbulb_outline, Colors.orange.shade600),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (rate / 100).clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              if (missedPairs.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Son Oyundaki Hatalar (${missedPairs.length})',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...missedPairs.map((pair) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.close,
                              size: 16, color: Colors.red.shade400),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pair['q']!,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF333333))),
                                const SizedBox(height: 2),
                                Text(
                                  'Cevap: ${pair['a']}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ] else if (played > 0) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Text('Son oyunda tüm sorular doğru!',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startGameForCategory(context, category, provider);
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(played == 0 ? 'Oynamaya Başla' : 'Tekrar Çalış'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_canShowAI) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _generateAIPuzzleForCategory(context, category, provider);
                  },
                  icon: const Icon(Icons.smart_toy),
                  label: const Text('AI ile 5 Soruluk Bulmaca Oluştur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade500,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Yapay zeka, "${_prettifyName(category.name)}" konusunda sana özel bir bulmaca hazırlasın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startGameForCategory(
    BuildContext context,
    CrosswordCategory category,
    CrosswordProvider provider,
  ) async {
    await provider.startGameFromCategory(
      category.id,
      wordCount: 10,
      difficulty: 0,
      gridSize: 15,
    );

    if (context.mounted && provider.currentPuzzle != null) {
      final route = SettingsService.instance.animationsEnabled
          ? PageRouteBuilder(
              pageBuilder: (ctx, anim, _) => const CrosswordGameScreen(),
              transitionsBuilder: (ctx, anim, _, child) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                      CurvedAnimation(
                          parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
            )
          : PageRouteBuilder(
              pageBuilder: (ctx, anim, _) => const CrosswordGameScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            );
      Navigator.push(context, route);
    }
  }

  double? _overallRate(PlayerStats stats, List<CrosswordCategory> cats) {
    int totalUser = 0;
    int totalMax = 0;
    for (final c in cats) {
      totalUser += stats.categoryUserScores[c.id] ?? 0;
      totalMax += stats.categoryMaxScores[c.id] ?? 0;
    }
    if (totalMax <= 0) return null;
    return (totalUser / totalMax) * 100;
  }

  Color _rateColor(double? rate) {
    if (rate == null) return Colors.grey;
    if (rate >= 75) return Colors.green.shade600;
    if (rate >= 50) return Colors.lightGreen.shade700;
    if (rate >= 30) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  String _prettifyName(String raw) {
    final cleaned = _trLower(raw.replaceAll('-', ' '));
    return cleaned
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((w) => _trCapitalize(w))
        .join(' ');
  }

  String _trLower(String s) {
    return s
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .toLowerCase();
  }

  String _trCapitalize(String word) {
    if (word.isEmpty) return word;
    final first = word[0];
    final upper = first == 'i'
        ? 'İ'
        : first == 'ı'
            ? 'I'
            : first.toUpperCase();
    return upper + word.substring(1);
  }

  // =========================================================================
  // AI Destekli Bulmaca Oluşturma
  // =========================================================================

  /// Üst banner — AI ile çalışmayı tanıtır, eksik konuları varsa "en zayıf
  /// konu" için tek tıkla bulmaca oluşturur.
  Widget _buildAIBanner(
    BuildContext context,
    List<CrosswordCategory> weak,
    Color primaryColor,
    CrosswordProvider provider,
  ) {
    final hasWeak = weak.isNotEmpty;
    final weakest = hasWeak ? weak.first : null;
    final canTap = _aiCanGenerate && !_isAIGenerating;

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade400,
            Colors.purple.shade500,
            Colors.indigo.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Destekli Çalışma',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Yapay zeka her konuya özel 5 soruluk çengel bulmaca hazırlar.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasWeak)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canTap
                    ? () => _generateAIPuzzleForCategory(
                        context, weakest!, provider)
                    : null,
                icon: Icon(
                  _aiCanGenerate ? Icons.auto_awesome : Icons.timer,
                  size: 18,
                ),
                label: Text(
                  _isAIGenerating
                      ? 'Oluşturuluyor...'
                      : _aiCanGenerate
                          ? 'En Zayıf Konuna AI Bulmaca: ${_prettifyName(weakest!.name)}'
                          : 'Sonraki bulmaca: $_aiRemainingSeconds sn',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple.shade700,
                  disabledBackgroundColor: Colors.white.withOpacity(0.5),
                  disabledForegroundColor: Colors.deepPurple.shade300,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bir konuya tıkla, "AI ile Bulmaca Oluştur" butonunu gör.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (!_aiCanGenerate && _aiRemainingSeconds > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.timer,
                    color: Colors.white70, size: 13),
                const SizedBox(width: 4),
                Text(
                  'AI 1 dakikada bir bulmaca üretir',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Bir kategori için AI'dan 5 soruluk bulmaca oluşturur, yükleme
  /// diyaloğu gösterir, sonra oyun ekranına geçer.
  Future<void> _generateAIPuzzleForCategory(
    BuildContext context,
    CrosswordCategory category,
    CrosswordProvider provider,
  ) async {
    if (_isAIGenerating) return;
    if (!_canShowAI) return; // AI özelliği aktif değil

    if (!AuthService.instance.isLoggedIn) {
      _showSnack(context,
          'AI bulmaca için giriş yapmalısın.', isError: true);
      return;
    }

    if (!_aiCanGenerate) {
      _showSnack(
        context,
        'AI 1 dakikada bir bulmaca üretebilir. $_aiRemainingSeconds sn sonra tekrar dene.',
        isError: true,
      );
      return;
    }

    SoundService.instance.playButtonClick();

    setState(() => _isAIGenerating = true);
    _showLoadingDialog(context, category);

    try {
      final response = await ApiService.instance.generateAIPuzzle(
        topic: _prettifyName(category.name),
        mode: 'topic',
      );

      if (!mounted) return;

      // Loading diyaloğunu kapat
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.isSuccess && response.data != null) {
        final puzzleData = response.data!['puzzle'];
        if (puzzleData is Map<String, dynamic>) {
          final puzzle = _parseAIPuzzle(puzzleData);
          if (puzzle != null && puzzle.words.isNotEmpty) {
            SoundService.instance.playWelcome();
            provider.loadAIPuzzle(puzzle);

            final route = SettingsService.instance.animationsEnabled
                ? PageRouteBuilder(
                    pageBuilder: (ctx, anim, _) =>
                        const CrosswordGameScreen(),
                    transitionsBuilder: (ctx, anim, _, child) =>
                        FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                            CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    ),
                  )
                : PageRouteBuilder(
                    pageBuilder: (ctx, anim, _) =>
                        const CrosswordGameScreen(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  );
            Navigator.push(context, route);
          } else {
            _showSnack(context, 'Bulmaca oluşturulamadı, tekrar dene.',
                isError: true);
          }
        } else {
          _showSnack(context, 'Bulmaca verisi bozuk geldi.', isError: true);
        }
      } else {
        _showSnack(
          context,
          response.errorMessage ?? 'AI bulmaca oluşturulamadı.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        _showSnack(context, 'Bağlantı hatası: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isAIGenerating = false);
        // Yeni rate-limit'i sunucudan çek (1dk geri sayımı tetikler)
        _refreshAIRateLimit();
      }
    }
  }

  void _showLoadingDialog(
      BuildContext context, CrosswordCategory category) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade300,
                      Colors.purple.shade400,
                    ],
                  ),
                ),
                child: const Icon(Icons.smart_toy,
                    size: 40, color: Colors.white),
              ),
              const SizedBox(height: 18),
              const Text(
                'AI Bulmacanı Hazırlıyor',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '"${_prettifyName(category.name)}" konusunda 5 soruluk çengel bulmaca oluşturuluyor.\nBu işlem 30-60 saniye sürebilir.',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 160,
                child: LinearProgressIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  CrosswordPuzzle? _parseAIPuzzle(Map<String, dynamic> data) {
    try {
      final words = (data['words'] as List).map((w) {
        return CrosswordWord(
          id: (w['id'] ?? '').toString(),
          question: (w['question'] ?? '').toString(),
          answer: (w['answer'] ?? '').toString().toUpperCase(),
          row: w['row'] ?? 0,
          col: w['col'] ?? 0,
          direction: (w['direction'] ?? 'across').toString(),
          number: w['number'] ?? 0,
        );
      }).toList();

      return CrosswordPuzzle(
        id: (data['id'] ?? 'ai_puzzle').toString(),
        title: (data['title'] ?? 'AI Bulmaca').toString(),
        difficulty: data['difficulty'] ?? 2,
        description: (data['description'] ?? '').toString(),
        gridRows: data['gridRows'] ?? 15,
        gridCols: data['gridCols'] ?? 15,
        words: words,
      );
    } catch (_) {
      return null;
    }
  }

  void _showSnack(BuildContext context, String message,
      {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}