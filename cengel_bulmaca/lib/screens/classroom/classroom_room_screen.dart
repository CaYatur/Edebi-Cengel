import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/crossword_clue.dart';
import '../../providers/classroom_provider.dart';
import '../../providers/theme_provider.dart';
import 'classroom_game_screen.dart';
import 'classroom_results_screen.dart';

/// Oda ekranı:
/// - Öğretmen ise: büyük oda kodu + canlı öğrenci paneli + Başlat butonu.
/// - Öğrenci ise: bekleme + öğretmen + diğer öğrenciler.
class ClassroomRoomScreen extends StatefulWidget {
  /// Öğretmen önceden setup'ta seçtiği soruları taşır
  final List<CrosswordClue>? initialSelectedClues;

  const ClassroomRoomScreen({super.key, this.initialSelectedClues});

  @override
  State<ClassroomRoomScreen> createState() => _ClassroomRoomScreenState();
}

class _ClassroomRoomScreenState extends State<ClassroomRoomScreen> {
  bool _starting = false;
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentAppTheme;

    return Consumer<ClassroomProvider>(
      builder: (context, p, _) {
        // Sınav başladıysa oyun ekranına geç
        if (p.status == ClassroomStatus.playing && !_navigated) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: p,
                  child: const ClassroomGameScreen(),
                ),
              ),
            );
          });
        }
        // Sınav bittiyse / oda kapatıldıysa sonuç ekranına geç.
        // Sonuç ekranı boş veri durumunu da kendi ele alıyor.
        if (p.status == ClassroomStatus.finished && !_navigated) {
          _navigated = true;
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
        // Öğrenci sınıftan atıldıysa ana sayfaya dön
        if (p.status == ClassroomStatus.idle && p.errorMessage != null && !_navigated) {
          _navigated = true;
          final msg = p.errorMessage!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            p.clearError();
            Navigator.of(context).popUntil((r) => r.isFirst);
          });
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (!didPop) {
              final allow = await _confirmLeave(p);
              if (allow && context.mounted) Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(p.meta.title.isEmpty ? 'Sınıf' : p.meta.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              flexibleSpace: Container(
                decoration: BoxDecoration(gradient: theme.appBarGradient),
              ),
              actions: [
                IconButton(
                  tooltip: 'Çık',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    final ok = await _confirmLeave(p);
                    if (ok && mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
            body: p.isTeacher ? _buildTeacherView(p, theme) : _buildStudentView(p, theme),
          ),
        );
      },
    );
  }

  Future<bool> _confirmLeave(ClassroomProvider p) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.isTeacher ? 'Sınıfı Kapat' : 'Sınıftan Ayrıl'),
        content: Text(p.isTeacher
            ? 'Sınıfı kapatırsanız tüm öğrencilerin bağlantısı kesilir.'
            : 'Sınıftan ayrılmak istediğinize emin misiniz?'),
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
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (result == true) {
      await p.leaveRoom();
      return true;
    }
    return false;
  }

  // ===================== ÖĞRETMEN PANELİ =====================
  Widget _buildTeacherView(ClassroomProvider p, theme) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final code = p.roomCode ?? '------';

    final codeBlock = _buildRoomCodeBlock(code, isWide, theme);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          codeBlock,
          const SizedBox(height: 16),
          _teacherInfoBar(p, theme),
          const SizedBox(height: 16),
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _teacherStudentPanel(p)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _teacherActions(p, theme)),
                  ],
                )
              : Column(
                  children: [
                    _teacherStudentPanel(p),
                    const SizedBox(height: 16),
                    _teacherActions(p, theme),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildRoomCodeBlock(String code, bool isWide, theme) {
    final primary = theme.primaryColor as Color;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 24, vertical: isWide ? 32 : 20),
      decoration: BoxDecoration(
        gradient: theme.appBarGradient as LinearGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: primary.withOpacity(0.30),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          const Text('Sınıf Kodu',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4)),
          const SizedBox(height: 6),
          // Asıl kod — masaüstünde devasa
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              code,
              style: TextStyle(
                color: Colors.white,
                fontSize: isWide ? 120 : 64,
                fontWeight: FontWeight.w900,
                letterSpacing: isWide ? 22 : 10,
                shadows: const [
                  Shadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(2, 4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Öğrenciler bu kodu kullanarak sınıfa katılır',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primary,
                ),
                icon: const Icon(Icons.copy),
                label: const Text('Kopyala'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kod kopyalandı')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teacherInfoBar(ClassroomProvider p, theme) {
    final s = p.settings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _stat(Icons.groups, '${p.students.length}/${s.maxStudents}', 'Öğrenci'),
            _stat(Icons.lightbulb_outline,
                s.hintLimit == 0 ? 'Yok' : '${s.hintLimit}', 'İpucu'),
            _stat(Icons.timer,
                s.timeLimit == 0 ? 'Sınırsız' : '${(s.timeLimit / 60).round()} dk',
                'Süre'),
            _stat(Icons.grid_4x4, '${s.gridSize}x${s.gridSize}', 'Grid'),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    final primary = context.read<ThemeProvider>().currentAppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primary, size: 16),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _teacherStudentPanel(ClassroomProvider p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sınıfa Katılanlar',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (p.students.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.hourglass_empty,
                          color: Colors.grey.shade400, size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        'Öğrenci bekleniyor...',
                        style: TextStyle(color: Colors.black45),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...p.students.map((s) => _studentTile(s, p)),
          ],
        ),
      ),
    );
  }

  Widget _studentTile(ClassroomMember s, ClassroomProvider p) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: s.disconnected ? Colors.grey.shade100 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: s.disconnected ? Colors.grey : Colors.green,
            child: Text(
              s.displayName.isNotEmpty
                  ? s.displayName.substring(0, 1).toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.displayName + (s.disconnected ? '  (bağlantı kesik)' : ''),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            tooltip: 'Sınıftan çıkar',
            icon: const Icon(Icons.person_remove, color: Colors.redAccent),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('${s.displayName} sınıftan çıkarılsın mı?'),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Vazgeç'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Çıkar'),
                    ),
                  ],
                ),
              );
              if (ok == true) await p.kickStudent(s.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _teacherActions(ClassroomProvider p, theme) {
    final canStart =
        p.students.isNotEmpty && (widget.initialSelectedClues?.isNotEmpty ?? false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sınavı Başlat',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.initialSelectedClues == null ||
                              widget.initialSelectedClues!.isEmpty
                          ? 'Soru seçilmedi. Önceki adıma dönüp soru seçin.'
                          : '${widget.initialSelectedClues!.length} soru hazır.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed:
                    !canStart || _starting ? null : () => _startExam(p),
                icon: _starting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_rounded, size: 26),
                label: const Text('Sınavı Başlat',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startExam(ClassroomProvider p) async {
    final clues = widget.initialSelectedClues;
    if (clues == null || clues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soru seçilmedi.')),
      );
      return;
    }
    setState(() => _starting = true);
    final pre = await p.startExamWithClues(clues);
    if (!pre.ok || pre.puzzle == null) {
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pre.message ?? 'Bulmaca oluşturulamadı.')),
      );
      return;
    }
    if (pre.warning) {
      final primary = Theme.of(context).primaryColor;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Uyarı'),
          content: Text(pre.message ?? ''),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yine de Başlat'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        setState(() => _starting = false);
        return;
      }
    }
    final ok = await p.commitStart(pre.puzzle!);
    setState(() => _starting = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(p.errorMessage ?? 'Sınav başlatılamadı')),
      );
    }
  }

  // ===================== ÖĞRENCİ GÖRÜNÜMÜ =====================
  Widget _buildStudentView(ClassroomProvider p, theme) {
    final primary = theme.primaryColor as Color;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary.withOpacity(0.18), primary.withOpacity(0.06)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.school, size: 56, color: primary),
                const SizedBox(height: 8),
                Text(
                  p.meta.title,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primary),
                ),
                if (p.meta.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(p.meta.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54)),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top, color: primary),
                      const SizedBox(width: 8),
                      Text('Öğretmen sınavı başlatmayı bekliyor...',
                          style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sınıftakiler',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (p.teacher != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: primary,
                        child: const Icon(Icons.school, color: Colors.white),
                      ),
                      title: Text(p.teacher!.displayName),
                      subtitle: const Text('Öğretmen'),
                    ),
                  const Divider(),
                  ...p.students.map((s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade400,
                          child: Text(
                            s.displayName.isNotEmpty
                                ? s.displayName.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(s.displayName),
                        trailing: s.id == p.playerId
                            ? const Text('Sen',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold))
                            : null,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
