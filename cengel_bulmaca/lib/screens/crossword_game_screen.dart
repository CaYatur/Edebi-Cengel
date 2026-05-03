import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/crossword_provider.dart';
import '../providers/theme_provider.dart';
import '../models/crossword_word.dart';
import '../widgets/crossword_grid_widget.dart';
import '../widgets/clues_list_widget.dart';
import '../services/sound_service.dart';
import '../services/settings_service.dart';

class CrosswordGameScreen extends StatefulWidget {
  const CrosswordGameScreen({super.key});

  @override
  State<CrosswordGameScreen> createState() => _CrosswordGameScreenState();
}

class _CrosswordGameScreenState extends State<CrosswordGameScreen> with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final _sound = SoundService.instance;
  late AnimationController _clueAnimCtrl;
  late AnimationController _celebrationCtrl;
  late Animation<double> _clueFade;
  OverlayEntry? _correctAnswerOverlay;

  @override
  void initState() {
    super.initState();
    final _animEnabled = SettingsService.instance.animationsEnabled;
    _focusNode.requestFocus();
    _clueAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _clueFade = CurvedAnimation(parent: _clueAnimCtrl, curve: Curves.easeOutCubic);
    _celebrationCtrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    if (_animEnabled) {
      _clueAnimCtrl.forward();
      _celebrationCtrl.repeat();
    } else {
      _clueAnimCtrl.value = 1.0;
      _celebrationCtrl.value = 0.0;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _clueAnimCtrl.dispose();
    _celebrationCtrl.dispose();
    // Overlay'i kapat (eğer hala görünüyorsa)
    _correctAnswerOverlay?.remove();
    _correctAnswerOverlay = null;
    // Oyun state'ini temizle - ana menüye dönüşte overlay göstermemesi için
    try {
      context.read<CrosswordProvider>().clearLastCompletedWord();
    } catch (_) {}
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final provider = context.read<CrosswordProvider>();
    final key = event.logicalKey;

    // Harf tuşları
    if (key.keyLabel.length == 1) {
      String char = key.keyLabel.toUpperCase();
      if (RegExp(r'[A-ZĞÜŞİÖÇ]').hasMatch(char)) {
        provider.enterLetter(char);
        _sound.playKeystroke();
        return;
      }
    }

    // Türkçe karakterler için özel kontrol
    if (event.character != null && event.character!.length == 1) {
      String char = event.character!.toUpperCase();
      if (RegExp(r'[A-ZĞÜŞİÖÇ]').hasMatch(char)) {
        provider.enterLetter(char);
        _sound.playKeystroke();
        return;
      }
    }

    // Backspace
    if (key == LogicalKeyboardKey.backspace) {
      provider.deleteLetter();
      _sound.playKeystroke();
      return;
    }

    // Ok tuşları
    if (provider.selectedCell != null && provider.currentPuzzle != null) {
      int row = provider.selectedCell!.row;
      int col = provider.selectedCell!.col;

      if (key == LogicalKeyboardKey.arrowUp && row > 0) {
        provider.selectCell(row - 1, col);
      } else if (key == LogicalKeyboardKey.arrowDown && 
                 row < provider.currentPuzzle!.gridRows - 1) {
        provider.selectCell(row + 1, col);
      } else if (key == LogicalKeyboardKey.arrowLeft && col > 0) {
        provider.selectCell(row, col - 1);
      } else if (key == LogicalKeyboardKey.arrowRight && 
                 col < provider.currentPuzzle!.gridCols - 1) {
        provider.selectCell(row, col + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final currentTheme = themeProvider.currentAppTheme;
        final settings = SettingsService.instance;
        return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: currentTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: currentTheme.appBarGradient,
            ),
          ),
          title: Consumer<CrosswordProvider>(
            builder: (context, provider, child) {
              return Text(
                provider.currentPuzzle?.title ?? 'Çengel Bulmaca',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * settings.fontSize),
              );
            },
          ),
          actions: [
            // Yeni Bulmaca butonu (aynı kategoriden farklı sorularla)
            Consumer<CrosswordProvider>(
              builder: (context, provider, child) {
                if (provider.currentCategoryId == null) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yeni Bulmaca Oluştur',
                  onPressed: () => _showRegeneratePuzzleDialog(context),
                );
              },
            ),
            // İpucu butonu
            Consumer<CrosswordProvider>(
              builder: (context, provider, child) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.lightbulb_outline),
                  tooltip: 'İpucu',
                  onSelected: (value) {
                    _sound.playHint();
                    if (value == 'letter') {
                      provider.revealLetter();
                    } else if (value == 'word') {
                      provider.revealWord();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'letter',
                      child: Row(
                        children: [
                          Icon(Icons.text_fields, size: 20, color: Colors.black87),
                          SizedBox(width: 8),
                          Text('Bir Harf Göster'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'word',
                      child: Row(
                        children: [
                          Icon(Icons.short_text, size: 20, color: Colors.black87),
                          SizedBox(width: 8),
                          Text('Kelimeyi Göster'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            // Skor
            Consumer<CrosswordProvider>(
              builder: (context, provider, child) {
                final stats = provider.getGameStats();
                final int puzzleScore = stats['puzzleScore'] ?? 0;
                final int maxScore = stats['maxPossibleScore'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Kelime progress
                        Text(
                          '${stats['completedWords'] ?? 0}/${stats['totalWords'] ?? 0}',
                          style: TextStyle(
                            fontSize: 14 * settings.fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Puan
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.white, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                '$puzzleScore/$maxScore',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                currentTheme.primaryColor.withOpacity(0.03),
                Colors.white,
              ],
            ),
          ),
          child: Consumer<CrosswordProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (provider.currentPuzzle == null) {
              return const Center(
                child: Text(
                  'Bulmaca yüklenemedi',
                  style: TextStyle(fontSize: 18),
                ),
              );
            }

            // Doğru cevap animasyonu
            if (provider.lastCompletedWordId != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showCorrectAnswerAnimation();
                provider.clearLastCompletedWord();
                
                // Se for o último, adia o dialog por 1 segundo
                if (provider.isGameCompleted) {
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) {
                      _showGameCompletedDialog();
                    }
                  });
                }
              });
            } else if (provider.isGameCompleted) {
              // Caso o jogo termine sem passar por aqui (improvável)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showGameCompletedDialog();
              });
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                // Ekran yönüne göre layout
                bool isWide = constraints.maxWidth > 700;

                if (isWide) {
                  return _buildWideLayout(provider);
                } else {
                  return _buildNarrowLayout(provider);
                }
              },
            );
          },
        ),
        ),
        // Mobil için soft keyboard
        bottomNavigationBar: Consumer<CrosswordProvider>(
          builder: (context, provider, child) {
            if (provider.currentPuzzle == null) return const SizedBox.shrink();
            return _buildKeyboard(provider);
          },
        ),
      ),
    );
      },
    );
  }

  Widget _buildWideLayout(CrosswordProvider provider) {
    return Row(
      children: [
        // Sol: Grid
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Seçili ipucu
                if (provider.selectedWord != null)
                  FadeTransition(
                    opacity: _clueFade,
                    child: _buildSelectedClueCard(provider.selectedWord!),
                  ),
                const SizedBox(height: 16),
                // Grid
                Expanded(
                  child: CrosswordGridWidget(
                    puzzle: provider.currentPuzzle!,
                    userAnswers: provider.userAnswers,
                    selectedWord: provider.selectedWord,
                    selectedCell: provider.selectedCell,
                    correctCells: provider.correctCells,
                    hintedCells: provider.hintedCells,
                    onCellTap: (row, col) => provider.selectCell(row, col),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Sağ: İpuçları listesi
        Expanded(
          flex: 2,
          child: CluesListWidget(
            acrossWords: provider.currentPuzzle!.acrossWords,
            downWords: provider.currentPuzzle!.downWords,
            selectedWord: provider.selectedWord,
            completedWordIds: provider.completedWordIds,
            onClueTap: (word) => provider.selectWord(word),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(CrosswordProvider provider) {
    return Column(
      children: [
        // Üst: Seçili ipucu
        if (provider.selectedWord != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildSelectedClueCard(provider.selectedWord!),
          ),
        // Orta: Grid - Sabit boyut verelim taşmasın
        Flexible(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: CrosswordGridWidget(
              puzzle: provider.currentPuzzle!,
              userAnswers: provider.userAnswers,
              selectedWord: provider.selectedWord,
              selectedCell: provider.selectedCell,
              correctCells: provider.correctCells,
              hintedCells: provider.hintedCells,
              onCellTap: (row, col) => provider.selectCell(row, col),
            ),
          ),
        ),
        // Alt: İpuçları listesi
        Flexible(
          flex: 2,
          child: CluesListWidget(
            acrossWords: provider.currentPuzzle!.acrossWords,
            downWords: provider.currentPuzzle!.downWords,
            selectedWord: provider.selectedWord,
            completedWordIds: provider.completedWordIds,
            onClueTap: (word) => provider.selectWord(word),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedClueCard(CrosswordWord word) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final lightBg = Color.alphaBlend(primaryColor.withOpacity(0.10), Colors.white);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: Card(
        key: ValueKey(word.number),
        color: lightBg,
        elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  word.number.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        word.isAcross ? Icons.arrow_forward : Icons.arrow_downward,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        word.isAcross ? 'Yatay' : 'Dikey',
                        style: TextStyle(
                          fontSize: 12,
                        color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${word.length} harf)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    word.question,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildKeyboard(CrosswordProvider provider) {
    final List<List<String>> rows = [
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', '⌫'],
    ];

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Ekran genişliğine göre tuş boyutu hesapla
          double maxKeyWidth = (constraints.maxWidth - 48) / 12; // 12 tuş + boşluklar
          double keyWidth = maxKeyWidth.clamp(22.0, 32.0);
          double keyHeight = keyWidth * 1.1;
          
          return Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: rows.map((row) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: row.map((key) {
                      bool isBackspace = key == '⌫';
                      bool isNumber = RegExp(r'[0-9]').hasMatch(key);
                      
                      Color keyColor = Colors.white;
                      if (isBackspace) {
                        keyColor = Colors.red.shade100;
                      } else if (isNumber) {
                        keyColor = Colors.blue.shade50;
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Material(
                          color: keyColor,
                          borderRadius: BorderRadius.circular(4),
                          elevation: 1,
                          child: InkWell(
                            onTap: () {
                              _sound.playKeystroke();
                              if (isBackspace) {
                                provider.deleteLetter();
                              } else {
                                provider.enterLetter(key);
                              }
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: isBackspace ? keyWidth * 1.4 : keyWidth,
                              height: keyHeight,
                              alignment: Alignment.center,
                              child: isBackspace
                                  ? Icon(Icons.backspace, size: keyWidth * 0.5)
                                  : Text(
                                      key,
                                      style: TextStyle(
                                        fontSize: keyWidth * 0.5,
                                        fontWeight: isNumber ? FontWeight.w600 : FontWeight.w800,
                                        fontFamily: 'Roboto',
                                        height: 1.0,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  void _showCorrectAnswerAnimation() {
    // Eğer overlay hala görünüyorsa kaldır
    _correctAnswerOverlay?.remove();
    _correctAnswerOverlay = null;
    
    if (!mounted) return;
    
    _sound.playWordComplete();
    final primaryColor = Theme.of(context).colorScheme.primary;
    final overlay = Overlay.of(context);
    
    _correctAnswerOverlay = OverlayEntry(
      builder: (context) => _CorrectAnswerOverlay(
        primaryColor: primaryColor,
        onComplete: () {
          if (mounted) {
            _correctAnswerOverlay?.remove();
            _correctAnswerOverlay = null;
          }
        },
      ),
    );
    overlay.insert(_correctAnswerOverlay!);
  }

  void _showGameCompletedDialog() {
    final provider = context.read<CrosswordProvider>();
    if (provider.gameResultRecorded) return;

    final stats = provider.getGameStats();
    final int puzzleScore = stats['puzzleScore'] ?? 0;
    final int maxScore = stats['maxPossibleScore'] ?? 0;
    final int hintedCells = stats['hintedCells'] ?? 0;
    final int durationSeconds = stats['durationSeconds'] ?? 0;
    final primaryColor = Theme.of(context).colorScheme.primary;

    provider.recordGameResult().then((newBadges) {
      if (!mounted) return;
      _sound.playGameComplete();
      if (newBadges.isNotEmpty) {
        _sound.playBadgeEarned();
      }

      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Game Complete',
        barrierColor: Colors.black54,
        transitionDuration: SettingsService.instance.animationsEnabled 
            ? const Duration(milliseconds: 500) 
            : Duration.zero,
        transitionBuilder: (context, anim1, anim2, child) {
          if (!SettingsService.instance.animationsEnabled) return child;
          return ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
            child: FadeTransition(opacity: anim1, child: child),
          );
        },
        pageBuilder: (dialogContext, anim1, anim2) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // Main dialog card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    constraints: BoxConstraints(
                      maxWidth: 400,
                      maxHeight: MediaQuery.of(dialogContext).size.height - 80,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sağ üst çarpı butonu
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, right: 8),
                            child: InkWell(
                              onTap: () => Navigator.of(dialogContext).pop(),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, size: 20, color: Colors.grey.shade700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Sürekli yıldız düşme animasyonu
                        if (SettingsService.instance.particlesEnabled)
                        AnimatedBuilder(
                          animation: _celebrationCtrl,
                          builder: (context, child) {
                            return SizedBox(
                              height: 40,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(7, (i) {
                                  final delay = i * 0.14;
                                  // Her yıldız kendi fazıyla sürekli dönüyor
                                  final t = ((_celebrationCtrl.value + delay) % 1.0);
                                  // Yukarı çık sonra aşağı düş (sürekli)
                                  final y = t < 0.3
                                      ? -25 * sin(t / 0.3 * pi) // yukarı çık
                                      : 20 * ((t - 0.3) / 0.7); // aşağı düş
                                  final opacity = t < 0.3 ? 1.0 : (1.0 - (t - 0.3) / 0.7).clamp(0.0, 1.0);
                                  final starSize = t < 0.3 ? 14.0 + 8 * sin(t / 0.3 * pi) : 22.0 * (1.0 - (t - 0.3) / 0.7).clamp(0.5, 1.0);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: Opacity(
                                      opacity: opacity,
                                      child: Transform.translate(
                                        offset: Offset(0, y),
                                        child: Icon(
                                          Icons.star,
                                          size: starSize,
                                          color: [
                                            Colors.amber,
                                            Colors.red,
                                            Colors.blue,
                                            Colors.green,
                                            Colors.purple,
                                            Colors.orange,
                                            Colors.pink,
                                          ][i],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),
                        // Title
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.bounceOut,
                          builder: (context, value, child) {
                            return Transform.scale(scale: value, child: child);
                          },
                          child: Text(
                            'Tebrikler!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Bulmacayı tamamladınız!',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        // Score with animation
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: puzzleScore),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.amber.shade100, Colors.amber.shade50],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 32),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$value / $maxScore',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (hintedCells > 0)
                                    Text(
                                      'İpucu ile açılan: $hintedCells hücre (-$hintedCells puan)',
                                      style: TextStyle(fontSize: 13, color: Colors.red.shade600),
                                    ),
                                  if (hintedCells == 0)
                                    Text(
                                      'Hiç ipucu kullanılmadı! Tam puan!',
                                      style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Stats
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              _buildStatLine(Icons.extension, 'Kelime', '${stats['completedWords']}/${stats['totalWords']}'),
                              _buildStatLine(Icons.timer, 'Süre', _formatGameDuration(durationSeconds)),
                              _buildStatLine(Icons.star_outline, 'Toplam Puan', '${provider.playerStats.totalScore}'),
                            ],
                          ),
                        ),
                        // New badges
                        if (newBadges.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Yeni Rozetler!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                          const SizedBox(height: 8),
                          ...newBadges.map((badge) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
                            child: Row(
                              children: [
                                Icon(_getBadgeIcon(badge.icon), size: 28, color: Colors.amber.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(badge.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(badge.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                        const SizedBox(height: 20),
                        // Action buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    provider.resetGame();
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Tekrar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    side: BorderSide(color: primaryColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (provider.currentCategoryId != null) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      Navigator.of(dialogContext).pop();
                                      await provider.regeneratePuzzle();
                                    },
                                    icon: const Icon(Icons.shuffle, size: 18),
                                    label: const Text('Yeni'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: BorderSide(color: primaryColor),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    provider.resetGame();
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                  },
                                  icon: const Icon(Icons.home, size: 18),
                                  label: const Text('Menü'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                    ),
                  ),
                  // Trophy circle on top
                  Positioned(
                    top: 0,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.bounceOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.amber.shade400, Colors.amber.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.emoji_events, color: Colors.white, size: 44),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildStatLine(IconData icon, String label, String value) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatGameDuration(int seconds) {
    if (seconds < 60) return '${seconds} saniye';
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return '${min}dk ${sec}s';
  }

  /// Bulmaca yenilemeden önce onay dialog'unu göster
  void _showRegeneratePuzzleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Yeni Bulmaca Oluştur?'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mevcut bulmacayı terk edip yeni bir bulmaca oluşturmak üzeresiniz.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'İlerlemeniz kaydedilmeyecektir. Devam edecek misiniz?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final provider = context.read<CrosswordProvider>();
                await provider.regeneratePuzzle();
              },
              child: const Text(
                'Oluştur',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        );
      },
    );
  }

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
}

/// Doğru cevap animasyon overlay'i
class _CorrectAnswerOverlay extends StatefulWidget {
  final Color primaryColor;
  final VoidCallback onComplete;

  const _CorrectAnswerOverlay({required this.primaryColor, required this.onComplete});

  @override
  State<_CorrectAnswerOverlay> createState() => _CorrectAnswerOverlayState();
}

class _CorrectAnswerOverlayState extends State<_CorrectAnswerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnim = Tween(begin: 0.3, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _fadeAnim = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );
    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: _fadeAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        const Text(
                          'Doğru!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
