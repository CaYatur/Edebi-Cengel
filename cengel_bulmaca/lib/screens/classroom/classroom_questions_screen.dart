import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';

/// Öğretmenin özel soru bankası — kategoriye göre düz, drill-down ekran.
///
/// Akış:
///   1) Bu ekran (ana liste): kategoriler + yeni kategori oluştur
///   2) Kategoriye tıkla → [_CategoryDetailScreen]: o kategorideki sorular,
///      yeni soru ekle, sil, seç (toplu / tek tek)
///
/// `selectionMode = true` ise pop'ta seçili soru ID listesi geri döner.
class ClassroomQuestionsScreen extends StatefulWidget {
  final bool selectionMode;
  final Set<String>? initialSelected;

  const ClassroomQuestionsScreen({
    super.key,
    this.selectionMode = false,
    this.initialSelected,
  });

  @override
  State<ClassroomQuestionsScreen> createState() =>
      _ClassroomQuestionsScreenState();
}

class _ClassroomQuestionsScreenState extends State<ClassroomQuestionsScreen> {
  // Tüm sorular (sunucudan gelen ham liste)
  List<Map<String, dynamic>> _allQuestions = [];
  // Lokal kategori listesi — sorular silinse de kullanıcı boş kategoriyi
  // tutmak isteyebilir, bu yüzden ayrı tutuyoruz
  Set<String> _localCategories = {};
  // Seçili soru ID'leri (selectionMode için ekranlar arası taşınır)
  final Set<String> _selectedIds = {};

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelected != null) {
      _selectedIds.addAll(widget.initialSelected!);
    }
    AuthService.instance.addListener(_handleAuthChange);
    _load();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_handleAuthChange);
    super.dispose();
  }

  /// Çıkış yapılınca ekrandaki cache'i hemen boşalt — bir sonraki kullanıcı
  /// (veya tekrar giriş) öncekinin sorularını görmesin.
  void _handleAuthChange() {
    if (!mounted) return;
    if (!AuthService.instance.isLoggedIn) {
      setState(() {
        _allQuestions = [];
        _localCategories = {};
        _selectedIds.clear();
        _loading = false;
        _error = null;
      });
      // Ekran açıksa kullanıcıyı geri çevir — yetkisiz state'te kalmasın
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
  }

  Future<void> _load() async {
    if (!AuthService.instance.isLoggedIn) {
      // Login değilken çağrılırsa boş listeyle dönelim
      setState(() {
        _allQuestions = [];
        _localCategories = {};
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ClassroomService.instance.listCustomQuestions();
      if (!mounted) return;
      // Mevcut sorulardan kategorileri çıkar — varolan kategoriler eklenir
      for (final q in list) {
        final cat = (q['categoryName'] ?? 'Genel').toString();
        if (cat.isNotEmpty) _localCategories.add(cat);
      }
      setState(() {
        _allQuestions = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Sorular yüklenemedi.';
        _loading = false;
      });
    }
  }

  // ---- KATEGORİ AKSİYONLARI ----

  Future<void> _createCategoryDialog(Color primary) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Kategori'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Kategori adı',
            hintText: 'Örn: Edebiyat — Şiir',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            if (ctrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
          },
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primary, foregroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = ctrl.text.trim();
    if (_localCategories.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" kategorisi zaten var.')),
      );
      return;
    }
    setState(() => _localCategories.add(name));
    // Yeni kategoriye direkt giriş yapalım — kullanıcı soru eklemek isteyebilir
    _openCategory(name);
  }

  Future<void> _deleteCategoryDialog(String category) async {
    final count =
        _allQuestions.where((q) => (q['categoryName'] ?? 'Genel') == category).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"$category" Kategorisini Sil'),
        content: Text(count > 0
            ? 'Bu kategorideki $count soru kalıcı olarak silinecek. Emin misiniz?'
            : 'Bu kategori boş ve tamamen kaldırılacak. Emin misiniz?'),
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
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Kategorideki soruları paralel sil
    final ids = _allQuestions
        .where((q) => (q['categoryName'] ?? 'Genel') == category)
        .map((q) => q['id'] as String)
        .toList();
    for (final id in ids) {
      await ClassroomService.instance.deleteCustomQuestion(id);
      _selectedIds.remove(id);
    }
    setState(() => _localCategories.remove(category));
    await _load();
  }

  // ---- KATEGORİYE GİRİŞ ----

  Future<void> _openCategory(String category) async {
    // Detay ekranına git ve geri dönünce listeyi tazele
    final returned = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _CategoryDetailScreen(
          category: category,
          allQuestions: _allQuestions,
          selectionMode: widget.selectionMode,
          alreadySelected: Set.from(_selectedIds),
        ),
      ),
    );
    // Detay seçim güncellemesini geri al
    if (returned != null) {
      setState(() {
        // Sadece bu kategoriye ait olan ID'leri reset et — diğer kategorilerin
        // seçimini koruyalım
        final catIds = _allQuestions
            .where((q) => (q['categoryName'] ?? 'Genel') == category)
            .map((q) => q['id'] as String)
            .toSet();
        _selectedIds.removeWhere(catIds.contains);
        _selectedIds.addAll(returned);
      });
    }
    await _load();
  }

  // ---- TOPLU SEÇİM ----

  void _toggleAllInCategory(String category) {
    final ids = _allQuestions
        .where((q) => (q['categoryName'] ?? 'Genel') == category)
        .map((q) => q['id'] as String)
        .toList();
    if (ids.isEmpty) return;
    final allSelected = ids.every(_selectedIds.contains);
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  // ---- BUILD ----

  /// Geri çıkışı yönet — selection mode'da seçim varsa kullanıcıyı uyar.
  /// Döner: 'save' kaydet, 'discard' bırak, 'cancel' iptal (kal).
  Future<String> _handleBackInSelectionMode(Color primary) async {
    if (!widget.selectionMode || _selectedIds.isEmpty) return 'discard';
    final res = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Seçimi Sakla?'),
        content: Text(
          '${_selectedIds.length} soru seçtiniz. Bu seçimi nasıl kullanmak istersiniz?',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Geri Dön'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Bırak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Kaydet ve Çık'),
          ),
        ],
      ),
    );
    return res ?? 'cancel';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentAppTheme;
    final primary = theme.primaryColor;

    final categories = _buildCategoryRows();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final action = await _handleBackInSelectionMode(primary);
        if (!context.mounted) return;
        switch (action) {
          case 'save':
            Navigator.pop(context, _selectedIds.toList());
            break;
          case 'discard':
            // Setup ekranı `null` durumunda dokunmuyor — boş liste döndürelim
            // ki seçim açıkça temizlenmiş sayılsın
            Navigator.pop(context, widget.selectionMode ? <String>[] : null);
            break;
          case 'cancel':
          default:
            // Ekranda kal
            break;
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode
            ? 'Soru Bankamdan Seç'
            : 'Soru Bankam'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: theme.appBarGradient),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final action = await _handleBackInSelectionMode(primary);
            if (!context.mounted) return;
            if (action == 'save') {
              Navigator.pop(context, _selectedIds.toList());
            } else if (action == 'discard') {
              Navigator.pop(context, widget.selectionMode ? <String>[] : null);
            }
          },
        ),
        actions: [
          if (widget.selectionMode)
            TextButton(
              onPressed: () => Navigator.pop(context, _selectedIds.toList()),
              child: Text(
                'Bitti (${_selectedIds.length})',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState(primary)
              : categories.isEmpty
                  ? _emptyState(primary)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: categories.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _buildCategoryRow(categories[i], primary),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        onPressed: () => _createCategoryDialog(primary),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Yeni Kategori'),
      ),
    ), // Scaffold
    ); // PopScope
  }

  // Kategori satırlarını hazırla — her kategori için soru sayısı, seçim sayısı
  List<_CategoryRow> _buildCategoryRows() {
    // Tüm bilinen kategoriler: hem soruları olanlar hem boş tanımlananlar
    final all = <String>{..._localCategories};
    for (final q in _allQuestions) {
      final c = (q['categoryName'] ?? 'Genel').toString();
      if (c.isNotEmpty) all.add(c);
    }
    final list = all.toList()..sort();

    return list.map((cat) {
      final qs = _allQuestions
          .where((q) => (q['categoryName'] ?? 'Genel') == cat)
          .toList();
      final selectedHere = qs.where((q) => _selectedIds.contains(q['id'])).length;
      return _CategoryRow(
        name: cat,
        questionCount: qs.length,
        selectedCount: selectedHere,
      );
    }).toList();
  }

  Widget _buildCategoryRow(_CategoryRow row, Color primary) {
    final isAllSelected =
        widget.selectionMode && row.questionCount > 0 && row.selectedCount == row.questionCount;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCategory(row.name),
        onLongPress: widget.selectionMode
            ? null
            : () => _deleteCategoryDialog(row.name),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.folder_rounded, color: primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _badge(
                            '${row.questionCount} soru', Colors.indigo, primary),
                        if (widget.selectionMode && row.selectedCount > 0)
                          _badge('${row.selectedCount} seçili',
                              Colors.green, primary),
                        if (row.questionCount == 0)
                          _badge('Boş', Colors.orange, primary),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.selectionMode && row.questionCount > 0)
                IconButton(
                  tooltip: isAllSelected
                      ? 'Tüm Kategoriyi Bırak'
                      : 'Tüm Kategoriyi Seç',
                  icon: Icon(
                    isAllSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: primary,
                  ),
                  onPressed: () => _toggleAllInCategory(row.name),
                ),
              // Selection mode'da silme yetkisi 3-noktalı menüde
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black54),
                tooltip: 'Kategori işlemleri',
                onSelected: (v) {
                  if (v == 'delete') _deleteCategoryDialog(row.name);
                  if (v == 'open') _openCategory(row.name);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'open',
                    child: Row(children: [
                      Icon(Icons.folder_open, size: 18),
                      SizedBox(width: 8),
                      Text('Aç'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Kategoriyi Sil',
                          style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color base, Color primary) {
    final color = base == Colors.indigo ? primary : base;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _emptyState(Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined,
                size: 80, color: primary.withOpacity(0.35)),
            const SizedBox(height: 16),
            const Text('Henüz kategori yok',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Önce bir kategori oluşturun, sonra içine soru ekleyin.\n'
              'Kategoriler sınavlarınızda hızlı toplu seçim için kullanılır.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primary, foregroundColor: Colors.white),
              onPressed: () => _createCategoryDialog(primary),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('İlk Kategoriyi Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// KATEGORİ DETAY EKRANI
// ===========================================================================
class _CategoryDetailScreen extends StatefulWidget {
  final String category;
  final List<Map<String, dynamic>> allQuestions;
  final bool selectionMode;
  final Set<String> alreadySelected;

  const _CategoryDetailScreen({
    required this.category,
    required this.allQuestions,
    required this.selectionMode,
    required this.alreadySelected,
  });

  @override
  State<_CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<_CategoryDetailScreen> {
  late List<Map<String, dynamic>> _items;
  late Set<String> _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.alreadySelected};
    _refreshItems(widget.allQuestions);
  }

  void _refreshItems(List<Map<String, dynamic>> all) {
    _items = all
        .where((q) => (q['categoryName'] ?? 'Genel') == widget.category)
        .toList();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final all = await ClassroomService.instance.listCustomQuestions();
    if (!mounted) return;
    setState(() {
      _refreshItems(all);
      _loading = false;
    });
  }

  // Detay ekranından geri dönerken seçim setini ana ekrana ilet.
  // Detay ekranında "Kaydet/Bırak" diyaloguna gerek yok — kullanıcı zaten
  // kategoriden ayrılıyor; nihai onay üst (kategori listesi) ekranında.
  void _popWithResult() {
    Navigator.pop(context, _selected);
  }

  /// Selection mode'da bu kategoride yeni seçim varsa kullanıcıya uyar.
  /// Döner: 'save', 'discard', 'cancel'.
  Future<String> _confirmExitInSelectionMode(Color primary) async {
    if (!widget.selectionMode) return 'save';
    final added = _selected.difference(widget.alreadySelected);
    final removed = widget.alreadySelected.difference(_selected);
    if (added.isEmpty && removed.isEmpty) return 'save';
    final res = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Seçimi Sakla?'),
        content: Text(
          'Bu kategoride değişiklik yaptınız: '
          '${added.length} eklendi, ${removed.length} kaldırıldı. '
          'Değişiklikleri saklamak ister misiniz?',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Geri Dön'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Bırak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Sakla'),
          ),
        ],
      ),
    );
    return res ?? 'cancel';
  }

  Future<void> _addQuestion(Color primary) async {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    int difficulty = 2;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Yeni Soru — ${widget.category}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qCtrl,
                  maxLines: 3,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'Soru',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: aCtrl,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Cevap (tek kelime önerilir)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Zorluk:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: difficulty,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Kolay')),
                        DropdownMenuItem(value: 2, child: Text('Orta')),
                        DropdownMenuItem(value: 3, child: Text('Zor')),
                      ],
                      onChanged: (v) => setSt(() => difficulty = v ?? 2),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style:
                  TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primary, foregroundColor: Colors.white),
              onPressed: () async {
                final q = qCtrl.text.trim();
                final a = aCtrl.text.trim();
                if (q.isEmpty || a.replaceAll(' ', '').length < 2) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Soru ve en az 2 harfli cevap girin.')),
                  );
                  return;
                }
                final added =
                    await ClassroomService.instance.addCustomQuestions([
                  {
                    'question': q,
                    'answer': a,
                    'difficulty': difficulty,
                    'categoryName': widget.category,
                  }
                ]);
                if (!ctx.mounted) return;
                if (added.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Soru eklenemedi (zaten kayıtlı olabilir).')),
                  );
                } else {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _reload();
  }

  Future<void> _deleteQuestion(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Soruyu Sil'),
        content:
            const Text('Bu soru kalıcı olarak silinecek. Onaylıyor musunuz?'),
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
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ClassroomService.instance.deleteCustomQuestion(id);
      _selected.remove(id);
      await _reload();
    }
  }

  void _toggleAll() {
    final ids = _items.map((q) => q['id'] as String).toList();
    if (ids.isEmpty) return;
    final allSelected = ids.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentAppTheme;
    final primary = theme.primaryColor;

    final selectedHere = _items.where((q) => _selected.contains(q['id'])).length;
    final allSelected = _items.isNotEmpty && selectedHere == _items.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final action = await _confirmExitInSelectionMode(primary);
        if (!context.mounted) return;
        if (action == 'save') {
          _popWithResult();
        } else if (action == 'discard') {
          // Bu kategoride yapılan değişiklikleri geri al — orijinal seçime dön
          Navigator.pop(context, widget.alreadySelected);
        }
        // 'cancel' → ekranda kal
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.category,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: BoxDecoration(gradient: theme.appBarGradient),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final action = await _confirmExitInSelectionMode(primary);
              if (!context.mounted) return;
              if (action == 'save') {
                _popWithResult();
              } else if (action == 'discard') {
                Navigator.pop(context, widget.alreadySelected);
              }
            },
          ),
          actions: [
            if (widget.selectionMode && _items.isNotEmpty)
              TextButton.icon(
                icon: Icon(
                  allSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: Colors.white,
                ),
                label: Text(
                  allSelected ? 'Tümünü Bırak' : 'Tümünü Seç',
                  style: const TextStyle(color: Colors.white),
                ),
                onPressed: _toggleAll,
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? _emptyCategoryState(primary)
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: primary.withOpacity(0.06),
                        child: Row(
                          children: [
                            Icon(Icons.help_outline, size: 16, color: primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.selectionMode
                                    ? '${_items.length} soru — $selectedHere seçili'
                                    : '${_items.length} soru',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: primary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _reload,
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(12, 8, 12, 88),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) =>
                                _buildItem(_items[i], primary),
                          ),
                        ),
                      ),
                    ],
                  ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          onPressed: () => _addQuestion(primary),
          icon: const Icon(Icons.add),
          label: const Text('Yeni Soru'),
        ),
      ),
    );
  }

  Widget _emptyCategoryState(Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.help_outline, size: 64, color: primary.withOpacity(0.35)),
            const SizedBox(height: 12),
            Text(
              '"${widget.category}" kategorisinde henüz soru yok',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Aşağıdaki butonu kullanarak ilk sorunuzu ekleyin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primary, foregroundColor: Colors.white),
              onPressed: () => _addQuestion(primary),
              icon: const Icon(Icons.add),
              label: const Text('Soru Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> q, Color primary) {
    final id = q['id'] as String;
    final difficulty = (q['difficulty'] ?? 2) as int;
    final diffText = const ['', 'Kolay', 'Orta', 'Zor'][difficulty.clamp(1, 3)];
    final diffColor = const [
      Colors.grey,
      Colors.green,
      Colors.orange,
      Colors.red,
    ][difficulty.clamp(1, 3)];
    final selected = _selected.contains(id);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: selected ? BorderSide(color: primary, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        leading: widget.selectionMode
            ? Checkbox(
                activeColor: primary,
                value: selected,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(id);
                  } else {
                    _selected.remove(id);
                  }
                }),
              )
            : CircleAvatar(
                backgroundColor: diffColor.withOpacity(0.15),
                child: Icon(Icons.help_outline, color: diffColor),
              ),
        title: Text(q['question'] ?? ''),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chip('Cevap: ${q['answer']}', primary),
              _chip(diffText, diffColor),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _deleteQuestion(id),
        ),
        onTap: widget.selectionMode
            ? () => setState(() {
                  if (selected) {
                    _selected.remove(id);
                  } else {
                    _selected.add(id);
                  }
                })
            : null,
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _CategoryRow {
  final String name;
  final int questionCount;
  final int selectedCount;
  _CategoryRow({
    required this.name,
    required this.questionCount,
    required this.selectedCount,
  });
}
