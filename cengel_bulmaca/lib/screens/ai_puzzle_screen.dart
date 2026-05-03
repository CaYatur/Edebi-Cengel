import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crossword_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';
import '../services/settings_service.dart';
import '../models/crossword_puzzle.dart';
import '../models/crossword_word.dart';
import 'crossword_game_screen.dart';

/// Yapay zeka ile bulmaca oluşturma ekranı
class AIPuzzleScreen extends StatefulWidget {
  const AIPuzzleScreen({super.key});

  @override
  State<AIPuzzleScreen> createState() => _AIPuzzleScreenState();
}

class _AIPuzzleScreenState extends State<AIPuzzleScreen>
    with TickerProviderStateMixin {
  final _topicController = TextEditingController();
  final _sound = SoundService.instance;
  
  String _selectedMode = 'free'; // 'free', 'topic', 'select'
  String? _selectedTopic;
  bool _isGenerating = false;
  String? _errorMessage;
  bool _canGenerate = true;
  int _remainingSeconds = 0;

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // Türk Edebiyatı konuları (TYT-AYT hazırlık)
  static const List<Map<String, String>> _topicOptions = [
    {'name': 'Türk Edebiyatı', 'icon': '📚'},
    {'name': 'Şairler ve Yazarlar', 'icon': '✒️'},
    {'name': 'Cumhuriyet Dönemi', 'icon': '🇹🇷'},
    {'name': 'Osmanlı Edebiyatı', 'icon': '👑'},
    {'name': 'Romanlar ve Hikayeler', 'icon': '📖'},
    {'name': 'Türk Şiiri', 'icon': '📝'},
    {'name': 'Tiyatro', 'icon': '🎭'},
    {'name': 'Söz Sanatları', 'icon': '✨'},
    {'name': 'Halk Edebiyatı', 'icon': '🎪'},
  ];

  @override
  void initState() {
    super.initState();
    final animEnabled = SettingsService.instance.animationsEnabled;

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    if (animEnabled) {
      _fadeController.forward();
    } else {
      _fadeController.value = 1.0;
    }

    _checkRateLimit();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkRateLimit() async {
    final response = await ApiService.instance.checkAIRateLimit();
    if (response.isSuccess && response.data != null) {
      setState(() {
        _canGenerate = response.data!['canGenerate'] ?? true;
        _remainingSeconds = response.data!['remainingSeconds'] ?? 0;
      });
      if (!_canGenerate && _remainingSeconds > 0) {
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _canGenerate = true;
          _remainingSeconds = 0;
        }
      });
      if (_remainingSeconds > 0) {
        _startCountdown();
      }
    });
  }

  Future<void> _generatePuzzle() async {
    if (_isGenerating || !_canGenerate) return;

    final auth = AuthService.instance;
    if (!auth.isLoggedIn) {
      setState(() {
        _errorMessage = 'Bu özelliği kullanmak için giriş yapmanız gerekiyor.';
      });
      return;
    }

    String? topic;
    String mode = _selectedMode;

    if (_selectedMode == 'topic') {
      topic = _topicController.text.trim();
      if (topic.isEmpty) {
        setState(() {
          _errorMessage = 'Lütfen bir konu yazın.';
        });
        return;
      }
    } else if (_selectedMode == 'select') {
      topic = _selectedTopic;
      if (topic == null || topic.isEmpty) {
        setState(() {
          _errorMessage = 'Lütfen bir konu seçin.';
        });
        return;
      }
      mode = 'topic'; // Sunucuya topic olarak gönder
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    _sound.playButtonClick();

    if (SettingsService.instance.animationsEnabled) {
      _pulseController.repeat(reverse: true);
    }

    try {
      final response = await ApiService.instance.generateAIPuzzle(
        topic: topic,
        mode: mode,
      );

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final puzzleData = response.data!['puzzle'];
        if (puzzleData != null) {
          // Puzzle'ı CrosswordPuzzle'a dönüştür
          final puzzle = _parsePuzzleFromServer(puzzleData);

          if (puzzle != null && puzzle.words.isNotEmpty) {
            _sound.playWelcome();

            // CrosswordProvider'a yükle ve oyun ekranına git
            if (mounted) {
              final provider = context.read<CrosswordProvider>();
              provider.loadAIPuzzle(puzzle);

              Navigator.pushReplacement(
                context,
                _buildPageRoute(const CrosswordGameScreen()),
              );
            }
          } else {
            setState(() {
              _errorMessage = 'Bulmaca oluşturulamadı. Tekrar deneyin.';
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = response.errorMessage ?? 'Bir hata oluştu.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Bağlantı hatası: $e';
      });
    } finally {
      if (mounted) {
        _pulseController.stop();
        _pulseController.reset();
        setState(() {
          _isGenerating = false;
        });
        _checkRateLimit();
      }
    }
  }

  CrosswordPuzzle? _parsePuzzleFromServer(Map<String, dynamic> data) {
    try {
      final words = (data['words'] as List).map((w) {
        return CrosswordWord(
          id: w['id'] ?? '',
          question: w['question'] ?? '',
          answer: (w['answer'] ?? '').toString().toUpperCase(),
          row: w['row'] ?? 0,
          col: w['col'] ?? 0,
          direction: w['direction'] ?? 'across',
          number: w['number'] ?? 0,
        );
      }).toList();

      return CrosswordPuzzle(
        id: data['id'] ?? 'ai_puzzle',
        title: data['title'] ?? 'AI Bulmaca',
        difficulty: data['difficulty'] ?? 2,
        description: data['description'] ?? '',
        gridRows: data['gridRows'] ?? 15,
        gridCols: data['gridCols'] ?? 15,
        words: words,
      );
    } catch (e) {
      print('AI Puzzle parse hatası: $e');
      return null;
    }
  }

  Route _buildPageRoute(Widget page) {
    if (!SettingsService.instance.animationsEnabled) {
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final currentTheme = themeProvider.currentAppTheme;

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy, size: 28),
                SizedBox(width: 8),
                Text(
                  'AI Bulmaca',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            centerTitle: true,
            backgroundColor: currentTheme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: currentTheme.appBarGradient,
              ),
            ),
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: !auth.isLoggedIn
                ? _buildLoginRequired(currentTheme)
                : _isGenerating
                    ? _buildGeneratingState(currentTheme)
                    : _buildCreationForm(currentTheme),
          ),
        );
      },
    );
  }

  Widget _buildLoginRequired(dynamic currentTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: currentTheme.primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Giriş Gerekli',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: currentTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Yapay zeka ile bulmaca oluşturmak için\nhesabınıza giriş yapmanız gerekmektedir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Geri Dön'),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingState(dynamic currentTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      currentTheme.primaryColor.withOpacity(0.2),
                      currentTheme.primaryColor.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: currentTheme.primaryColor.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.smart_toy,
                  size: 60,
                  color: currentTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Bulmaca Oluşturuluyor...',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: currentTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Yapay zeka sizin için özel bir bulmaca hazırlıyor.\nBu işlem birkaç saniye sürebilir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: currentTheme.primaryColor.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  currentTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreationForm(dynamic currentTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  currentTheme.primaryColor.withOpacity(0.1),
                  currentTheme.primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: currentTheme.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: currentTheme.primaryColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'Yapay Zeka ile Bulmaca Oluştur',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: currentTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'AI, sizin için 5 soruluk bir çengel bulmaca oluşturacak.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Mod Seçimi
          Text(
            'Nasıl oluşturulsun?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: currentTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),

          // Yapay zekaya bırak
          _buildModeCard(
            currentTheme: currentTheme,
            mode: 'free',
            icon: Icons.auto_fix_high,
            title: 'Yapay Zekaya Bırak',
            subtitle: 'AI serbest konuda ilgi çekici bir bulmaca oluşturur',
          ),
          const SizedBox(height: 10),

          // Konu yaz
          _buildModeCard(
            currentTheme: currentTheme,
            mode: 'topic',
            icon: Icons.edit,
            title: 'Konu Yaz',
            subtitle: 'İstediğin konuyu yaz, AI o konuda bulmaca oluştursun',
          ),
          const SizedBox(height: 10),

          // Konu seç
          _buildModeCard(
            currentTheme: currentTheme,
            mode: 'select',
            icon: Icons.category,
            title: 'Konu Seç',
            subtitle: 'Hazır konulardan birini seç',
          ),

          // Konu yazma alanı
          if (_selectedMode == 'topic') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: 'Konu',
                hintText: 'Örn: Osmanlı Tarihi, Uzay, Hayvanlar...',
                prefixIcon: const Icon(Icons.topic),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: currentTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 50,
            ),
          ],

          // Konu seçme listesi
          if (_selectedMode == 'select') ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _topicOptions.map((option) {
                final isSelected = _selectedTopic == option['name'];
                return FilterChip(
                  label: Text('${option['icon']} ${option['name']}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTopic = selected ? option['name'] : null;
                    });
                    _sound.playButtonClick();
                  },
                  selectedColor: currentTheme.primaryColor.withOpacity(0.2),
                  checkmarkColor: currentTheme.primaryColor,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? currentTheme.primaryColor : null,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? currentTheme.primaryColor
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Hata mesajı
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Rate limit uyarısı
          if (!_canGenerate && _remainingSeconds > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Sonraki oluşturma: $_remainingSeconds saniye',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Oluştur butonu
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _canGenerate ? _generatePuzzle : null,
              icon: Icon(
                _canGenerate ? Icons.smart_toy : Icons.timer,
                size: 24,
              ),
              label: Text(
                _canGenerate
                    ? 'Bulmaca Oluştur'
                    : '$_remainingSeconds sn bekleyin',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: _canGenerate ? 4 : 0,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bilgi notu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.blue[400],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Her 1 dakikada bir bulmaca oluşturabilirsiniz. '
                    'AI bulmacaları çözerek özel rozetler kazanabilirsiniz!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required dynamic currentTheme,
    required String mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _errorMessage = null;
        });
        _sound.playButtonClick();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? currentTheme.primaryColor
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? currentTheme.primaryColor.withOpacity(0.05)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? currentTheme.primaryColor.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? currentTheme.primaryColor
                    : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? currentTheme.primaryColor
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: currentTheme.primaryColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
