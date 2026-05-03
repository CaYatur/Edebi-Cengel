import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/crossword_word.dart';
import '../../providers/classroom_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/sound_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/crossword_grid_widget.dart';
import '../../widgets/clues_list_widget.dart';
import 'classroom_results_screen.dart';

/// Sınav ekranı.
/// Öğretmen → canlı izleme paneli (tüm öğrenciler).
/// Öğrenci → çengel bulmaca + klavye + ipucu butonları.
class ClassroomGameScreen extends StatefulWidget {
  const ClassroomGameScreen({super.key});

  @override
  State<ClassroomGameScreen> createState() => _ClassroomGameScreenState();
}

class _ClassroomGameScreenState extends State<ClassroomGameScreen>
    with TickerProviderStateMixin {
  bool _routedToResults = false;
  final FocusNode _focusNode = FocusNode();
  final _sound = SoundService.instance;
  late AnimationController _clueAnimCtrl;
  late Animation<double> _clueFade;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _clueAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
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

  void _handleKeyEvent(KeyEvent event, ClassroomProvider p) {
    if (event is! KeyDownEvent) return;
    if (p.isTeacher || p.finishedSelf) return;
    final key = event.logicalKey;

    if (key.keyLabel.length == 1) {
      final char = key.keyLabel.toUpperCase();
      if (RegExp(r'[A-ZĞÜŞİÖÇ]').hasMatch(char)) {
        p.enterLetter(char);
        _sound.playKeystroke();
        return;
      }
    }
    if (event.character != null && event.character!.length == 1) {
      final char = event.character!.toUpperCase();
      if (RegExp(r'[A-ZĞÜŞİÖÇ]').hasMatch(char)) {
        p.enterLetter(char);
        _sound.playKeystroke();
        return;
      }
    }
    if (key == LogicalKeyboardKey.backspace) {
      p.deleteLetter();
      _sound.playKeystroke();
      return;
    }
    if (p.selectedCell != null && p.puzzle != null) {
      final row = p.selectedCell!.row;
      final col = p.selectedCell!.col;
      if (key == LogicalKeyboardKey.arrowUp && row > 0) {
        p.selectCell(row - 1, col);
      } else if (key == LogicalKeyboardKey.arrowDown &&
          row < p.puzzle!.gridRows - 1) {
        p.selectCell(row + 1, col);
      } else if (key == LogicalKeyboardKey.arrowLeft && col > 0) {
        p.selectCell(row, col - 1);
      } else if (key == LogicalKeyboardKey.arrowRight &&
          col < p.puzzle!.gridCols - 1) {
        p.selectCell(row, col + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentAppTheme;

    return Consumer<ClassroomProvider>(
      builder: (context, p, _) {
        if (p.status == ClassroomStatus.finished && !_routedToResults) {
          _routedToResults = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: p,
                  child: const ClassroomResultsScreen(),
                ),
              ),
            );
          });
        }

        final isPlaying = p.status == ClassroomStatus.playing;

        return PopScope(
          canPop: !isPlaying,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && isPlaying) {
              if (p.isTeacher) {
                _showTeacherLeaveDialog(p);
              } else {
                _showLeaveWarningDialog(p);
              }
            }
          },
          child: KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: (e) => _handleKeyEvent(e, p),
            child: Scaffold(
              appBar: AppBar(
                title: Text(p.meta.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                leading: isPlaying
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: p.isTeacher ? 'Sınavı Bitir ve Çık' : 'Sınavdan Çık',
                        onPressed: () => p.isTeacher
                            ? _showTeacherLeaveDialog(p)
                            : _showLeaveWarningDialog(p),
                      )
                    : null,
                flexibleSpace: Container(
                  decoration: BoxDecoration(gradient: theme.appBarGradient),
                ),
                actions: [
                  // Öğrenci için ipucu butonu + skor — multiplayer ile birebir aynı
                  if (!p.isTeacher && isPlaying) ...[
                    _buildHintButton(p),
                    _buildScoreIndicator(p),
                  ],
                  if (p.hasTimeLimit)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _timerWidget(p.remainingSeconds),
                      ),
                    ),
                  if (p.isTeacher)
                    IconButton(
                      tooltip: 'Sınavı Bitir',
                      icon: const Icon(Icons.stop_circle),
                      onPressed: () => _confirmEnd(p),
                    ),
                ],
              ),
              body: p.isTeacher
                  ? _buildTeacherMonitor(p, theme)
                  : _buildStudentGame(p, theme),
              // Ana oyunla aynı yapı: klavye bottomNavigationBar'da
              bottomNavigationBar: (!p.isTeacher && isPlaying)
                  ? (p.finishedSelf
                      ? _buildFinishedBar()
                      : _buildKeyboard(p))
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _timerWidget(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    final color = seconds < 60 ? Colors.red : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: color, size: 16),
          const SizedBox(width: 4),
          Text('$m:$s',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  // ── Multiplayer ile birebir aynı hint butonu ─────────────────────────
  Widget _buildHintButton(ClassroomProvider p) {
    return PopupMenuButton<String>(
      icon: Stack(
        children: [
          const Icon(Icons.lightbulb_outline),
          if (p.remainingHints > 0)
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
                  '${p.remainingHints}',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      tooltip: 'İpucu (${p.remainingHints} kaldı)',
      enabled: p.canUseHint && !p.finishedSelf,
      onSelected: (value) {
        if (!p.canUseHint) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İpucu hakkınız bitti!')),
          );
          return;
        }
        _sound.playHint();
        if (value == 'letter') {
          p.revealLetter();
        } else if (value == 'word') {
          p.revealWord();
        }
      },
      itemBuilder: (_) => [
        if (p.settings.allowLetterHint)
          PopupMenuItem(
            value: 'letter',
            enabled: p.canUseHint,
            child: Row(
              children: [
                const Icon(Icons.text_fields, size: 20, color: Colors.black87),
                const SizedBox(width: 8),
                Text('Bir Harf Göster (${p.remainingHints} kaldı)'),
              ],
            ),
          ),
        if (p.settings.allowWordHint)
          PopupMenuItem(
            value: 'word',
            enabled: p.canUseHint,
            child: Row(
              children: [
                const Icon(Icons.short_text, size: 20, color: Colors.black87),
                const SizedBox(width: 8),
                Text('Kelimeyi Göster (${p.remainingHints} kaldı)'),
              ],
            ),
          ),
      ],
    );
  }

  // ── Multiplayer ile birebir aynı skor göstergesi ─────────────────────
  Widget _buildScoreIndicator(ClassroomProvider p) {
    final stats = p.getGameStats();
    final int displayScore = stats['displayScore'] ?? (stats['puzzleScore'] ?? 0);
    final int maxScore = stats['maxPossibleScore'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${stats['completedWords'] ?? 0}/${stats['totalWords'] ?? 0}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    '$displayScore/$maxScore',
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

  Future<void> _confirmEnd(ClassroomProvider p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sınavı Bitir'),
        content: const Text(
            'Sınavı şu an bitirirseniz tüm öğrencilerin sonuçları kaydedilir. Devam edilsin mi?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
    if (ok == true) await p.endExamEarly();
  }

  /// Öğretmen geri/kapat tuşuna bastığında — sınav sona erdirilip
  /// herkes results ekranına yönlendirilir.
  Future<void> _showTeacherLeaveDialog(ClassroomProvider p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Ayrılmak İstediğinizden\nEmin Misiniz?'),
          ],
        ),
        content: const Text(
          'Ayrılırsanız sınav sona erer ve tüm öğrenciler oyundan düşer.\n\nDevam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sınavı Bitir ve Ayrıl'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      // endExamEarly → sunucu onGameEnded event'i ateşler →
      // _onGameEnded status=finished → ClassroomGameScreen otomatik
      // ClassroomResultsScreen'e yönlendirir.
      await p.endExamEarly();
    }
  }

  void _showLeaveWarningDialog(ClassroomProvider p) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Sınavdan Ayrıl'),
          ],
        ),
        content: const Text(
          'Sınav devam ediyor. Ayrılırsanız oyundan düşmüş görüneceksiniz ve puanınız kaydedilmeyecek.\n\nYine de ayrılmak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Devam Et'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ayrıl ve Oyundan Düş'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        p.leaveRoom();
        Navigator.of(context).pop();
      }
    });
  }

  // =========================================================
  // ÖĞRETMEN — CANLI İZLEME PANELİ
  // =========================================================
  Widget _buildTeacherMonitor(ClassroomProvider p, theme) {
    final students = [...p.students];
    students.sort((a, b) {
      if (a.isFinished != b.isFinished) return a.isFinished ? -1 : 1;
      if (b.score != a.score) return b.score - a.score;
      return b.progress - a.progress;
    });
    final totalWords = p.puzzle?.words.length ?? 0;
    final activeCount = students.where((s) => !s.disconnected).length;
    final finishedCount = students.where((s) => s.isFinished).length;
    final avgProgress = students.isEmpty
        ? 0
        : students.map((s) => s.progress).reduce((a, b) => a + b) ~/
            students.length;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Üst KPI çubuğu
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _kpi(Icons.groups, '$activeCount/${students.length}',
                      'Aktif öğrenci', Colors.blue),
                  _kpi(Icons.check_circle, '$finishedCount',
                      'Tamamlayan', Colors.green),
                  _kpi(Icons.trending_up, '%$avgProgress',
                      'Ortalama ilerleme', Colors.orange),
                  _kpi(Icons.list_alt, '$totalWords', 'Toplam soru',
                      Colors.purple),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('Hiç öğrenci yok'))
                : LayoutBuilder(
                    builder: (ctx, c) {
                      final cols = c.maxWidth > 900
                          ? 3
                          : c.maxWidth > 600
                              ? 2
                              : 1;
                      return GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.6,
                        ),
                        itemCount: students.length,
                        itemBuilder: (_, i) =>
                            _teacherStudentCard(students[i], totalWords, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teacherStudentCard(
      ClassroomMember s, int totalWords, ClassroomProvider p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: s.disconnected
                      ? Colors.grey
                      : s.isFinished
                          ? Colors.green
                          : Colors.indigo,
                  child: s.isFinished
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          s.displayName.isNotEmpty
                              ? s.displayName.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      if (s.disconnected)
                        const Text('bağlantı kesik',
                            style: TextStyle(
                                fontSize: 10, color: Colors.red)),
                      if (s.isFinished)
                        Text(
                          'Tamamladı${s.finishOrder != null ? ' (#${s.finishOrder})' : ''}'
                          '${s.durationSeconds != null ? ' • ${_formatDuration(s.durationSeconds!)}' : ''}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.green),
                        ),
                    ],
                  ),
                ),
                if (!s.isFinished)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (v) async {
                      if (v == 'kick') await p.kickStudent(s.id);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'kick', child: Text('Sınıftan çıkar')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s.progress / 100.0,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(s.isFinished
                    ? Colors.green
                    : s.progress > 75
                        ? Colors.lightGreen
                        : s.progress > 40
                            ? Colors.orange
                            : Colors.indigo),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                _miniStat(Icons.task_alt, '${s.completedWords}/$totalWords'),
                _miniStat(Icons.star, '${s.score}'),
                _miniStat(
                  Icons.lightbulb_outline,
                  '${s.hintsUsed}/${p.settings.hintLimit}',
                  warning: s.hintsUsed >= p.settings.hintLimit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, {bool warning = false}) {
    final color = warning ? Colors.red : Colors.black54;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Text(value, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}d ${s}s';
  }

  // =========================================================
  // ÖĞRENCİ — OYUN
  // =========================================================
  Widget _buildStudentGame(ClassroomProvider p, theme) {
    if (p.puzzle == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final myMember = p.members.where((m) => m.id == p.playerId).firstOrNull;
    final isDropped = myMember?.disconnected == true;

    // bottomNavigationBar için klavye veya tamamlandı barı bir üst widget'ta
    // yönetildiğinden burada sadece oyun alanını döndürüyoruz.
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.primaryColor.withOpacity(0.03),
                Colors.white,
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return isWide ? _buildWideLayout(p) : _buildNarrowLayout(p);
            },
          ),
        ),
        if (isDropped) _buildDroppedOverlay(p),
      ],
    );
  }

  Widget _buildWideLayout(ClassroomProvider p) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (p.selectedWord != null)
                  FadeTransition(
                    opacity: _clueFade,
                    child: _buildSelectedClueCard(p.selectedWord!),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: CrosswordGridWidget(
                    puzzle: p.puzzle!,
                    userAnswers: p.userAnswers,
                    selectedWord: p.selectedWord,
                    selectedCell: p.selectedCell,
                    correctCells: p.correctCells,
                    hintedCells: p.hintedCells,
                    onCellTap: (row, col) => p.selectCell(row, col),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: CluesListWidget(
            acrossWords: p.puzzle!.acrossWords,
            downWords: p.puzzle!.downWords,
            selectedWord: p.selectedWord,
            completedWordIds: p.completedWordIds,
            onClueTap: (word) => p.selectWord(word),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(ClassroomProvider p) {
    return Column(
      children: [
        if (p.selectedWord != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: FadeTransition(
              opacity: _clueFade,
              child: _buildSelectedClueCard(p.selectedWord!),
            ),
          ),
        Flexible(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: CrosswordGridWidget(
              puzzle: p.puzzle!,
              userAnswers: p.userAnswers,
              selectedWord: p.selectedWord,
              selectedCell: p.selectedCell,
              correctCells: p.correctCells,
              hintedCells: p.hintedCells,
              onCellTap: (row, col) => p.selectCell(row, col),
            ),
          ),
        ),
        Flexible(
          flex: 3,
          child: CluesListWidget(
            acrossWords: p.puzzle!.acrossWords,
            downWords: p.puzzle!.downWords,
            selectedWord: p.selectedWord,
            completedWordIds: p.completedWordIds,
            onClueTap: (word) => p.selectWord(word),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedClueCard(CrosswordWord word) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final lightBg =
        Color.alphaBlend(primaryColor.withOpacity(0.10), Colors.white);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, -0.2), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: Card(
        key: ValueKey(word.id),
        color: lightBg,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  word.number.toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
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
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          word.isAcross ? 'Yatay' : 'Dikey',
                          style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${word.length} harf)',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(word.question,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDroppedOverlay(ClassroomProvider p) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 56, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Oyundan Düştünüz',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bağlantınız kesildi veya sınavdan ayrıldınız.\nÖğretmen sizi oyundan düşmüş olarak görüyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    p.leaveRoom();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Ana Menüye Dön'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(14),
        color: Colors.green.shade50,
        child: Center(
          child: Text(
            '🎉 Bulmacayı tamamladın! Sınav bitmesi bekleniyor...',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800),
          ),
        ),
      ),
    );
  }

  /// Ana crossword_game_screen.dart ile birebir aynı klavye.
  Widget _buildKeyboard(ClassroomProvider p) {
    final List<List<String>> rows = [
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', '⌫'],
    ];

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxKeyWidth = (constraints.maxWidth - 48) / 12;
          final double keyWidth = maxKeyWidth.clamp(22.0, 32.0);
          final double keyHeight = keyWidth * 1.1;

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
                      final bool isBackspace = key == '⌫';
                      final bool isNumber = RegExp(r'[0-9]').hasMatch(key);

                      Color keyColor = Colors.white;
                      if (isBackspace) keyColor = Colors.red.shade100;
                      else if (isNumber) keyColor = Colors.blue.shade50;

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
                                p.deleteLetter();
                              } else {
                                p.enterLetter(key);
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
}
