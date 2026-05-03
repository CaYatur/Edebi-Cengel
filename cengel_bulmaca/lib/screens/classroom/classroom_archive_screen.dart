import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/classroom_service.dart';
import '../../services/auth_service.dart';

/// Öğretmenin geçmiş sınav arşivi ekranı.
/// Her kayıt detaylandırılabilir ve silinebilir.
class ClassroomArchiveScreen extends StatefulWidget {
  const ClassroomArchiveScreen({super.key});

  @override
  State<ClassroomArchiveScreen> createState() => _ClassroomArchiveScreenState();
}

class _ClassroomArchiveScreenState extends State<ClassroomArchiveScreen> {
  final ClassroomService _service = ClassroomService.instance;
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final token = AuthService.instance.token;
    if (token != null) _service.setAuthToken(token);
    AuthService.instance.addListener(_handleAuthChange);
    _load();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_handleAuthChange);
    super.dispose();
  }

  void _handleAuthChange() {
    if (!mounted) return;
    if (!AuthService.instance.isLoggedIn) {
      setState(() {
        _records = [];
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
  }

  Future<void> _load() async {
    if (!AuthService.instance.isLoggedIn) {
      setState(() {
        _records = [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.listHistory();
      // Tarihe göre en yeni önce
      list.sort((a, b) {
        final ta = a['createdAt']?.toString() ?? '';
        final tb = b['createdAt']?.toString() ?? '';
        return tb.compareTo(ta);
      });
      if (mounted) setState(() { _records = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Veriler yüklenemedi.'; _loading = false; });
    }
  }

  Future<void> _deleteRecord(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: const Text('Bu sınav kaydını kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.deleteHistoryRecord(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentAppTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınav Arşivi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: theme.appBarGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Tekrar Dene')),
                    ],
                  ),
                )
              : _records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('Henüz kayıtlı sınav yok.',
                              style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final rec = _records[index];
                        return _buildRecordCard(rec, theme);
                      },
                    ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> rec, dynamic theme) {
    final id = rec['id']?.toString() ?? '';
    final title = rec['meta']?['title']?.toString() ?? 'Sınav';
    final createdAt = rec['createdAt']?.toString() ?? '';
    final displayDate = _formatDate(createdAt);
    final studentCount = (rec['studentCount'] ?? 0) as int;
    final agg = rec['aggregate'] as Map<String, dynamic>? ?? {};
    final finishedCount = (agg['finishedCount'] ?? 0) as int;
    final avgScore = agg['avgScore'];
    final avgCompletion = agg['avgCompletion'];
    final avgHints = agg['avgHintsUsed'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [theme.primaryColor.withOpacity(0.8), theme.primaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.school, color: Colors.white, size: 22),
        ),
        title: Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text('$displayDate  •  $studentCount öğrenci',
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Kaydı Sil',
              onPressed: () => _deleteRecord(id),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                // Özet kutucukları
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(Icons.check_circle_outline,
                        '$finishedCount/$studentCount tamamladı',
                        Colors.green),
                    if (avgScore != null)
                      _chip(Icons.star_outline,
                          'Ort. ${(avgScore as num).round()} puan',
                          Colors.amber),
                    if (avgCompletion != null)
                      _chip(Icons.percent,
                          '%${(avgCompletion as num).round()} ort.',
                          Colors.teal),
                    if (avgHints != null)
                      _chip(Icons.lightbulb_outline,
                          '${(avgHints as num).round()} ort. ipucu',
                          Colors.orange),
                  ],
                ),
                const SizedBox(height: 12),
                // Öğrenci listesi
                if (rec['results'] != null)
                  _buildDetailedResults(rec['results'] as List),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedResults(List results) {
    // Öğrencileri sırala
    final students = results
        .cast<Map<String, dynamic>>()
        .where((r) => r['isTeacher'] != true)
        .toList();
    students.sort((a, b) {
      final fa = a['finishOrder'] as int?;
      final fb = b['finishOrder'] as int?;
      if (fa != null && fb != null) return fa.compareTo(fb);
      if (fa != null) return -1;
      if (fb != null) return 1;
      return (b['score'] as int? ?? 0).compareTo(a['score'] as int? ?? 0);
    });

    if (students.isEmpty) {
      return const Text('Öğrenci verisi bulunamadı.',
          style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Öğrenci Detayları',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade200, width: 0.5),
            columnWidths: const {
              0: FlexColumnWidth(0.5),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
              5: FlexColumnWidth(1.2),
            },
            children: [
              // Başlık satırı
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  _TableHeader('#'),
                  _TableHeader('İsim'),
                  _TableHeader('Puan'),
                  _TableHeader('Tamaml.'),
                  _TableHeader('İpucu'),
                  _TableHeader('Süre'),
                ],
              ),
              // Veri satırları
              ...students.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                final dur = r['durationSeconds'] as int?;
                final durStr = dur != null
                    ? '${(dur ~/ 60)}d ${dur % 60}s'
                    : '—';
                final comp = (r['completedWords'] ?? 0) as int;
                final total = (r['totalWords'] ?? 1) as int;
                return TableRow(
                  decoration: BoxDecoration(
                    color: i % 2 == 0 ? Colors.white : Colors.grey.shade50,
                  ),
                  children: [
                    _TableCell('${i + 1}'),
                    _TableCell(r['displayName']?.toString() ?? '—'),
                    _TableCell('${r['score'] ?? 0}'),
                    _TableCell('$comp/$total'),
                    _TableCell('${r['hintsUsed'] ?? 0}'),
                    _TableCell(durStr),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.2)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// --- Yardımcı widget'lar ---

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54)),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
    );
  }
}
