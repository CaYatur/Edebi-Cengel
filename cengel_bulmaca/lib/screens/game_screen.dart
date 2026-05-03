import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/theme_provider.dart';
import '../models/puzzle_clue.dart';
import '../widgets/clue_widget.dart';
import '../widgets/answer_boxes_widget.dart';
import '../widgets/media_player_widget.dart';
import '../services/sound_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final PageController _pageController = PageController();
  final _sound = SoundService.instance;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final currentTheme = themeProvider.currentAppTheme;
        
        return Scaffold(
          appBar: AppBar(
            title: Consumer<GameProvider>(
              builder: (context, gameProvider, child) {
                final topic = gameProvider.currentTopic;
                return Text(
                  topic?.name ?? 'Çengel Bulmaca',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                );
              },
            ),
            backgroundColor: currentTheme.primaryColor,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: currentTheme.appBarGradient,
              ),
            ),
            actions: [
              Consumer<GameProvider>(
                builder: (context, gameProvider, child) {
                  final stats = gameProvider.getGameStats();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: Text(
                        'Skor: ${stats['score'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
      ),
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, child) {
          if (gameProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (gameProvider.currentQuestions.isEmpty) {
            return const Center(
              child: Text(
                'Oyun verisi bulunamadı',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final currentQuestion = gameProvider.currentQuestion;
          if (currentQuestion == null) {
            return const Center(
              child: Text(
                'Mevcut soru bulunamadı',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return Column(
            children: [
              // Progress Indicator
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          gameProvider.currentTopic?.name ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${gameProvider.currentQuestionIndex + 1} / ${gameProvider.currentQuestions.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: gameProvider.currentQuestions.isNotEmpty 
                          ? (gameProvider.currentQuestionIndex + 1) / gameProvider.currentQuestions.length 
                          : 0.0,
                    ),
                  ],
                ),
              ),
              
              // Main Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: gameProvider.currentQuestions.length,
                  onPageChanged: (index) {
                    // PageView ile manuel gezinme (şimdilik kapalı)
                  },
                  itemBuilder: (context, index) {
                    final question = gameProvider.currentQuestions[index];
                    // Basit zorluk hesaplama: cevap uzunluğuna göre
                    final difficulty = (question.answer.length / 3).ceil().clamp(1, 5);
                    
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Clue Widget - zorluk seviyesi ile
                          ClueWidget(
                            clue: question,
                            difficulty: difficulty,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Media Player (if exists)
                          if (question.mediaPath != null) ...[
                            MediaPlayerWidget(
                              mediaPath: question.mediaPath!,
                              mediaType: question.mediaType ?? 'image',
                            ),
                            const SizedBox(height: 20),
                          ],
                          
                          // Answer Boxes - kalıcı input ile
                          AnswerBoxesWidget(
                            expectedAnswer: question.answer,
                            maskedAnswer: question.maskedAnswer,
                            initialInput: gameProvider.getUserInput(question.id),
                            isAnswered: gameProvider.isQuestionAnswered(question.id),
                            onInputChanged: (input) => gameProvider.saveUserInput(question.id, input),
                            onAnswerSubmitted: (answer) => _handleAnswerComplete(answer, question),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              // Navigation Buttons
              _buildNavigationButtons(),
            ],
          );
        },
      ),
        );
      },
    );
  }

  Widget _buildNavigationButtons() {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous Button
              ElevatedButton.icon(
                onPressed: gameProvider.currentQuestionIndex > 0
                    ? () => _goToPreviousQuestion()
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Önceki'),
              ),
              
              // Question Counter
              Text(
                '${gameProvider.currentQuestionIndex + 1} / ${gameProvider.currentQuestions.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              // Next/Finish Button
              ElevatedButton.icon(
                onPressed: _getNextButtonHandler(),
                icon: Icon(gameProvider.isLastQuestion 
                    ? Icons.check 
                    : Icons.arrow_forward),
                label: Text(gameProvider.isLastQuestion 
                    ? 'Bitir' 
                    : 'Sonraki'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gameProvider.isLastQuestion 
                      ? Colors.green 
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  VoidCallback? _getNextButtonHandler() {
    final gameProvider = context.read<GameProvider>();
    
    if (gameProvider.isLastQuestion) {
      return gameProvider.isGameCompleted ? _completeGame : null;
    } else {
      return _goToNextQuestion;
    }
  }

  void _goToPreviousQuestion() {
    final gameProvider = context.read<GameProvider>();
    gameProvider.previousQuestion();
    
    _pageController.animateToPage(
      gameProvider.currentQuestionIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToNextQuestion() {
    final gameProvider = context.read<GameProvider>();
    gameProvider.nextQuestion();
    
    _pageController.animateToPage(
      gameProvider.currentQuestionIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleAnswerComplete(String answer, PuzzleClue question) {
    final gameProvider = context.read<GameProvider>();
    final isCorrect = gameProvider.checkAnswer(answer);
    
    if (isCorrect) {
      _sound.playSuccess();
      _showCorrectAnswerDialog();
    } else {
      _sound.playError();
      _showIncorrectAnswerDialog();
    }
  }

  void _showCorrectAnswerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                ),
                const SizedBox(width: 12),
                const Text('Doğru!', style: TextStyle(color: Colors.green)),
              ],
            ),
            content: const Text('Tebrikler! Doğru cevabı buldunuz.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  final gameProvider = context.read<GameProvider>();
                  if (!gameProvider.isLastQuestion) {
                    _goToNextQuestion();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Devam Et'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showIncorrectAnswerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.red, size: 32),
                ),
                const SizedBox(width: 12),
                const Text('Yanlış', style: TextStyle(color: Colors.red)),
              ],
            ),
            content: const Text('Bu cevap doğru değil. Tekrar deneyin.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _completeGame() async {
    final gameProvider = context.read<GameProvider>();
    await gameProvider.completeGame();
    
    if (mounted) {
      _sound.playGameComplete();
      _showGameCompletedDialog();
    }
  }

  void _showGameCompletedDialog() {
    final gameProvider = context.read<GameProvider>();
    final stats = gameProvider.getGameStats();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Oyun Tamamlandı!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Toplam Skor: ${stats['score']}'),
              Text('Doğru Cevap: ${stats['answeredQuestions']}/${stats['totalQuestions']}'),
              Text('Başarı Oranı: %${stats['completionPercentage']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                Navigator.of(context).pop(); // GameScreen'den çık
              },
              child: const Text('Ana Menü'),
            ),
          ],
        );
      },
    );
  }
}
