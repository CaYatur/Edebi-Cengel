import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/classroom_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../auth_screen.dart';
import 'classroom_setup_screen.dart';
import 'classroom_room_screen.dart';
import 'classroom_archive_screen.dart';
import 'classroom_questions_screen.dart';

/// Sınıf modu giriş ekranı.
/// İki ana eylem: "Sınıfa Katıl" (öğrenci) ve "Sınıf Oluştur (Yönetici)".
/// Her iki tarafın da oturumu zorunludur.
class ClassroomLobbyScreen extends StatefulWidget {
  const ClassroomLobbyScreen({super.key});

  @override
  State<ClassroomLobbyScreen> createState() => _ClassroomLobbyScreenState();
}

class _ClassroomLobbyScreenState extends State<ClassroomLobbyScreen> {
  final _codeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool _ensureLoggedIn() {
    if (AuthService.instance.isLoggedIn) return true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Giriş Gerekli'),
        content: const Text(
          'Sınıf modunu kullanabilmek için hesabınıza giriş yapmanız zorunludur. '
          'Hem öğretmenler hem de öğrenciler giriş yapmalıdır.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    context.read<ThemeProvider>().currentAppTheme.primaryColor,
                foregroundColor: Colors.white),
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
    return false;
  }

  Future<void> _onJoin() async {
    if (!_ensureLoggedIn()) return;
    final code = _codeController.text.trim();
    if (code.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir oda kodu girin (6 hane).')),
      );
      return;
    }
    setState(() => _busy = true);
    final provider = context.read<ClassroomProvider>();
    await provider.initialize();
    final ok = await provider.joinRoom(code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const ClassroomRoomScreen(),
          ),
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
      provider.clearError();
    }
  }

  Future<void> _onCreate() async {
    if (!_ensureLoggedIn()) return;
    final provider = context.read<ClassroomProvider>();
    await provider.initialize();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const ClassroomSetupScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentAppTheme;
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınıf Modu',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: theme.appBarGradient),
        ),
        actions: [
          IconButton(
            tooltip: 'Sınav Arşivim',
            icon: const Icon(Icons.history_edu),
            onPressed: () {
              if (!_ensureLoggedIn()) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ClassroomArchiveScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Soru Bankam',
            icon: const Icon(Icons.library_books),
            onPressed: () {
              if (!_ensureLoggedIn()) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const ClassroomQuestionsScreen(selectionMode: false)),
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
              theme.primaryColor.withOpacity(0.05),
              Colors.white,
              const Color(0xFFEFF6FF),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cast_for_education,
                        size: 64, color: theme.primaryColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sınıf Modu',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Öğretmenler sınıf oluşturur, öğrenciler kodla katılır.\n'
                    'Çoklu oyuncudan farklı: 50 kişiye kadar, oturum zorunlu, sınav odaklı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  if (!AuthService.instance.isLoggedIn)
                    _buildLoginNotice(theme),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildJoinCard(theme)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildCreateCard(theme)),
                      ],
                    )
                  else ...[
                    _buildJoinCard(theme),
                    const SizedBox(height: 16),
                    _buildCreateCard(theme),
                  ],
                  const SizedBox(height: 24),
                  _buildInfoBanner(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginNotice(theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.amber.shade800),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Sınıf modunda hem öğretmenin hem de öğrencinin oturum açması zorunludur. '
              'Devam etmek için giriş yapın.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            child: const Text('Giriş'),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCard(theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.login_rounded,
                    size: 32, color: Colors.indigo.shade600),
                const SizedBox(width: 8),
                const Text('Sınıfa Katıl',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Öğretmeninizin verdiği 6 haneli kodu girin.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '• • • • • •',
                hintStyle: TextStyle(
                  fontSize: 28,
                  color: Colors.grey.shade300,
                  letterSpacing: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _busy ? null : _onJoin,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_forward),
                label: const Text('Katıl',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard(theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.school, size: 32, color: theme.primaryColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Sınıf Oluştur (Yönetici)',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Soruları seç, sınav ayarlarını belirle ve sınıfı yönet. '
              'Sınav sonuçları hesabına otomatik kaydolur.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            _miniBullet(Icons.groups, 'En fazla 50 öğrenci'),
            _miniBullet(Icons.timer, 'Süre, ipucu ve grid ayarları'),
            _miniBullet(Icons.bar_chart, 'Detaylı sınav istatistikleri'),
            _miniBullet(Icons.add_box, 'Kendi sorularını ekle'),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _busy ? null : _onCreate,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Sınıf Oluştur',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBullet(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo.shade400),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sınıf modu çoklu oyuncudan ayrıdır. Herkese açık liste yoktur; '
              'öğrenciler yalnızca öğretmenin paylaştığı kodla katılabilir.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
