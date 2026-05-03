import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/crossword_category.dart';
import '../models/crossword_clue.dart';
import '../providers/crossword_provider.dart';
import '../providers/theme_provider.dart';
import '../services/dynamic_crossword_generator.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import 'crossword_game_screen.dart';

/// Dil Bilgisi Soruları Ana Ekranı
class GrammarHomeScreen extends StatefulWidget {
  const GrammarHomeScreen({super.key});

  @override
  State<GrammarHomeScreen> createState() => _GrammarHomeScreenState();
}

class _GrammarHomeScreenState extends State<GrammarHomeScreen> {
  final _sound = SoundService.instance;
  List<CrosswordCategory> _categories = [];
  bool _isLoading = true;
  String? _error;
  int _selectedDifficulty = 0;
  int _wordCount = 10;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final String response =
          await rootBundle.loadString('assets/data/grammar_clues.json');
      final data = json.decode(response);

      if (data['categories'] != null) {
        _categories = (data['categories'] as List)
            .map((json) => CrosswordCategory.fromJson(json))
            .toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Dil bilgisi verileri yüklenirken hata: $e';
        _isLoading = false;
      });
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
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = context.watch<ThemeProvider>().currentAppTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dil Bilgisi Soruları',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      _buildSettingsBar(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount;
                              if (MediaQuery.of(context).orientation ==
                                  Orientation.landscape) {
                                crossAxisCount =
                                    (constraints.maxWidth / 150).toInt();
                                crossAxisCount = crossAxisCount.clamp(3, 6);
                              } else {
                                crossAxisCount = 2;
                              }
                              return GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: 1.0,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  return _buildAnimatedCategoryCard(
                                      _categories[index], index);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSettingsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Zorluk',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                        value: 0,
                        label: Text('Hepsi', style: TextStyle(fontSize: 12))),
                    ButtonSegment(
                        value: 1,
                        label: Text('Kolay', style: TextStyle(fontSize: 12))),
                    ButtonSegment(
                        value: 2,
                        label: Text('Orta', style: TextStyle(fontSize: 12))),
                    ButtonSegment(
                        value: 3,
                        label: Text('Zor', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_selectedDifficulty},
                  onSelectionChanged: (Set<int> selection) {
                    setState(() => _selectedDifficulty = selection.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kelime',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              DropdownButton<int>(
                value: _wordCount,
                items: [6, 8, 10, 12, 15]
                    .map((c) => DropdownMenuItem(value: c, child: Text('$c')))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _wordCount = value);
                },
                isDense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCategoryCard(CrosswordCategory category, int index) {
    if (!SettingsService.instance.animationsEnabled) {
      return _buildCategoryCard(category, index);
    }
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
            child: Transform.scale(scale: 0.8 + 0.2 * value, child: child),
          ),
        );
      },
      child: _buildCategoryCard(category, index),
    );
  }

  Widget _buildCategoryCard(CrosswordCategory category, int index) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        List<Color> colorPair;
        if (themeProvider.advancedThemeEnabled) {
          // Gelişmiş tema modunda: temaya uygun renkler
          colorPair = themeProvider.currentAppTheme.getCategoryColors(
            index,
            themeProvider.colorVibrancy,
          );
        } else {
          // Normal mod: önceden tanımlı renkler
          final colors = [
            [Colors.teal.shade600, Colors.teal.shade800],
            [Colors.indigo.shade500, Colors.indigo.shade800],
            [Colors.deepOrange.shade600, Colors.deepOrange.shade800],
            [Colors.purple.shade600, Colors.purple.shade800],
            [Colors.blue.shade600, Colors.blue.shade800],
            [Colors.red.shade600, Colors.red.shade800],
            [Colors.green.shade600, Colors.green.shade800],
          ];
          colorPair = colors[index % colors.length];
        }
        
        final icons = [
          Icons.record_voice_over,
          Icons.construction,
          Icons.abc,
          Icons.short_text,
          Icons.psychology,
          Icons.edit_note,
          Icons.timeline,
        ];
        final icon = icons[index % icons.length];

        int clueCount = _getClueCount(category, _selectedDifficulty);
        bool hasEnough = clueCount >= 3;

        return Card(
          elevation: hasEnough ? 4 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: hasEnough
                ? () {
                    _sound.playCategorySelect();
                    // Eğer hamburger menü açıksa kapat
                    if (Scaffold.of(context).hasEndDrawer) {
                      Navigator.maybePop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _startCategoryGame(category);
                      });
                    } else {
                      _startCategoryGame(category);
                    }
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${category.name} kategorisinde yeterli soru yok.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: hasEnough
                      ? colorPair
                      : [Colors.grey.shade400, Colors.grey.shade600],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: 40,
                        color: Colors.white.withOpacity(hasEnough ? 1.0 : 0.6)),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(hasEnough ? 1.0 : 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasEnough
                            ? Colors.white24
                            : Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasEnough ? '$clueCount soru' : 'Soru yok',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _getClueCount(CrosswordCategory category, int difficulty) {
    switch (difficulty) {
      case 0:
        return category.totalClues;
      case 1:
        return category.easyClues.length;
      case 2:
        return category.mediumClues.length;
      case 3:
        return category.hardClues.length;
      default:
        return category.totalClues;
    }
  }

  Future<void> _startCategoryGame(CrosswordCategory category) async {
    // Zorluk filtrelemesi
    List<CrosswordClue> filteredClues;
    switch (_selectedDifficulty) {
      case 1:
        filteredClues = List.from(category.easyClues);
        break;
      case 2:
        filteredClues = List.from(category.mediumClues);
        break;
      case 3:
        filteredClues = List.from(category.hardClues);
        break;
      default:
        filteredClues = List.from(category.clues);
    }

    if (filteredClues.isEmpty) return;

    filteredClues.shuffle();
    final selectedClues = filteredClues.take(_wordCount + 5).toList();

    final generator = DynamicCrosswordGenerator(
      gridRows: 15,
      gridCols: 15,
    );

    String diffText = ['Karışık', 'Kolay', 'Orta', 'Zor'][_selectedDifficulty];

    final puzzle = generator.generatePuzzle(
      id: 'grammar_${category.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: '${category.name} ($diffText)',
      clues: selectedClues,
      difficulty: _selectedDifficulty,
      maxWords: _wordCount,
      description: 'Dil Bilgisi - ${category.name}',
    );

    if (puzzle.words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bulmaca oluşturulamadı, tekrar deneyin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // CrosswordProvider'a bulmacayı yükle
    if (mounted) {
      final provider = context.read<CrosswordProvider>();
      provider.loadExternalPuzzle(puzzle);
      Navigator.push(context, _buildPageRoute(const CrosswordGameScreen()));
    }
  }
}
