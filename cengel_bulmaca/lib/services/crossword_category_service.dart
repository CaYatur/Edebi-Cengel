import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/crossword_category.dart';
import '../models/crossword_clue.dart';
import '../models/crossword_puzzle.dart';
import 'dynamic_crossword_generator.dart';

/// Çengel bulmaca veri servisi - kategoriler ve dinamik bulmaca oluşturma
class CrosswordCategoryService {
  List<CrosswordCategory> _categories = [];
  List<CrosswordCategory> _grammarCategories = [];
  bool _isInitialized = false;

  List<CrosswordCategory> get categories => _categories;
  List<CrosswordCategory> get grammarCategories => _grammarCategories;
  /// Tüm kategoriler (edebiyat + dil bilgisi)
  List<CrosswordCategory> get allCategories => [..._categories, ..._grammarCategories];
  bool get isInitialized => _isInitialized;

  /// Servisi başlat - kategorileri yükle
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final String response =
          await rootBundle.loadString('assets/data/crossword_clues.json');
      final data = json.decode(response);

      if (data['categories'] != null) {
        _categories = (data['categories'] as List)
            .map((json) => CrosswordCategory.fromJson(json))
            .toList();
      }

      // Dil bilgisi kategorilerini de yükle
      try {
        final String grammarResponse =
            await rootBundle.loadString('assets/data/grammar_clues.json');
        final grammarData = json.decode(grammarResponse);

        if (grammarData['categories'] != null) {
          _grammarCategories = (grammarData['categories'] as List)
              .map((json) => CrosswordCategory.fromJson(json))
              .toList();
        }
        print('CrosswordCategoryService: ${_grammarCategories.length} dil bilgisi kategorisi yüklendi');
      } catch (e) {
        print('Dil bilgisi kategorileri yüklenemedi: $e');
        _grammarCategories = [];
      }

      _isInitialized = true;
      print('CrosswordCategoryService: ${_categories.length} kategori yüklendi');
    } catch (e) {
      print('CrosswordCategoryService initialize error: $e');
      _categories = [];
      _isInitialized = true; // Hata olsa bile başlatılmış say
    }
  }

  /// Kategori ID'sine göre kategori getir (edebiyat + dil bilgisi)
  CrosswordCategory? getCategoryById(String id) {
    try {
      return allCategories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Kategoriden dinamik çengel bulmaca oluştur
  /// Her çağrıda farklı bir bulmaca oluşturur
  CrosswordPuzzle? generatePuzzleFromCategory(
    String categoryId, {
    int wordCount = 10,
    int gridSize = 15,
    int? seed,
  }) {
    final category = getCategoryById(categoryId);
    if (category == null || category.clues.isEmpty) {
      print('Kategori bulunamadı veya boş: $categoryId');
      return null;
    }

    // Rastgele soruları seç
    final selectedClues = category.getRandomClues(
      wordCount + 5, // Fazladan seç, bazıları yerleşmeyebilir
      seed: seed,
    );

    if (selectedClues.isEmpty) {
      print('Seçilen soru yok: $categoryId');
      return null;
    }

    // Dinamik bulmaca oluştur
    final generator = DynamicCrosswordGenerator(
      gridRows: gridSize,
      gridCols: gridSize,
      seed: seed,
    );

    final puzzle = generator.generatePuzzle(
      id: '${categoryId}_${DateTime.now().millisecondsSinceEpoch}',
      title: category.name,
      clues: selectedClues,
      maxWords: wordCount,
      description: '${category.name} kategorisinden dinamik bulmaca',
    );

    print('Bulmaca oluşturuldu: ${puzzle.words.length} kelime');
    return puzzle;
  }

  /// Kategoriden zorluk seviyesine göre bulmaca oluştur
  /// difficulty: 0=Karışık, 1=Kolay, 2=Orta, 3=Zor
  CrosswordPuzzle? generatePuzzleByDifficulty(
    String categoryId,
    int difficulty, {
    int wordCount = 10,
    int gridSize = 15,
    int? seed,
  }) {
    final category = getCategoryById(categoryId);
    if (category == null) return null;

    // Zorluk seviyesine göre soruları filtrele
    List<CrosswordClue> filteredClues;
    String diffText;
    
    switch (difficulty) {
      case 0: // Karışık - tüm sorular
        filteredClues = List.from(category.clues);
        diffText = 'Karışık';
        break;
      case 1: // Kolay - SADECE kolay sorular
        filteredClues = List.from(category.easyClues);
        diffText = 'Kolay';
        break;
      case 2: // Orta - SADECE orta sorular
        filteredClues = List.from(category.mediumClues);
        diffText = 'Orta';
        break;
      case 3: // Zor - SADECE zor sorular
        filteredClues = List.from(category.hardClues);
        diffText = 'Zor';
        break;
      default:
        filteredClues = List.from(category.clues);
        diffText = 'Karışık';
    }

    // Yeterli soru yoksa null döndür
    if (filteredClues.isEmpty) {
      print('UYARI: $categoryId kategorisinde $diffText zorlukta soru yok');
      return null;
    }

    // Rastgele karıştır
    final random = seed != null ? Random(seed) : Random();
    filteredClues.shuffle(random);

    // Seçilen soruları al (olduğu kadar)
    final actualWordCount = filteredClues.length < wordCount ? filteredClues.length : wordCount;
    final selectedClues = filteredClues.take(actualWordCount + 5).toList();

    final generator = DynamicCrosswordGenerator(
      gridRows: gridSize,
      gridCols: gridSize,
      seed: seed,
    );

    final puzzle = generator.generatePuzzle(
      id: '${categoryId}_d${difficulty}_${DateTime.now().millisecondsSinceEpoch}',
      title: '${category.name} ($diffText)',
      clues: selectedClues,
      difficulty: difficulty,
      maxWords: actualWordCount,
      description: '${category.name} - $diffText seviye',
    );

    // Bulmaca boşsa null döndür
    if (puzzle.words.isEmpty) {
      print('UYARI: Bulmaca oluşturulamadı - kelime yerleştirilemedi');
      return null;
    }

    return puzzle;
  }

  String _difficultyText(int difficulty) {
    switch (difficulty) {
      case 0:
        return 'Karışık';
      case 1:
        return 'Kolay';
      case 2:
        return 'Orta';
      case 3:
        return 'Zor';
      default:
        return 'Karışık';
    }
  }

  /// Belirli bir kategoride belirli zorlukta kaç soru var
  int getClueCountByDifficulty(String categoryId, int difficulty) {
    final category = getCategoryById(categoryId);
    if (category == null) return 0;
    
    switch (difficulty) {
      case 0: return category.clues.length;
      case 1: return category.easyClues.length;
      case 2: return category.mediumClues.length;
      case 3: return category.hardClues.length;
      default: return category.clues.length;
    }
  }

  /// Tüm kategorilerden karma bulmaca oluştur
  CrosswordPuzzle? generateMixedPuzzle({
    int wordCount = 12,
    int gridSize = 15,
    int? seed,
  }) {
    if (_categories.isEmpty) return null;

    final random = seed != null ? Random(seed) : Random();
    final allClues = <CrosswordClue>[];

    // Her kategoriden rastgele sorular al
    for (var category in _categories) {
      final categoryClues = category.getRandomClues(3, seed: random.nextInt(10000));
      allClues.addAll(categoryClues);
    }

    if (allClues.isEmpty) return null;

    allClues.shuffle(random);
    final selectedClues = allClues.take(wordCount + 5).toList();

    final generator = DynamicCrosswordGenerator(
      gridRows: gridSize,
      gridCols: gridSize,
      seed: seed,
    );

    return generator.generatePuzzle(
      id: 'mixed_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Karışık Bulmaca',
      clues: selectedClues,
      maxWords: wordCount,
      description: 'Tüm kategorilerden seçilmiş sorular',
    );
  }

  /// İstatistikler
  int get totalCategories => _categories.length;
  
  int get totalClues => _categories.fold(0, (sum, c) => sum + c.totalClues);

  Map<String, int> get categoryStats {
    return Map.fromEntries(
      _categories.map((c) => MapEntry(c.name, c.totalClues)),
    );
  }
}
