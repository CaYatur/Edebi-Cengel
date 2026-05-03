import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';
import '../services/settings_service.dart';
import 'auth_screen.dart';
import 'multiplayer_room_screen.dart';

/// Çoklu Oyuncu Lobi Ekranı - Oda Oluştur / Katıl
class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen>
    with TickerProviderStateMixin {
  final _roomCodeController = TextEditingController();
  final _sound = SoundService.instance;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  bool _isJoining = false;
  Timer? _publicRoomsTimer;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);

    if (SettingsService.instance.animationsEnabled) {
      _fadeCtrl.forward();
    } else {
      _fadeCtrl.value = 1.0;
    }
    
    // Herkese açık odaları yükle ve sürekli tara
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MultiplayerProvider>().fetchPublicRooms();
    });
    _publicRoomsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<MultiplayerProvider>().fetchPublicRooms();
      }
    });
  }

  @override
  void dispose() {
    _publicRoomsTimer?.cancel();
    _roomCodeController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = context.watch<ThemeProvider>().currentAppTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çoklu Oyuncu', style: TextStyle(fontWeight: FontWeight.bold)),
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
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Başlık ikonu
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: currentTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    size: 56,
                    color: currentTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Arkadaşlarınla Yarış!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: currentTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bir oda oluştur veya mevcut odaya katıl.\nAynı bulmacayı çözün, ilk bitiren kazansın!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // 1) Herkese Açık Odalar (EN ÜSTTE)
                Consumer<MultiplayerProvider>(
                  builder: (context, mp, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.public, color: Colors.green[700], size: 24),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Herkese Açık Odalar',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Yenile butonu
                            IconButton(
                              onPressed: () => mp.fetchPublicRooms(),
                              icon: Icon(Icons.refresh, color: Colors.green[700], size: 20),
                              tooltip: 'Yenile',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (mp.loadingPublicRooms && mp.publicRooms.isEmpty)
                          const Center(child: CircularProgressIndicator())
                        else if (mp.publicRooms.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.search_off, size: 36, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  'Şu an açık oda yok',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Her 5 saniyede otomatik taranıyor',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: mp.publicRooms.length,
                            itemBuilder: (context, index) {
                              final room = mp.publicRooms[index];
                              return _buildPublicRoomTile(room, currentTheme);
                            },
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // 2) Odaya Katıl (ORTADA)
                _buildJoinCard(currentTheme),

                const SizedBox(height: 20),

                // Ayırıcı
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'VEYA',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),

                const SizedBox(height: 20),

                // 3) Oda Oluştur (EN ALTTA)
                _buildActionCard(
                  icon: Icons.add_circle_outline,
                  title: 'Oda Oluştur',
                  description: 'Yeni bir oyun odası oluştur.\nKategori, zorluk ve ayarları sen belirle!',
                  buttonText: 'Oda Oluştur',
                  color: currentTheme.primaryColor,
                  onPressed: _createRoom,
                ),

                const SizedBox(height: 24),

                // Bilgi notu
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Çoklu oyuncuda her oyuncunun sınırlı ipucu hakkı vardır. '
                          'Oda sahibi ipucu sayısını ve diğer ayarları belirleyebilir.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                label: Text(buttonText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinCard(dynamic currentTheme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.login_rounded, size: 48, color: Colors.orange[700]),
            const SizedBox(height: 12),
            Text(
              'Odaya Katıl',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arkadaşının verdiği 4 haneli oda kodunu gir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Kod giriş alanı
            TextField(
              controller: _roomCodeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 16,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                counterText: '',
                hintText: '• • • •',
                hintStyle: TextStyle(
                  fontSize: 32,
                  color: Colors.grey[300],
                  letterSpacing: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isJoining ? null : _joinRoom,
                icon: _isJoining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded, size: 20),
                label: Text(
                  _isJoining ? 'Katılınıyor...' : 'Odaya Katıl',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicRoomTile(Map<String, dynamic> room, dynamic currentTheme) {
    final playersCount = room['playersCount'] as int? ?? 0;
    final maxPlayers = room['maxPlayers'] as int? ?? 8;
    final difficulty = (room['difficulty'] ?? room['settings']?['difficulty'] ?? 0) as int;
    final categoryName = (room['categoryName'] ?? room['settings']?['categoryName'] ?? 'Karışık') as String;
    
    final difficultyText = ['Karışık', 'Kolay', 'Orta', 'Zor'][difficulty.clamp(0, 3)];
    final isFull = playersCount >= maxPlayers;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        enabled: !isFull,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isFull ? Colors.grey[200] : Colors.green[50],
        leading: Icon(
          Icons.videogame_asset,
          color: isFull ? Colors.grey : Colors.green[700],
          size: 24,
        ),
        title: Text(
          room['hostName'] as String? ?? 'Anonim',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isFull ? Colors.grey[600] : Colors.black87,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              categoryName,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                difficultyText,
                style: TextStyle(fontSize: 11, color: Colors.blue[800], fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.people, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 2),
            Text(
              '$playersCount/$maxPlayers',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: isFull
            ? Text('DOLU', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11))
            : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green[700]),
        onTap: isFull ? null : () => _joinPublicRoom((room['code'] ?? room['id'] ?? room['roomCode'] ?? '') as String),
      ),
    );
  }

  void _joinPublicRoom(String roomId) {
    _sound.playButtonClick();

    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oda kodu alınamadı.')),
      );
      return;
    }

    if (!AuthService.instance.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    setState(() => _isJoining = true);

    final provider = context.read<MultiplayerProvider>();
    provider.initialize().then((_) {
      provider.joinRoom(roomId);

      late VoidCallback listener;
      listener = () {
        if (provider.status == RoomStatus.waiting && provider.roomCode != null) {
          provider.removeListener(listener);
          if (mounted) {
            setState(() => _isJoining = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const MultiplayerRoomScreen(),
                ),
              ),
            );
          }
        } else if (provider.errorMessage != null) {
          provider.removeListener(listener);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(provider.errorMessage!)),
            );
            provider.clearError();
            setState(() => _isJoining = false);
          }
        }
      };
      provider.addListener(listener);
    });
  }

  void _createRoom() {
    _sound.playButtonClick();

    // Giriş yapılmamışsa yönlendir
    if (!AuthService.instance.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    final provider = context.read<MultiplayerProvider>();
    provider.initialize().then((_) {
      provider.createRoom();

      // Oda oluşturulunca yönlendir
      late VoidCallback listener;
      listener = () {
        if (provider.status == RoomStatus.waiting && provider.roomCode != null) {
          provider.removeListener(listener);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const MultiplayerRoomScreen(),
                ),
              ),
            );
          }
        } else if (provider.errorMessage != null) {
          provider.removeListener(listener);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(provider.errorMessage!)),
            );
            provider.clearError();
          }
        }
      };
      provider.addListener(listener);
    });
  }

  void _joinRoom() {
    _sound.playButtonClick();

    if (!AuthService.instance.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    final code = _roomCodeController.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen 4 haneli oda kodunu girin.')),
      );
      return;
    }

    setState(() => _isJoining = true);

    final provider = context.read<MultiplayerProvider>();
    provider.initialize().then((_) {
      provider.joinRoom(code);

      late VoidCallback listener;
      listener = () {
        if (provider.status == RoomStatus.waiting && provider.roomCode != null) {
          provider.removeListener(listener);
          setState(() => _isJoining = false);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const MultiplayerRoomScreen(),
                ),
              ),
            );
          }
        } else if (provider.errorMessage != null) {
          provider.removeListener(listener);
          setState(() => _isJoining = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(provider.errorMessage!)),
            );
            provider.clearError();
          }
        }
      };
      provider.addListener(listener);
    });
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Giriş Gerekli'),
        content: const Text(
          'Çoklu oyuncu modunu kullanabilmek için giriş yapmanız gerekiyor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }
}
