import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/theme_provider.dart';
import '../models/crossword_category.dart';
import '../services/crossword_category_service.dart';
import '../services/sound_service.dart';
import 'multiplayer_game_screen.dart';

/// Çoklu Oyuncu Oda Ekranı - Bekleme odası
class MultiplayerRoomScreen extends StatefulWidget {
  const MultiplayerRoomScreen({super.key});

  @override
  State<MultiplayerRoomScreen> createState() => _MultiplayerRoomScreenState();
}

class _MultiplayerRoomScreenState extends State<MultiplayerRoomScreen> {
  final _sound = SoundService.instance;
  final CrosswordCategoryService _categoryService = CrosswordCategoryService();
  bool _gameNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MultiplayerProvider>();
      provider.addListener(_onProviderChanged);
    });
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    await _categoryService.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final provider = context.read<MultiplayerProvider>();

    // Oyun başladığında yönlendir
    if (provider.status == RoomStatus.playing && !_gameNavigated) {
      _gameNavigated = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const MultiplayerGameScreen(),
          ),
        ),
      );
    }

    // Hata mesajı göster
    if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
      provider.clearError();
    }
  }

  @override
  void dispose() {
    try {
      context.read<MultiplayerProvider>().removeListener(_onProviderChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MultiplayerProvider, ThemeProvider>(
      builder: (context, mp, themeProvider, _) {
        final currentTheme = themeProvider.currentAppTheme;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _showLeaveDialog();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                'Oda: ${mp.roomCode ?? '...'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: currentTheme.primaryColor,
              foregroundColor: Colors.white,
              flexibleSpace: Container(
                decoration: BoxDecoration(gradient: currentTheme.appBarGradient),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _showLeaveDialog,
              ),
              actions: [
                // Kodu kopyala
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Oda kodunu kopyala',
                  onPressed: () {
                    if (mp.roomCode != null) {
                      Clipboard.setData(ClipboardData(text: mp.roomCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Oda kodu kopyalandı!')),
                      );
                    }
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
                    currentTheme.primaryColor.withOpacity(0.05),
                    Colors.white,
                    const Color(0xFFFFF8E1),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Oda kodu büyük gösterim
                    _buildRoomCodeBanner(mp, currentTheme),
                    const SizedBox(height: 20),

                    // Oyuncular listesi
                    _buildPlayersSection(mp, currentTheme),
                    const SizedBox(height: 20),

                    // Oda ayarları
                    _buildSettingsSection(mp, currentTheme),
                    const SizedBox(height: 24),

                    // Aksiyon butonları
                    _buildActionButtons(mp, currentTheme),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomCodeBanner(MultiplayerProvider mp, dynamic currentTheme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              currentTheme.primaryColor,
              currentTheme.primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          children: [
            const Text(
              'ODA KODU',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mp.roomCode ?? '----',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu kodu arkadaşlarınla paylaş!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersSection(MultiplayerProvider mp, dynamic currentTheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: currentTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Oyuncular (${mp.players.length}/${mp.settings.maxPlayers})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: currentTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            ...mp.players.map((player) => _buildPlayerTile(player, mp, currentTheme)),
            if (mp.players.length < mp.settings.maxPlayers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey[300]!,
                          style: BorderStyle.solid,
                          width: 2,
                        ),
                      ),
                      child: Icon(Icons.person_add, color: Colors.grey[400], size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Oyuncu bekleniyor...',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
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

  Widget _buildPlayerTile(MultiplayerPlayer player, MultiplayerProvider mp, dynamic currentTheme) {
    final isMe = player.id == mp.playerId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isMe
                  ? currentTheme.primaryColor.withOpacity(0.2)
                  : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                player.displayName.isNotEmpty
                    ? player.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isMe ? currentTheme.primaryColor : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // İsim ve rol
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isMe ? currentTheme.primaryColor : Colors.black87,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(Sen)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
                if (player.isHost)
                  Text(
                    '👑 Oda Sahibi',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // Hazır durumu
          if (!player.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: player.isReady
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: player.isReady ? Colors.green : Colors.orange,
                ),
              ),
              child: Text(
                player.isReady ? 'Hazır ✓' : 'Bekliyor',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: player.isReady ? Colors.green[700] : Colors.orange[700],
                ),
              ),
            ),
          if (player.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber),
              ),
              child: Text(
                'Sahip',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[800],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(MultiplayerProvider mp, dynamic currentTheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: currentTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Oda Ayarları',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: currentTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                if (mp.isHost)
                  TextButton.icon(
                    onPressed: () => _showSettingsDialog(mp),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Düzenle'),
                  ),
              ],
            ),
            const Divider(),
            _buildSettingRow(
              Icons.category,
              'Kategori',
              mp.settings.categoryName,
            ),
            _buildSettingRow(
              Icons.speed,
              'Zorluk',
              _getDifficultyText(mp.settings.difficulty),
            ),
            _buildSettingRow(
              Icons.text_fields,
              'Kelime Sayısı',
              '${mp.settings.wordCount}',
            ),
            _buildSettingRow(
              Icons.lightbulb_outline,
              'İpucu Limiti',
              '${mp.settings.hintLimit} ipucu',
            ),
            _buildSettingRow(
              Icons.timer,
              'Süre Limiti',
              mp.settings.timeLimit > 0
                  ? '${mp.settings.timeLimit ~/ 60} dakika'
                  : 'Sınırsız',
            ),
            _buildSettingRow(
              Icons.people_outline,
              'Maks. Oyuncu',
              '${mp.settings.maxPlayers}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(MultiplayerProvider mp, dynamic currentTheme) {
    if (mp.isHost) {
      final canStart = mp.players.length >= 2 && mp.allPlayersReady;
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: canStart ? _startGame : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text(
                mp.players.length < 2
                    ? 'En Az 2 Kişi Gerekli'
                    : !mp.allPlayersReady
                        ? 'Oyuncular Hazır Değil'
                        : 'Oyunu Başlat!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canStart ? Colors.green[600] : Colors.grey[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            canStart ? 'Tüm oyuncular hazır!' : 'Tüm oyuncuların hazır olmasını bekle',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      );
    } else {
      final me = mp.players.where((p) => p.id == mp.playerId).firstOrNull;
      final amIReady = me?.isReady ?? false;
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () {
            _sound.playButtonClick();
            mp.toggleReady();
          },
          icon: Icon(
            amIReady ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 24,
          ),
          label: Text(
            amIReady ? 'Hazırım ✓' : 'Hazır Ol',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: amIReady ? Colors.green[600] : Colors.orange[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }
  }

  void _startGame() {
    _sound.playButtonClick();
    final mp = context.read<MultiplayerProvider>();
    mp.startGame();
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odadan Ayrıl'),
        content: const Text('Odadan ayrılmak istediğine emin misin?'),
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
            child: const Text('Ayrıl', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(MultiplayerProvider mp) {
    final settings = RoomSettings(
      categoryId: mp.settings.categoryId,
      categoryName: mp.settings.categoryName,
      difficulty: mp.settings.difficulty,
      wordCount: mp.settings.wordCount,
      gridSize: mp.settings.gridSize,
      hintLimit: mp.settings.hintLimit,
      timeLimit: mp.settings.timeLimit,
      maxPlayers: mp.settings.maxPlayers,
      isPublic: mp.settings.isPublic,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RoomSettingsSheet(
        settings: settings,
        categories: _categoryService.categories,
        grammarCategories: _categoryService.grammarCategories,
        onSave: (newSettings) {
          mp.updateSettings(newSettings);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  String _getDifficultyText(int difficulty) {
    switch (difficulty) {
      case 0: return 'Karışık';
      case 1: return 'Kolay';
      case 2: return 'Orta';
      case 3: return 'Zor';
      default: return 'Karışık';
    }
  }
}

/// Oda ayarları bottom sheet
class _RoomSettingsSheet extends StatefulWidget {
  final RoomSettings settings;
  final List<CrosswordCategory> categories;
  final List<CrosswordCategory> grammarCategories;
  final Function(RoomSettings) onSave;

  const _RoomSettingsSheet({
    required this.settings,
    required this.categories,
    required this.grammarCategories,
    required this.onSave,
  });

  @override
  State<_RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends State<_RoomSettingsSheet> {
  late RoomSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                const Icon(Icons.settings, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Oda Ayarları',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Kategori
            const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _settings.categoryId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: 'mixed',
                      child: Text('Karışık (Tüm Kategoriler)'),
                    ),
                    // Edebiyat Dönemleri
                    const DropdownMenuItem(
                      enabled: false,
                      value: '__header_edebiyat__',
                      child: Text('── Edebiyat Dönemleri ──',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              fontSize: 12)),
                    ),
                    ...widget.categories.map((cat) => DropdownMenuItem(
                      value: cat.id,
                      child: Text(cat.name),
                    )),
                    // Dil Bilgisi
                    if (widget.grammarCategories.isNotEmpty) ...[
                      const DropdownMenuItem(
                        enabled: false,
                        value: '__header_grammar__',
                        child: Text('── Dil Bilgisi ──',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 12)),
                      ),
                      ...widget.grammarCategories.map((cat) => DropdownMenuItem(
                        value: cat.id,
                        child: Text('📝 ${cat.name}'),
                      )),
                    ],
                  ],
                  onChanged: (value) {
                    if (value != null && !value.startsWith('__header_')) {
                      setState(() {
                        _settings.categoryId = value;
                        _settings.categoryName = value == 'mixed'
                            ? 'Karışık'
                            : [...widget.categories, ...widget.grammarCategories]
                                .firstWhere((c) => c.id == value)
                                .name;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Herkese Açık
            Row(
              children: [
                const Text('Herkese Açık', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: _settings.isPublic,
                  onChanged: (value) {
                    setState(() => _settings.isPublic = value);
                  },
                ),
              ],
            ),
            if (_settings.isPublic)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Bu oda, lobideki herkese açık listesinde görünecektir.',
                  style: TextStyle(fontSize: 12, color: Colors.green[700], fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 20),

            // Zorluk
            const Text('Zorluk', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Karışık')),
                ButtonSegment(value: 1, label: Text('Kolay')),
                ButtonSegment(value: 2, label: Text('Orta')),
                ButtonSegment(value: 3, label: Text('Zor')),
              ],
              selected: {_settings.difficulty},
              onSelectionChanged: (values) {
                setState(() => _settings.difficulty = values.first);
              },
            ),
            const SizedBox(height: 20),

            // Kelime sayısı
            Row(
              children: [
                const Text('Kelime Sayısı', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_settings.wordCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            Slider(
              value: _settings.wordCount.toDouble(),
              min: 5,
              max: 20,
              divisions: 15,
              label: '${_settings.wordCount}',
              onChanged: (v) => setState(() => _settings.wordCount = v.round()),
            ),

            // İpucu limiti
            Row(
              children: [
                const Text('İpucu Limiti', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_settings.hintLimit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            Slider(
              value: _settings.hintLimit.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              label: '${_settings.hintLimit}',
              onChanged: (v) => setState(() => _settings.hintLimit = v.round()),
            ),

            // Süre limiti
            Row(
              children: [
                const Text('Süre Limiti', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  _settings.timeLimit > 0
                      ? '${_settings.timeLimit ~/ 60} dk'
                      : 'Sınırsız',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            Slider(
              value: _settings.timeLimit.toDouble(),
              min: 0,
              max: 1800, // 30 dakika
              divisions: 6,
              label: _settings.timeLimit > 0
                  ? '${_settings.timeLimit ~/ 60} dk'
                  : 'Sınırsız',
              onChanged: (v) => setState(() => _settings.timeLimit = v.round()),
            ),

            // Maks oyuncu
            Row(
              children: [
                const Text('Maks. Oyuncu', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_settings.maxPlayers}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            Slider(
              value: _settings.maxPlayers.toDouble(),
              min: 2,
              max: 10,
              divisions: 8,
              label: '${_settings.maxPlayers}',
              onChanged: (v) => setState(() => _settings.maxPlayers = v.round()),
            ),

            const SizedBox(height: 16),

            // Kaydet butonu
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => widget.onSave(_settings),
                child: const Text('Ayarları Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
