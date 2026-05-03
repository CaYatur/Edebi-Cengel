import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/crossword_category.dart';
import '../../models/crossword_clue.dart';
import '../../providers/classroom_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/classroom_service.dart';
import '../../services/crossword_category_service.dart';
import 'classroom_room_screen.dart';
import 'classroom_questions_screen.dart';

/// Öğretmen — sınav kurulumu (ayarlar + soru seçimi).
/// Önce odayı oluşturmaz; öğretmen "Sınıfı Aç" butonuna bastığında oluşturur.
class ClassroomSetupScreen extends StatefulWidget {
  const ClassroomSetupScreen({super.key});

  @override
  State<ClassroomSetupScreen> createState() => _ClassroomSetupScreenState();
}

class _ClassroomSetupScreenState extends State<ClassroomSetupScreen> {
  final _categoryService = CrosswordCategoryService();
  final _titleCtrl = TextEditingController(text: 'Sınıf Sınavı');
  final _descCtrl = TextEditingController();

  bool _loading = true;
  bool _creating = false;

  // Ayarlar
  int _hintLimit = 3;
  int _timeLimitMinutes = 0; // 0 = sınırsız
  int _maxStudents = 50;
  int _gridSize = 15;
  bool _allowLetterHint = true;
  bool _allowWordHint = true;
  bool _showScoreboard = true;

  // Seçili sorular: id → CrosswordClue
  final Map<String, CrosswordClue> _selectedClues = {};
  // Özel sorular (sunucudan)
  List<Map<String, dynamic>> _customQuestions = [];

  // Filtreleme
  String _selectedCategoryId = 'all';
  int _difficultyFilter = 0; // 0=hepsi, 1/2/3
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _categoryService.initialize();
    final custom = await ClassroomService.instance.listCustomQuestions();
    if (!mounted) return;
    setState(() {
      _customQuestions = custom;
      _loading = false;
    });
  }

  List<CrosswordCategory> get _allCategories => _categoryService.allCategories;

  /// Filtre uygulanmış soru havuzu (sistem + özel)
  List<_ClueOption> _buildPool() {
    final out = <_ClueOption>[];
    // Sistem soruları
    for (final cat in _allCategories) {
      if (_selectedCategoryId != 'all' && _selectedCategoryId != cat.id) continue;
      for (final c in cat.clues) {
        if (_difficultyFilter != 0 && c.difficulty != _difficultyFilter) {
          continue;
        }
        if (_searchTerm.isNotEmpty &&
            !c.question.toLowerCase().contains(_searchTerm.toLowerCase()) &&
            !c.answer.toLowerCase().contains(_searchTerm.toLowerCase())) {
          continue;
        }
        out.add(_ClueOption(clue: c, source: cat.name));
      }
    }
    // Özel sorular
    if (_selectedCategoryId == 'all' || _selectedCategoryId == 'custom') {
      for (final q in _customQuestions) {
        final difficulty = (q['difficulty'] ?? 2) as int;
        if (_difficultyFilter != 0 && difficulty != _difficultyFilter) continue;
        final question = (q['question'] ?? '').toString();
        final answer = (q['answer'] ?? '').toString();
        if (_searchTerm.isNotEmpty &&
            !question.toLowerCase().contains(_searchTerm.toLowerCase()) &&
            !answer.toLowerCase().contains(_searchTerm.toLowerCase())) {
          continue;
        }
        out.add(_ClueOption(
          clue: CrosswordClue(
            id: q['id'] as String,
            question: question,
            answer: answer,
            difficulty: difficulty,
          ),
          source: (q['categoryName'] ?? 'Özel Sorular').toString(),
          isCustom: true,
        ));
      }
    }
    return out;
  }

  bool _canFitInGrid(CrosswordClue c) =>
      c.cleanAnswer.length >= 2 && c.cleanAnswer.length <= _gridSize;

  Future<void> _createAndStart() async {
    final selected = _selectedClues.values.toList();
    final invalid = selected.where((c) => !_canFitInGrid(c)).toList();
    if (selected.length < 2) {
      _snack('En az 2 soru seçmelisiniz.');
      return;
    }
    if (invalid.isNotEmpty) {
      _snack(
          'Seçili ${invalid.length} sorunun cevabı grid (${_gridSize}x$_gridSize) için uygun değil. '
          'Lütfen daha kısa cevaplı sorular seçin veya grid boyutunu artırın.');
      return;
    }

    final provider = context.read<ClassroomProvider>();
    setState(() => _creating = true);

    // 1) Önce sınıfı oluştur (öğretmen oda kodunu görmek için)
    final ok = await provider.createRoom(
      settings: ClassroomSettings(
        hintLimit: _hintLimit,
        timeLimit: _timeLimitMinutes * 60,
        maxStudents: _maxStudents,
        gridSize: _gridSize,
        allowLetterHint: _allowLetterHint,
        allowWordHint: _allowWordHint,
        showScoreboard: _showScoreboard,
      ),
      meta: ClassroomMeta(
        title: _titleCtrl.text.trim().isEmpty
            ? 'Sınıf Sınavı'
            : _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _creating = false);

    if (!ok) {
      _snack(provider.errorMessage ?? 'Sınıf oluşturulamadı');
      return;
    }

    // Bulmaca pre-validation: bulmaca yerleşimi mümkün mü?
    final preview = await provider.startExamWithClues(selected);
    if (!preview.ok) {
      // Açılmış olan odayı geri al — orphan oda kalmasın
      await provider.leaveRoom();
      _snack(preview.message ?? 'Bulmaca oluşturulamadı.');
      return;
    }
    if (preview.warning && preview.message != null) {
      // Kullanıcıya uyarıyı şimdi göster, ama yine de odayı açık bırak
      _snack(preview.message!);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: ClassroomRoomScreen(initialSelectedClues: selected),
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openCustomBank() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ClassroomQuestionsScreen(
          selectionMode: true,
          initialSelected: _selectedClues.keys
              .where((id) => _customQuestions.any((q) => q['id'] == id))
              .toSet(),
        ),
      ),
    );
    // Soru bankası değişmiş olabilir; tazele
    final fresh = await ClassroomService.instance.listCustomQuestions();
    if (!mounted) return;
    setState(() => _customQuestions = fresh);

    if (result == null) return;
    // Sonuçtaki ID'lere karşılık gelen özel soruları seçimine ekle
    for (final id in result) {
      final q = _customQuestions.firstWhere(
        (x) => x['id'] == id,
        orElse: () => {},
      );
      if (q.isEmpty) continue;
      _selectedClues[id] = CrosswordClue(
        id: id,
        question: (q['question'] ?? '').toString(),
        answer: (q['answer'] ?? '').toString(),
        difficulty: (q['difficulty'] ?? 2) as int,
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentAppTheme;
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pool = _buildPool();
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınav Hazırla',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: theme.appBarGradient),
        ),
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 5, child: _buildLeftPane(pool)),
                Container(width: 1, color: Colors.grey.shade300),
                Expanded(flex: 4, child: _buildRightPane(theme)),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildLeftPane(pool, embedded: true),
                  const Divider(),
                  _buildRightPane(theme, embedded: true),
                ],
              ),
            ),
      bottomNavigationBar: Material(
        elevation: 8,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedClues.length} soru seçildi',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  onPressed: _creating ? null : _createAndStart,
                  icon: _creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.meeting_room),
                  label: const Text('Sınıfı Aç'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----- SOL: Soru havuzu -----
  Widget _buildLeftPane(List<_ClueOption> pool, {bool embedded = false}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Soru Havuzu',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Soru veya cevap ara...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchTerm = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'all', child: Text('Tüm Kategoriler')),
                        const DropdownMenuItem(
                            value: 'custom', child: Text('Özel Sorularım')),
                        ..._allCategories.map(
                          (c) => DropdownMenuItem(
                              value: c.id, child: Text(c.name)),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedCategoryId = v ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _difficultyFilter,
                      decoration: const InputDecoration(
                        labelText: 'Zorluk',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Hepsi')),
                        DropdownMenuItem(value: 1, child: Text('Kolay')),
                        DropdownMenuItem(value: 2, child: Text('Orta')),
                        DropdownMenuItem(value: 3, child: Text('Zor')),
                      ],
                      onChanged: (v) =>
                          setState(() => _difficultyFilter = v ?? 0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.library_add),
                    label: const Text('Soru Bankamdan Seç'),
                    onPressed: _openCustomBank,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _selectedClues.isEmpty
                        ? null
                        : () => setState(() => _selectedClues.clear()),
                    child: const Text('Seçimi Temizle'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: pool.isEmpty
              ? const Center(child: Text('Filtrede soru bulunamadı.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: pool.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) => _buildClueTile(pool[i]),
                ),
        ),
      ],
    );
    if (embedded) {
      return SizedBox(height: 520, child: content);
    }
    return content;
  }

  Widget _buildClueTile(_ClueOption opt) {
    final selected = _selectedClues.containsKey(opt.clue.id);
    final tooLong = !_canFitInGrid(opt.clue);
    final colors = const [
      Colors.grey,
      Colors.green,
      Colors.orange,
      Colors.red
    ];
    final diffColor = colors[opt.clue.difficulty.clamp(1, 3)];

    return Material(
      color: selected ? Colors.indigo.shade50 : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            if (selected) {
              _selectedClues.remove(opt.clue.id);
            } else {
              _selectedClues[opt.clue.id] = opt.clue;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.indigo : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedClues[opt.clue.id] = opt.clue;
                  } else {
                    _selectedClues.remove(opt.clue.id);
                  }
                }),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opt.clue.question,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _smallChip('Cevap: ${opt.clue.answer}', Colors.indigo),
                        _smallChip(
                            const ['', 'Kolay', 'Orta', 'Zor']
                                [opt.clue.difficulty.clamp(1, 3)],
                            diffColor),
                        _smallChip(opt.source, Colors.blueGrey),
                        if (opt.isCustom) _smallChip('Özel', Colors.purple),
                        if (tooLong)
                          _smallChip(
                              'Grid için uzun (${opt.clue.cleanAnswer.length})',
                              Colors.red),
                      ],
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

  Widget _smallChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  // ----- SAĞ: Sınav ayarları -----
  Widget _buildRightPane(theme, {bool embedded = false}) {
    final pool = _buildPool();
    final invalidCount =
        _selectedClues.values.where((c) => !_canFitInGrid(c)).length;

    final content = ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      children: [
        Text('Sınav Bilgileri',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Sınav Başlığı',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        TextField(
          controller: _descCtrl,
          maxLength: 200,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Açıklama (öğrencilere gösterilir)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),
        const Text('Sınav Ayarları',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _slider(
          'İpucu hakkı',
          _hintLimit.toDouble(),
          0,
          15,
          _hintLimit == 0 ? 'Kapalı' : '$_hintLimit ipucu',
          (v) => setState(() => _hintLimit = v.round()),
        ),
        _slider(
          'Süre limiti (dk)',
          _timeLimitMinutes.toDouble(),
          0,
          120,
          _timeLimitMinutes == 0 ? 'Sınırsız' : '$_timeLimitMinutes dk',
          (v) => setState(() => _timeLimitMinutes = v.round()),
        ),
        _slider(
          'En fazla öğrenci',
          _maxStudents.toDouble(),
          1,
          50,
          '$_maxStudents kişi',
          (v) => setState(() => _maxStudents = v.round()),
        ),
        _slider(
          'Grid boyutu',
          _gridSize.toDouble(),
          10,
          25,
          '${_gridSize}x$_gridSize',
          (v) => setState(() => _gridSize = v.round()),
        ),
        SwitchListTile(
          dense: true,
          value: _allowLetterHint,
          onChanged: (v) => setState(() => _allowLetterHint = v),
          title: const Text('Harf ipucu serbest'),
        ),
        SwitchListTile(
          dense: true,
          value: _allowWordHint,
          onChanged: (v) => setState(() => _allowWordHint = v),
          title: const Text('Kelime ipucu serbest'),
        ),
        SwitchListTile(
          dense: true,
          value: _showScoreboard,
          onChanged: (v) => setState(() => _showScoreboard = v),
          title: const Text('Öğrencilere skor tablosu göster'),
        ),
        const SizedBox(height: 12),
        // Validation banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: invalidCount > 0 || _selectedClues.length < 2
                ? Colors.red.shade50
                : Colors.green.shade50,
            border: Border.all(
              color: invalidCount > 0 || _selectedClues.length < 2
                  ? Colors.red.shade300
                  : Colors.green.shade300,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                invalidCount > 0 || _selectedClues.length < 2
                    ? Icons.warning_amber
                    : Icons.check_circle,
                color: invalidCount > 0 || _selectedClues.length < 2
                    ? Colors.red
                    : Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedClues.length < 2
                      ? 'Sınav için en az 2 soru seçmelisiniz. (${pool.length} soru havuzunuzda mevcut.)'
                      : invalidCount > 0
                          ? '$invalidCount soru grid boyutuyla uyumsuz. Daha kısa cevaplı sorular seçin veya grid\'i büyütün.'
                          : '${_selectedClues.length} soru hazır. Sınavı başlatabilirsiniz.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return content;
  }

  Widget _slider(String label, double v, double min, double max, String hint,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(hint, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          Slider(
            value: v,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ClueOption {
  final CrosswordClue clue;
  final String source;
  final bool isCustom;
  _ClueOption({required this.clue, required this.source, this.isCustom = false});
}
