import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';
import '../models/crossword_word.dart';
import '../widgets/crossword_grid_widget.dart';
import '../widgets/clues_list_widget.dart';
import '../services/sound_service.dart';
import '../services/settings_service.dart';
import '../services/local_storage_service.dart';

/// Çoklu oyuncu bulmaca oyun ekranı - tek oyuncu tasarımıyla aynı
class MultiplayerGameScreen extends StatefulWidget {
  const MultiplayerGameScreen({super.key});

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen>
    with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final _sound = SoundService.instance;
  late AnimationController _clueAnimCtrl;
  late Animation<double> _clueFade;
  bool _completionDialogShown = false;
  bool _resultScreenShown = false;
  bool _cancelDialogShown = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _clueAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _clueFade =
        CurvedAnimation(parent: _clueAnimCtrl, curve: Curves.easeOutCubic);

    if (SettingsService.instance.animationsEnabled) {
      _clueAnimCtrl.forward();
    } else {
      _clueAnimCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _clueAnimCtrl.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final mp = context.read<MultiplayerProvider>();
    final key = event.logicalKey;

    if (key.keyLabel.length == 1) {
      String char = key.keyLabel.toUpperCase();
      if (RegExp(r'[A-ZĞÜŞİÖÇ]').hasMatch(char)) {
        mp.enterLetter(char);
        _sound.playKeystroke();
        return;
      }
    }

    if (event.character != null && event.character!.length == 1) {
      String char = event.character!.toUpperCase();
      if (RegExp(r'[A-ZĞÜŞİÖÇ]').hasMatch(char)) {
        mp.enterLetter(char);
        _sound.playKeystroke();
        return;
      }
    }

    if (key == LogicalKeyboardKey.backspace) {
      mp.deleteLetter();
      _sound.playKeystroke();
      return;
    }

    if (mp.selectedCell != null && mp.puzzle != null) {
      int row = mp.selectedCell!.row;
      int col = mp.selectedCell!.col;

      if (key == LogicalKeyboardKey.arrowUp && row > 0) {
        mp.selectCell(row - 1, col);
      } else if (key == LogicalKeyboardKey.arrowDown &&
          row < mp.puzzle!.gridRows - 1) {
        mp.selectCell(row + 1, col);
      } else if (key == LogicalKeyboardKey.arrowLeft && col > 0) {
        mp.selectCell(row, col - 1);
      } else if (key == LogicalKeyboardKey.arrowRight &&
          col < mp.puzzle!.gridCols - 1) {
        mp.selectCell(row, col + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MultiplayerProvider, ThemeProvider>(
      builder: (context, mp, themeProvider, _) {
        final currentTheme = themeProvider.currentAppTheme;

        // Oyun bitti mi kontrol et
        if (mp.status == RoomStatus.finished && !_resultScreenShown) {
          // Oyun iptal edildiyse (ev sahibi ayrıldı)
          if (mp.gameResults.isEmpty && mp.errorMessage != null && !_cancelDialogShown) {
            _cancelDialogShown = true;
            _resultScreenShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showGameCancelledDialog(mp.errorMessage!);
            });
          } else if (!_cancelDialogShown) {
            _resultScreenShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showResultsScreen(mp);
            });
          }
        }

        // Kendi oyunumuz bittiyse
        if (mp.isGameCompleted && !_completionDialogShown) {
          _completionDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _sound.playSuccess();
            _showCompletionSnackbar();
          });
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _showLeaveDialog();
          },
          child: KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: currentTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                flexibleSpace: Container(
                  decoration:
                      BoxDecoration(gradient: currentTheme.appBarGradient),
                ),
                title: const Text('Çoklu Oyuncu',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _showLeaveDialog,
                ),
                actions: [
                  _buildHintButton(mp),
                  _buildScoreIndicator(mp),
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
                child: mp.puzzle == null
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          // Çoklu oyuncu bilgi çubuğu
                          _buildMultiplayerInfoBar(mp, currentTheme),
                          // Ana içerik - tek oyuncuyla aynı layout
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                bool isWide = constraints.maxWidth > 700;
                                if (isWide) {
                                  return _buildWideLayout(mp);
                                } else {
                                  return _buildNarrowLayout(mp);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              // Klavye - tek oyuncuyla aynı stil, bottomNavigationBar
              bottomNavigationBar: mp.puzzle == null
                  ? null
                  : mp.isFinished
                      ? _buildFinishedBar()
                      : _buildKeyboard(mp),
            ),
          ),
        );
      },
    );
  }

  /// Çoklu oyuncuya özel üst bilgi çubuğu
  Widget _buildMultiplayerInfoBar(
      MultiplayerProvider mp, AppTheme currentTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: currentTheme.primaryColor.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(
              color: currentTheme.primaryColor.withOpacity(0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst satır: Timer + İpucu + İlerleme
          Row(
            children: [
              // Timer
              if (mp.hasTimeLimit) ...[
                Icon(Icons.timer,
                    size: 16,
                    color: mp.remainingSeconds < 60
                        ? Colors.red
                        : Colors.grey[700]),
                const SizedBox(width: 4),
                Text(
                  _formatTime(mp.remainingSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: mp.remainingSeconds < 60
                        ? Colors.red
                        : Colors.black87,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              // İpucu bilgisi
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber[700]),
              const SizedBox(width: 4),
              Text(
                '${mp.remainingHints}/${mp.settings.hintLimit}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: mp.canUseHint ? Colors.amber[800] : Colors.red,
                ),
              ),
              const Spacer(),
              // Kelime ilerlemesi
              Text(
                '${mp.completedWordIds.length}/${mp.puzzle?.words.length ?? 0}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: currentTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 4),
              Text('kelime',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          // Rakip ilerleme çubukları
          if (mp.players
              .where((p) => p.id != mp.playerId)
              .isNotEmpty) ...[
            const SizedBox(height: 6),
            ...mp.players.where((p) => p.id != mp.playerId).map(
                  (player) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            player.displayName,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: player.progress / 100,
                              backgroundColor: Colors.grey[300],
                              color: player.isFinished
                                  ? Colors.green
                                  : Colors.orange,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (player.isFinished)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${player.finishOrder}.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Text(
                            '%${player.progress}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildHintButton(MultiplayerProvider mp) {
    return PopupMenuButton<String>(
      icon: Stack(
        children: [
          const Icon(Icons.lightbulb_outline),
          if (mp.remainingHints > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${mp.remainingHints}',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      tooltip: 'İpucu (${mp.remainingHints} kaldı)',
      enabled: mp.canUseHint && !mp.isFinished,
      onSelected: (value) {
        if (!mp.canUseHint) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İpucu hakkınız bitti!')),
          );
          return;
        }
        _sound.playHint();
        if (value == 'letter') {
          mp.revealLetter();
        } else if (value == 'word') {
          mp.revealWord();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'letter',
          enabled: mp.canUseHint,
          child: Row(
            children: [
              const Icon(Icons.text_fields, size: 20, color: Colors.black87),
              const SizedBox(width: 8),
              Text('Bir Harf Göster (${mp.remainingHints} kaldı)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'word',
          enabled: mp.canUseHint,
          child: Row(
            children: [
              const Icon(Icons.short_text, size: 20, color: Colors.black87),
              const SizedBox(width: 8),
              Text('Kelimeyi Göster (${mp.remainingHints} kaldı)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreIndicator(MultiplayerProvider mp) {
    final stats = mp.getGameStats();
    final int puzzleScore = stats['displayScore'] ?? (stats['puzzleScore'] ?? 0);
    final int maxScore = stats['maxPossibleScore'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${stats['completedWords'] ?? 0}/${stats['totalWords'] ?? 0}',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
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
  }

  // ==================== LAYOUT (tek oyuncuyla aynı) ====================

  Widget _buildWideLayout(MultiplayerProvider mp) {
    return Row(
      children: [
        // Sol: Grid + İpucu
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (mp.selectedWord != null)
                  FadeTransition(
                    opacity: _clueFade,
                    child: _buildSelectedClueCard(mp.selectedWord!),
                  ),
                const SizedBox(height: 16),
                Expanded(
                  child: CrosswordGridWidget(
                    puzzle: mp.puzzle!,
                    userAnswers: mp.userAnswers,
                    selectedWord: mp.selectedWord,
                    selectedCell: mp.selectedCell,
                    correctCells: mp.correctCells,
                    hintedCells: mp.hintedCells,
                    onCellTap: (row, col) => mp.selectCell(row, col),
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
            acrossWords: mp.puzzle!.acrossWords,
            downWords: mp.puzzle!.downWords,
            selectedWord: mp.selectedWord,
            completedWordIds: mp.completedWordIds,
            onClueTap: (word) => mp.selectWord(word),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(MultiplayerProvider mp) {
    return Column(
      children: [
        // Üst: Seçili ipucu
        if (mp.selectedWord != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildSelectedClueCard(mp.selectedWord!),
          ),
        // Orta: Grid
        Flexible(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: CrosswordGridWidget(
              puzzle: mp.puzzle!,
              userAnswers: mp.userAnswers,
              selectedWord: mp.selectedWord,
              selectedCell: mp.selectedCell,
              correctCells: mp.correctCells,
              hintedCells: mp.hintedCells,
              onCellTap: (row, col) => mp.selectCell(row, col),
            ),
          ),
        ),
        // Alt: İpuçları listesi
        Flexible(
          flex: 2,
          child: CluesListWidget(
            acrossWords: mp.puzzle!.acrossWords,
            downWords: mp.puzzle!.downWords,
            selectedWord: mp.selectedWord,
            completedWordIds: mp.completedWordIds,
            onClueTap: (word) => mp.selectWord(word),
          ),
        ),
      ],
    );
  }

  /// Seçili ipucu kartı - tek oyuncuyla aynı tasarım
  Widget _buildSelectedClueCard(CrosswordWord word) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final lightBg = Color.alphaBlend(primaryColor.withOpacity(0.10), Colors.white);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, -0.3), end: Offset.zero)
              .animate(animation),
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
                          word.isAcross
                              ? Icons.arrow_forward
                              : Icons.arrow_downward,
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

  // ==================== KLAVYE (tek oyuncuyla aynı stil) ====================

  Widget _buildFinishedBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.green[50],
        child: Center(
          child: Text(
            '🎉 Bulmacayı tamamladın! Diğer oyuncular bekleniyor...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboard(MultiplayerProvider mp) {
    final List<List<String>> rows = [
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', '⌫'],
    ];

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          double maxKeyWidth = (constraints.maxWidth - 48) / 12;
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
                                mp.deleteLetter();
                              } else {
                                mp.enterLetter(key);
                              }
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width:
                                  isBackspace ? keyWidth * 1.4 : keyWidth,
                              height: keyHeight,
                              alignment: Alignment.center,
                              child: isBackspace
                                  ? Icon(Icons.backspace,
                                      size: keyWidth * 0.5)
                                  : Text(
                                      key,
                                      style: TextStyle(
                                        fontSize: keyWidth * 0.5,
                                        fontWeight: isNumber
                                            ? FontWeight.w600
                                            : FontWeight.w800,
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

  // ==================== DİYALOGLAR ====================

  void _showCompletionSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Bulmacayı tamamladın! Diğer oyuncular bekleniyor...'),
          ],
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showResultsScreen(MultiplayerProvider mp) {
    // Oyuncu istatistikleri kaydet
    if (mp.gameResults.isNotEmpty && mp.playerId != null) {
      // Oyuncunun sonuçlarını bul
      final myResult = mp.gameResults.firstWhere(
        (r) => r['id'] == mp.playerId,
        orElse: () => {},
      );
      
      if (myResult.isNotEmpty) {
        final playerScore = myResult['score'] ?? 0;
        // Rank 1 ise kazanan
        final isWinner = (myResult['rank'] ?? 999) == 1;
        final categoryId = mp.settings.categoryId;
        
        // Multiplayer game sonuçlarını kaydet
        LocalStorageService.instance.recordMultiplayerGameResult(
          playerScore: (playerScore as num).toInt(),
          isWinner: isWinner,
          categoryId: categoryId,
        );
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GameResultsDialog(
        results: mp.gameResults,
        myId: mp.playerId ?? '',
        settings: mp.settings,
        onClose: () {
          Navigator.pop(ctx);
          mp.leaveRoom();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showGameCancelledDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Oyun İptal Edildi'),
          ],
        ),
        content: Text(reason),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<MultiplayerProvider>().leaveRoom();
                Navigator.pop(context);
              },
              child: const Text('Ana Menüye Dön'),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Oyundan Ayrıl'),
        content: const Text(
          'Oyundan ayrılırsan puanın kaydedilmeyecek. Ayrılmak istiyor musun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MultiplayerProvider>().leaveRoom();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Ayrıl', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

/// Oyun sonuçları dialog'u
class _GameResultsDialog extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final String myId;
  final RoomSettings settings;
  final VoidCallback onClose;

  const _GameResultsDialog({
    required this.results,
    required this.myId,
    required this.settings,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🏆 Oyun Bitti!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (results.isNotEmpty)
              Text(
                'Kazanan: ${results.first['displayName'] ?? 'Bilinmiyor'}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.amber[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  final isMe = result['id'] == myId;
                  final rank = result['rank'] ?? (index + 1);
                  final isFinished = result['isFinished'] ?? false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.blue[50]
                          : (rank == 1 ? Colors.amber[50] : Colors.grey[50]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMe
                            ? Colors.blue[300]!
                            : (rank == 1
                                ? Colors.amber[300]!
                                : Colors.grey[300]!),
                        width: isMe ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? Colors.amber
                                : rank == 2
                                    ? Colors.grey[400]
                                    : rank == 3
                                        ? Colors.brown[300]
                                        : Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              rank <= 3
                                  ? ['🥇', '🥈', '🥉'][rank - 1]
                                  : '$rank',
                              style: TextStyle(
                                fontSize: rank <= 3 ? 18 : 14,
                                fontWeight: FontWeight.bold,
                                color: rank <= 3 ? null : Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    result['displayName'] ?? 'Anonim',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isMe
                                          ? Colors.blue[800]
                                          : Colors.black87,
                                    ),
                                  ),
                                  if (isMe)
                                    const Text(' (Sen)',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey)),
                                  if (result['isHost'] == true)
                                    const Text(' 👑',
                                        style: TextStyle(fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isFinished
                                    ? '${result['completedWords']}/${result['totalWords']} kelime • ${_formatDuration(result['durationSeconds'] ?? 0)}'
                                    : '${result['completedWords']}/${result['totalWords']} kelime • Bitiremedi',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${result['score'] ?? 0}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                            Text(
                              'puan',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ana Menüye Dön',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    if (min > 0) return '${min}dk ${sec}sn';
    return '${sec}sn';
  }
}
