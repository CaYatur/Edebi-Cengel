import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/classroom_provider.dart';
import '../../providers/theme_provider.dart';

/// Sınav bitti ekranı — tamamen responsive, her çözünürlükte taşma yok.
class ClassroomResultsScreen extends StatelessWidget {
  const ClassroomResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentAppTheme;
    final p = context.watch<ClassroomProvider>();

    final sorted = [...p.results];
    sorted.sort((a, b) {
      final fa = a['finishOrder'] as int?;
      final fb = b['finishOrder'] as int?;
      if (fa != null && fb != null) return fa.compareTo(fb);
      if (fa != null) return -1;
      if (fb != null) return 1;
      return (b['score'] as int? ?? 0).compareTo(a['score'] as int? ?? 0);
    });
    final students = sorted.where((r) => r['isTeacher'] != true).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await p.leaveRoom();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Sınav Sonuçları — ${p.meta.title}',
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: BoxDecoration(gradient: theme.appBarGradient),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Kapat ve Çık',
            onPressed: () async {
              await p.leaveRoom();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (p.endReason != null)
                    _EndReasonBanner(reason: p.endReason!),

                  const SizedBox(height: 8),

                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _PodiumSection(students: students),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _AggregateSection(
                            agg: p.aggregate,
                            studentCount: students.length,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _PodiumSection(students: students),
                    const SizedBox(height: 12),
                    _AggregateSection(
                      agg: p.aggregate,
                      studentCount: students.length,
                    ),
                  ],

                  const SizedBox(height: 12),

                  _RankingTable(students: students),

                  const SizedBox(height: 16),

                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text(
                        'Ana Sayfaya Dön',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () async {
                        await p.leaveRoom();
                        if (context.mounted) {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// BANNER
// ─────────────────────────────────────────────────────────────────
class _EndReasonBanner extends StatelessWidget {
  final String reason;
  const _EndReasonBanner({required this.reason});

  @override
  Widget build(BuildContext context) {
    const msgs = {
      'all_finished': 'Tüm öğrenciler bulmacayı tamamladı.',
      'teacher_ended': 'Öğretmen sınavı sonlandırdı.',
      'teacher_left': 'Öğretmen ayrıldı, sınav sona erdi.',
      'time_limit': 'Süre doldu.',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.indigo.shade600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msgs[reason] ?? 'Sınav sona erdi.',
              style: TextStyle(color: Colors.indigo.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PODYUM
// ─────────────────────────────────────────────────────────────────
class _PodiumSection extends StatelessWidget {
  final List<Map<String, dynamic>> students;
  const _PodiumSection({required this.students});

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) return const SizedBox.shrink();
    final top = students.take(3).toList();

    const medals = ['🥇', '🥈', '🥉'];
    const podiumColors = [
      Color(0xFFFFD700),
      Color(0xFFC0C0C0),
      Color(0xFFCD7F32),
    ];

    final order = top.length >= 3
        ? [1, 0, 2]
        : top.length == 2
            ? [1, 0]
            : [0];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Podyum',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (ctx, c) {
              final slotW =
                  (c.maxWidth / order.length).clamp(60.0, 120.0);
              final baseH = (slotW * 0.72).clamp(36.0, 86.0);
              final heights = [baseH, baseH * 0.78, baseH * 0.60];

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: order.map((i) {
                  if (i >= top.length) return SizedBox(width: slotW);
                  final r = top[i];
                  return _PodiumSlot(
                    rank: i + 1,
                    medal: medals[i],
                    color: podiumColors[i],
                    blockHeight: heights[i],
                    slotWidth: slotW,
                    name: r['displayName']?.toString() ?? 'Öğrenci',
                    score: (r['score'] ?? 0) as int,
                    completed: (r['completedWords'] ?? 0) as int,
                    total: (r['totalWords'] ?? 1) as int,
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final int rank;
  final String medal;
  final Color color;
  final double blockHeight;
  final double slotWidth;
  final String name;
  final int score;
  final int completed;
  final int total;

  const _PodiumSlot({
    required this.rank,
    required this.medal,
    required this.color,
    required this.blockHeight,
    required this.slotWidth,
    required this.name,
    required this.score,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fs = (slotWidth * 0.10).clamp(9.0, 12.0);
    return SizedBox(
      width: slotWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medal,
              style: TextStyle(
                  fontSize: (slotWidth * 0.20).clamp(14.0, 24.0))),
          const SizedBox(height: 2),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: fs + 1)),
          Text('$completed/$total',
              style: TextStyle(fontSize: fs - 1, color: Colors.black54)),
          Text('$score puan',
              style: TextStyle(fontSize: fs, color: Colors.black87)),
          const SizedBox(height: 4),
          Container(
            width: slotWidth * 0.68,
            height: blockHeight,
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 3)),
              ],
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$rank',
                style: TextStyle(
                    fontSize: (slotWidth * 0.18).clamp(12.0, 24.0),
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// İSTATİSTİK KARTLARI
// ─────────────────────────────────────────────────────────────────
class _AggregateSection extends StatelessWidget {
  final Map<String, dynamic> agg;
  final int studentCount;
  const _AggregateSection(
      {required this.agg, required this.studentCount});

  String _fmt(dynamic v, {bool pct = false, bool dur = false}) {
    if (v == null) return '—';
    if (dur) {
      final s = (v as num).round();
      final m = s ~/ 60;
      final sec = s % 60;
      if (m == 0) return '${sec}sn';
      return '${m}dk ${sec}sn';
    }
    if (pct) return '%${(v as num).round()}';
    return (v as num).round().toString();
  }

  @override
  Widget build(BuildContext context) {
    if (agg.isEmpty) return const SizedBox.shrink();

    final items = [
      _StatItem(Icons.people, 'Katılımcı', '$studentCount kişi',
          Colors.blue),
      _StatItem(Icons.check_circle_outline, 'Tamamlayan',
          '${agg['finishedCount'] ?? 0} kişi', Colors.green),
      _StatItem(
          Icons.star, 'Ort. Puan', _fmt(agg['avgScore']), Colors.amber),
      _StatItem(Icons.percent, 'Ort. Tamamlama',
          _fmt(agg['avgCompletion'], pct: true), Colors.teal),
      _StatItem(Icons.lightbulb_outline, 'Ort. İpucu',
          _fmt(agg['avgHintsUsed']), Colors.orange),
      _StatItem(Icons.timer_outlined, 'Ort. Süre',
          _fmt(agg['avgDuration'], dur: true), Colors.purple),
      _StatItem(Icons.text_fields, 'Harf Yardımı',
          _fmt(agg['avgLettersRevealed']), Colors.red.shade400),
      _StatItem(
          Icons.abc, 'Kelime Yardımı', _fmt(agg['avgWordsRevealed']),
          Colors.brown),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sınıf İstatistikleri',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (ctx, c) {
              final cols = c.maxWidth > 400 ? 4 : 2;
              final ratio = c.maxWidth > 400 ? 1.15 : 1.2;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: ratio,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (_, i) => _StatCard(item: items[i]),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: item.color.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: item.color, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: item.color.withOpacity(0.9)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SIRALAMA TABLOSU
// ─────────────────────────────────────────────────────────────────
class _RankingTable extends StatelessWidget {
  final List<Map<String, dynamic>> students;
  const _RankingTable({required this.students});

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
            child: Text('Henüz öğrenci verisi yok.',
                style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Tüm Öğrenciler',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...students.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final r = entry.value;
          final name = r['displayName']?.toString() ?? 'Öğrenci';
          final score = (r['score'] ?? 0) as int;
          final completed = (r['completedWords'] ?? 0) as int;
          final total = (r['totalWords'] ?? 1) as int;
          final hints = (r['hintsUsed'] ?? 0) as int;
          final lettersRev = (r['lettersRevealed'] ?? 0) as int;
          final wordsRev = (r['wordsRevealed'] ?? 0) as int;
          final dur = r['durationSeconds'] as int?;
          final finished = r['isFinished'] == true;
          final pct =
              total > 0 ? ((completed / total) * 100).round() : 0;

          Color rankColor = Colors.grey.shade400;
          if (rank == 1) rankColor = const Color(0xFFFFD700);
          if (rank == 2) rankColor = const Color(0xFFC0C0C0);
          if (rank == 3) rankColor = const Color(0xFFCD7F32);

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: finished
                  ? Colors.green.withOpacity(0.04)
                  : Colors.grey.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: finished
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey.shade200),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 2),
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rankColor.withOpacity(0.2),
                  border: Border.all(color: rankColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text('$rank',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: rankColor,
                        fontSize: 13)),
              ),
              title: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                '$completed/$total kelime  •  $score puan  •  $pct%',
                style:
                    const TextStyle(fontSize: 11, color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
              trailing: finished
                  ? const Icon(Icons.check_circle,
                      color: Colors.green, size: 18)
                  : const Icon(Icons.hourglass_bottom,
                      color: Colors.orange, size: 18),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  // Wrap → dar ekranda çipler alt satıra geçer, Row overflow olmaz
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip(Icons.lightbulb_outline,
                          '$hints ipucu', Colors.orange),
                      _chip(Icons.text_fields,
                          '$lettersRev harf', Colors.red.shade400),
                      _chip(Icons.abc,
                          '$wordsRev kelime', Colors.brown),
                      if (dur != null)
                        _chip(Icons.timer_outlined, () {
                          final m = dur ~/ 60;
                          final s = dur % 60;
                          return m == 0 ? '${s}sn' : '${m}dk ${s}sn';
                        }(), Colors.purple),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 13, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.2)),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────
class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatItem(this.icon, this.label, this.value, this.color);
}

