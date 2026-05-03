import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/theme_provider.dart';
import '../models/topic.dart';
import '../services/sound_service.dart';
import '../services/settings_service.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _sound = SoundService.instance;
  late AnimationController _cardAnimCtrl;
  @override
  void initState() {
    super.initState();
    _cardAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    if (SettingsService.instance.animationsEnabled) {
      _cardAnimCtrl.forward();
    } else {
      _cardAnimCtrl.value = 1.0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().initialize();
      _sound.playWelcome();
    });
  }

  @override
  void dispose() {
    _cardAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final currentTheme = themeProvider.currentAppTheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Çengel Bulmaca',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            centerTitle: true,
            backgroundColor: currentTheme.primaryColor,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: currentTheme.appBarGradient,
              ),
            ),
          ),
          body: Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              if (gameProvider.isLoading) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Oyun hazırlanıyor...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              if (gameProvider.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hata!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          gameProvider.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => gameProvider.initialize(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                );
              }

              if (gameProvider.topics.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Henüz konu eklenmemiş',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'İçerik yönetimi aracını kullanarak konular ekleyebilirsiniz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return _buildTopicsList(gameProvider.topics, currentTheme.primaryColor);
            },
          ),
        );
      },
    );
  }

  Widget _buildTopicsList(List<Topic> topics, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Konular',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Oynamak istediğiniz konuyu seçin',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildCategoriesGrid(topics, primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid(List<Topic> topics, Color primaryColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = 1.2;
        final width = constraints.maxWidth;

        if (width > 1200) {
          crossAxisCount = 4;
          childAspectRatio = 1.15;
        } else if (width > 800) {
          crossAxisCount = 3;
          childAspectRatio = 1.18;
        } else if (width > 600) {
          crossAxisCount = 2;
          childAspectRatio = 1.2;
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: topics.length,
          itemBuilder: (context, index) {
            return _buildAnimatedTopicCard(topics[index], index, primaryColor);
          },
        );
      },
    );
  }

  Widget _buildAnimatedTopicCard(Topic topic, int index, Color primaryColor) {
    final delay = index * 80;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Transform.scale(scale: 0.85 + 0.15 * value, child: child),
          ),
        );
      },
      child: _buildTopicCard(topic, primaryColor),
    );
  }

  Widget _buildTopicCard(Topic topic, Color primaryColor) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          _sound.playCategorySelect();
          _startGame(topic);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.7),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    topic.iconPath != null ? Icons.book : Icons.quiz,
                    color: Colors.white,
                    size: 32,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${topic.puzzleSets.length} set',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                topic.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  topic.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              _buildDifficultyIndicator(topic.getAvailableDifficulties()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyIndicator(List<int> difficulties) {
    return Row(
      children: [
        const Icon(
          Icons.speed,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 4),
        ...difficulties.map((difficulty) => Container(
              margin: const EdgeInsets.only(right: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getDifficultyColor(difficulty),
                shape: BoxShape.circle,
              ),
            )),
      ],
    );
  }

  Color _getDifficultyColor(int difficulty) {
    switch (difficulty) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.yellow;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red;
      case 5:
        return Colors.deepOrange;
      default:
        return Colors.white;
    }
  }

  void _startGame(Topic topic) async {
    final gameProvider = context.read<GameProvider>();

    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Oyun başlatılıyor...'),
          ],
        ),
      ),
    );

    try {
      await gameProvider.startNewGame(topic.id);

      if (mounted) {
        Navigator.of(context).pop(); // Loading dialog'u kapat
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const GameScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Loading dialog'u kapat

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Oyun başlatılamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
