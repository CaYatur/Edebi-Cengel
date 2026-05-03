import 'package:flutter/foundation.dart';
import '../models/crossword_puzzle.dart';
import '../models/crossword_word.dart';
import '../models/crossword_category.dart';
import '../models/player_stats.dart';
import '../models/game_badge.dart';
import '../services/crossword_data_service.dart';
import '../services/crossword_category_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';

/// Türkçe karakterleri ASCII karşılıklarına dönüştürür
String normalizeTurkish(String text) {
  String result = text.toUpperCase();
  
  // Türkçe büyük harfler -> ASCII
  result = result.replaceAll('Ğ', 'G');
  result = result.replaceAll('Ü', 'U');
  result = result.replaceAll('Ş', 'S');
  result = result.replaceAll('İ', 'I');
  result = result.replaceAll('Ö', 'O');
  result = result.replaceAll('Ç', 'C');
  
  // Türkçe küçük harfler -> ASCII (eğer toUpperCase çalışmazsa diye)
  result = result.replaceAll('ğ', 'G');
  result = result.replaceAll('ü', 'U');
  result = result.replaceAll('ş', 'S');
  result = result.replaceAll('ı', 'I');
  result = result.replaceAll('ö', 'O');
  result = result.replaceAll('ç', 'C');
  result = result.replaceAll('i', 'I'); // küçük i de büyük I olsun
  
  return result;
}

class CrosswordProvider extends ChangeNotifier {
  final CrosswordDataService _dataService = CrosswordDataService();
  final CrosswordCategoryService _categoryService = CrosswordCategoryService();
  final LocalStorageService _storageService = LocalStorageService.instance;
  
  List<CrosswordPuzzle> _puzzles = [];
  List<CrosswordCategory> _categories = [];
  CrosswordPuzzle? _currentPuzzle;
  CrosswordWord? _selectedWord;
  CellPosition? _selectedCell;
  Map<String, String> _userAnswers = {}; // cellKey -> letter
  Set<String> _completedWordIds = {};
  Set<String> _correctCells = {};
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _currentCategoryId;
  int _lastDifficulty = 0; // Son kullanılan zorluk
  int _lastWordCount = 10; // Son kullanılan kelime sayısı
  int _lastGridSize = 15; // Son kullanılan grid boyutu

  // === Puanlama Sistemi ===
  Set<String> _hintedCells = {}; // İpucu ile açılan hücreler
  int _hintLetterCount = 0; // Tek harf ipucu kullanım sayısı
  int _hintWordCount = 0; // Kelime ipucu kullanım sayısı
  DateTime? _gameStartTime; // Oyun başlangıç zamanı
  bool _gameResultRecorded = false; // Sonuç kaydedildi mi
  String? _lastCompletedWordId; // Son tamamlanan kelime (animasyon için)

  // Getters
  List<CrosswordPuzzle> get puzzles => _puzzles;
  List<CrosswordCategory> get categories => _categories;
  List<CrosswordCategory> get grammarCategories => _categoryService.grammarCategories;
  List<CrosswordCategory> get allCategories => _categoryService.allCategories;
  CrosswordPuzzle? get currentPuzzle => _currentPuzzle;
  CrosswordWord? get selectedWord => _selectedWord;
  CellPosition? get selectedCell => _selectedCell;
  Map<String, String> get userAnswers => _userAnswers;
  Set<String> get completedWordIds => _completedWordIds;
  Set<String> get correctCells => _correctCells;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentCategoryId => _currentCategoryId;
  Set<String> get hintedCells => _hintedCells;
  PlayerStats get playerStats => _storageService.stats;
  bool get gameResultRecorded => _gameResultRecorded;
  String? get lastCompletedWordId => _lastCompletedWordId;
  
  void clearLastCompletedWord() {
    _lastCompletedWordId = null;
  }
  
  bool get isGameCompleted => _currentPuzzle != null && 
      _completedWordIds.length == _currentPuzzle!.words.length;

  String _cellKey(int row, int col) => '$row-$col';

  // Initialization
  Future<void> initialize() async {
    // Zaten initialize edilmişse tekrar yapma
    if (_isInitialized) return;
    
    _setLoading(true);
    try {
      // Yerel depolamayı başlat
      await _storageService.initialize();
      
      // Eski statik bulmacaları yükle
      await _dataService.initialize();
      _puzzles = _dataService.puzzles;
      
      // Yeni kategori sistemini yükle
      await _categoryService.initialize();
      _categories = _categoryService.categories;
      
      _isInitialized = true;
      _setError(null);
      print('Provider initialized: ${_categories.length} kategori, ${_puzzles.length} statik bulmaca');
    } catch (e) {
      _setError('Veriler yüklenirken hata oluştu: $e');
    }
    _setLoading(false);
  }

  // Kategoriden dinamik bulmaca başlat
  Future<void> startGameFromCategory(
    String categoryId, {
    int wordCount = 10,
    int difficulty = 0,
    int gridSize = 15,
  }) async {
    _setLoading(true);
    
    // Son ayarları kaydet
    _lastDifficulty = difficulty;
    _lastWordCount = wordCount;
    _lastGridSize = gridSize;
    
    try {
      // Birkaç deneme yap (farklı seed'lerle)
      CrosswordPuzzle? puzzle;
      int maxRetries = 3;
      int currentDifficulty = difficulty;
      
      // Önce seçilen zorlukta dene
      for (int retry = 0; retry < maxRetries && puzzle == null; retry++) {
        puzzle = _categoryService.generatePuzzleByDifficulty(
          categoryId,
          currentDifficulty,
          wordCount: wordCount,
          gridSize: gridSize,
          seed: retry > 0 ? DateTime.now().millisecondsSinceEpoch + retry : null,
        );
        
        // Eğer çok az kelime varsa tekrar dene
        if (puzzle != null && puzzle.words.length < 3) {
          print('Yetersiz kelime (${puzzle.words.length}), tekrar deneniyor...');
          puzzle = null;
        }
      }
      
      // Seçilen zorlukta bulunamadıysa, diğer zorluklarda dene
      if (puzzle == null && difficulty != 0) {
        print('Seçilen zorlukta ($difficulty) soru bulunamadı, diğer zorluklar deneniyor...');
        List<int> fallbackDifficulties = [0, 1, 2, 3].where((d) => d != difficulty).toList();
        
        for (int fallbackDiff in fallbackDifficulties) {
          puzzle = _categoryService.generatePuzzleByDifficulty(
            categoryId,
            fallbackDiff,
            wordCount: wordCount,
            gridSize: gridSize,
          );
          
          if (puzzle != null && puzzle.words.length >= 3) {
            currentDifficulty = fallbackDiff;
            print('Alternatif zorluk ($fallbackDiff) ile bulmaca oluşturuldu');
            break;
          }
          puzzle = null;
        }
      }

      if (puzzle == null || puzzle.words.isEmpty) {
        _setError('Bu kategori için bulmaca oluşturulamadı. Lütfen başka bir kategori deneyin.');
        _setLoading(false);
        return;
      }

      _currentPuzzle = puzzle;
      _currentCategoryId = categoryId;
      _isAIPuzzle = false;
      _selectedWord = puzzle.words.isNotEmpty ? puzzle.words.first : null;
      _selectedCell = _selectedWord != null 
          ? CellPosition(_selectedWord!.row, _selectedWord!.col) 
          : null;
      _userAnswers.clear();
      _completedWordIds.clear();
      _correctCells.clear();
      _hintedCells.clear();
      _hintLetterCount = 0;
      _hintWordCount = 0;
      _gameStartTime = DateTime.now();
      _gameResultRecorded = false;
      
      _setError(null);
      print('[Provider] Oyun başarıyla başlatıldı: ${puzzle.words.length} kelime');
    } catch (e, stackTrace) {
      print('[Provider] HATA: $e');
      print('[Provider] Stack trace: $stackTrace');
      _setError('Oyun başlatılırken hata oluştu: $e');
    }
    _setLoading(false);
  }

  // Aynı kategoriden yeni bulmaca oluştur (farklı sorularla)
  Future<void> regeneratePuzzle() async {
    if (_currentCategoryId == null) return;
    await startGameFromCategory(
      _currentCategoryId!,
      wordCount: _lastWordCount,
      difficulty: _lastDifficulty,
      gridSize: _lastGridSize,
    );
  }

  // Karışık bulmaca başlat
  Future<void> startMixedGame({
    int wordCount = 12,
    int gridSize = 15,
  }) async {
    _setLoading(true);
    try {
      final puzzle = _categoryService.generateMixedPuzzle(
        wordCount: wordCount,
        gridSize: gridSize,
      );

      if (puzzle == null) {
        _setError('Karışık bulmaca oluşturulamadı.');
        _setLoading(false);
        return;
      }

      _currentPuzzle = puzzle;
      _currentCategoryId = 'mixed';
      _isAIPuzzle = false;
      _selectedWord = puzzle.words.isNotEmpty ? puzzle.words.first : null;
      _selectedCell = _selectedWord != null 
          ? CellPosition(_selectedWord!.row, _selectedWord!.col) 
          : null;
      _userAnswers.clear();
      _completedWordIds.clear();
      _correctCells.clear();
      _hintedCells.clear();
      _hintLetterCount = 0;
      _hintWordCount = 0;
      _gameStartTime = DateTime.now();
      _gameResultRecorded = false;
      
      _setError(null);
    } catch (e) {
      _setError('Oyun başlatılırken hata oluştu: $e');
    }
    _setLoading(false);
  }

  // AI tarafından oluşturulan bulmacayı yükle
  bool _isAIPuzzle = false;
  bool get isAIPuzzle => _isAIPuzzle;

  void loadAIPuzzle(CrosswordPuzzle puzzle) {
    _currentPuzzle = puzzle;
    _currentCategoryId = 'ai_generated';
    _isAIPuzzle = true;
    _selectedWord = puzzle.words.isNotEmpty ? puzzle.words.first : null;
    _selectedCell = _selectedWord != null 
        ? CellPosition(_selectedWord!.row, _selectedWord!.col) 
        : null;
    _userAnswers.clear();
    _completedWordIds.clear();
    _correctCells.clear();
    _hintedCells.clear();
    _hintLetterCount = 0;
    _hintWordCount = 0;
    _gameStartTime = DateTime.now();
    _gameResultRecorded = false;
    _setError(null);
    notifyListeners();
  }

  /// Harici bir bulmacayı yükle (Dil Bilgisi vb.)
  void loadExternalPuzzle(CrosswordPuzzle puzzle) {
    _currentPuzzle = puzzle;
    _currentCategoryId = 'external';
    _isAIPuzzle = false;
    _selectedWord = puzzle.words.isNotEmpty ? puzzle.words.first : null;
    _selectedCell = _selectedWord != null
        ? CellPosition(_selectedWord!.row, _selectedWord!.col)
        : null;
    _userAnswers.clear();
    _completedWordIds.clear();
    _correctCells.clear();
    _hintedCells.clear();
    _hintLetterCount = 0;
    _hintWordCount = 0;
    _gameStartTime = DateTime.now();
    _gameResultRecorded = false;
    _setError(null);
    notifyListeners();
  }

  // Eski statik oyun başlat (geriye uyumluluk)
  Future<void> startNewGame(String puzzleId) async {
    _setLoading(true);
    try {
      final puzzle = _puzzles.firstWhere((p) => p.id == puzzleId);
      _currentPuzzle = puzzle;
      _currentCategoryId = null;
      _selectedWord = puzzle.words.isNotEmpty ? puzzle.words.first : null;
      _selectedCell = _selectedWord != null 
          ? CellPosition(_selectedWord!.row, _selectedWord!.col) 
          : null;
      _userAnswers.clear();
      _completedWordIds.clear();
      _correctCells.clear();
      _hintedCells.clear();
      _hintLetterCount = 0;
      _hintWordCount = 0;
      _gameStartTime = DateTime.now();
      _gameResultRecorded = false;
      
      _setError(null);
    } catch (e) {
      _setError('Oyun başlatılırken hata oluştu: $e');
    }
    _setLoading(false);
  }

  // Hücre seçimi
  void selectCell(int row, int col) {
    if (_currentPuzzle == null) return;
    if (!_currentPuzzle!.isCellActive(row, col)) return;

    List<CrosswordWord> wordsAtCell = _currentPuzzle!.getWordsAt(row, col);
    if (wordsAtCell.isEmpty) return;

    // Aynı hücreye tıklandığında yön değiştir
    if (_selectedCell?.row == row && _selectedCell?.col == col) {
      if (wordsAtCell.length > 1) {
        // Diğer kelimeyi seç
        int currentIndex = wordsAtCell.indexOf(_selectedWord!);
        _selectedWord = wordsAtCell[(currentIndex + 1) % wordsAtCell.length];
      }
    } else {
      _selectedCell = CellPosition(row, col);
      // Mevcut yönde devam et, yoksa ilk kelimeyi seç
      if (_selectedWord != null) {
        var sameDirectionWord = wordsAtCell.firstWhere(
          (w) => w.direction == _selectedWord!.direction,
          orElse: () => wordsAtCell.first,
        );
        _selectedWord = sameDirectionWord;
      } else {
        _selectedWord = wordsAtCell.first;
      }
    }

    notifyListeners();
  }

  // İpucu seçimi
  void selectWord(CrosswordWord word) {
    _selectedWord = word;
    _selectedCell = CellPosition(word.row, word.col);
    notifyListeners();
  }

  // Harf girişi
  void enterLetter(String letter) {
    if (isGameCompleted) return;
    if (_selectedCell == null || _selectedWord == null || _currentPuzzle == null) return;

    String cellKey = _cellKey(_selectedCell!.row, _selectedCell!.col);
    _userAnswers[cellKey] = letter.toUpperCase();

    // Sonraki hücreye git
    _moveToNextCell();
    
    // Kelime tamamlandı mı kontrol et
    _checkWordCompletion();

    notifyListeners();
  }

  // Harf silme
  void deleteLetter() {
    if (isGameCompleted) return;
    if (_selectedCell == null || _selectedWord == null) return;

    String cellKey = _cellKey(_selectedCell!.row, _selectedCell!.col);
    
    if (_userAnswers.containsKey(cellKey) && _userAnswers[cellKey]!.isNotEmpty) {
      _userAnswers[cellKey] = '';
    } else {
      // Önceki hücreye git ve sil
      _moveToPreviousCell();
      if (_selectedCell != null) {
        String prevCellKey = _cellKey(_selectedCell!.row, _selectedCell!.col);
        _userAnswers[prevCellKey] = '';
      }
    }

    // Kelime tamamlanma durumunu kontrol et (harf silindiğinde de)
    _checkWordCompletion();

    notifyListeners();
  }

  void _moveToNextCell() {
    if (_selectedWord == null || _selectedCell == null) return;

    List<CellPosition> cells = _selectedWord!.cells;
    int currentIndex = cells.indexWhere(
      (c) => c.row == _selectedCell!.row && c.col == _selectedCell!.col,
    );

    if (currentIndex >= 0 && currentIndex < cells.length - 1) {
      _selectedCell = cells[currentIndex + 1];
    }
  }

  void _moveToPreviousCell() {
    if (_selectedWord == null || _selectedCell == null) return;

    List<CellPosition> cells = _selectedWord!.cells;
    int currentIndex = cells.indexWhere(
      (c) => c.row == _selectedCell!.row && c.col == _selectedCell!.col,
    );

    if (currentIndex > 0) {
      _selectedCell = cells[currentIndex - 1];
    }
  }

  void _checkWordCompletion() {
    if (_currentPuzzle == null) return;

    for (var word in _currentPuzzle!.words) {
      bool isComplete = true;
      // Cevabı normalize et (Türkçe karakterleri ASCII'ye çevir)
      String cleanAnswer = normalizeTurkish(word.answer.replaceAll(' ', ''));
      
      // Hücre sayısı ve cevap uzunluğu eşleşmeli
      if (word.cells.length != cleanAnswer.length) {
        continue;
      }
      
      for (int i = 0; i < word.cells.length; i++) {
        CellPosition cell = word.cells[i];
        String cellKey = _cellKey(cell.row, cell.col);
        String? userLetter = _userAnswers[cellKey];
        
        if (userLetter == null || userLetter.isEmpty) {
          isComplete = false;
          break;
        }
        
        // Kullanıcının girdiği harfi normalize et
        String normalizedUserLetter = normalizeTurkish(userLetter);
        String expectedLetter = cleanAnswer[i];
        
        if (normalizedUserLetter != expectedLetter) {
          isComplete = false;
          break;
        }
      }

      if (isComplete) {
        // Kelime doğru tamamlandı
        if (!_completedWordIds.contains(word.id)) {
          _completedWordIds.add(word.id);
          _lastCompletedWordId = word.id;
          // Tüm hücreleri doğru olarak işaretle
          for (var cell in word.cells) {
            _correctCells.add(_cellKey(cell.row, cell.col));
          }
        }
      } else {
        // Kelime artık doğru değil, tamamlanmış listesinden çıkar
        if (_completedWordIds.contains(word.id)) {
          _completedWordIds.remove(word.id);
          // Sadece bu kelimeye ait hücreleri kaldır (başka kelime kullanmıyorsa)
          for (var cell in word.cells) {
            String cellKey = _cellKey(cell.row, cell.col);
            // Bu hücreyi kullanan başka tamamlanmış kelime var mı kontrol et
            bool usedByOtherCompleted = _currentPuzzle!.words.any((otherWord) =>
              otherWord.id != word.id &&
              _completedWordIds.contains(otherWord.id) &&
              otherWord.cells.any((c) => c.row == cell.row && c.col == cell.col)
            );
            if (!usedByOtherCompleted) {
              _correctCells.remove(cellKey);
            }
          }
        }
      }
    }
  }

  // Seçili kelimeyi kontrol et
  bool checkSelectedWord() {
    if (_selectedWord == null || _currentPuzzle == null) return false;

    // Cevabı normalize et (Türkçe karakterleri ASCII'ye çevir)
    String cleanAnswer = normalizeTurkish(_selectedWord!.answer.replaceAll(' ', ''));
    bool isCorrect = true;

    for (int i = 0; i < _selectedWord!.cells.length; i++) {
      CellPosition cell = _selectedWord!.cells[i];
      String cellKey = _cellKey(cell.row, cell.col);
      String? userLetter = _userAnswers[cellKey];

      if (userLetter == null || 
          userLetter.isEmpty || 
          normalizeTurkish(userLetter) != cleanAnswer[i]) {
        isCorrect = false;
        break;
      }
    }

    if (isCorrect) {
      _completedWordIds.add(_selectedWord!.id);
      for (var cell in _selectedWord!.cells) {
        _correctCells.add(_cellKey(cell.row, cell.col));
      }
      notifyListeners();
    }

    return isCorrect;
  }

  // İpucu göster (bir harf aç)
  void revealLetter() {
    if (isGameCompleted) return;
    if (_selectedCell == null || _currentPuzzle == null) return;

    String? correctLetter = _currentPuzzle!.getCorrectLetterAt(
      _selectedCell!.row,
      _selectedCell!.col,
    );

    if (correctLetter != null) {
      String cellKey = _cellKey(_selectedCell!.row, _selectedCell!.col);
      if (_correctCells.contains(cellKey)) {
        return; // zaten doğruysa yeni renk geçişi olmasın
      }
      _userAnswers[cellKey] = correctLetter.toUpperCase();
      _hintedCells.add(cellKey); // İpucu ile açılan hücre olarak işaretle
      _hintLetterCount++;
      _moveToNextCell();
      _checkWordCompletion();
      notifyListeners();
    }
  }

  // Seçili kelimeyi tamamen göster
  void revealWord() {
    if (isGameCompleted) return;
    if (_selectedWord == null || _currentPuzzle == null) return;

    String cleanAnswer = _selectedWord!.answer.replaceAll(' ', '').toUpperCase();
    
    for (int i = 0; i < _selectedWord!.cells.length; i++) {
      CellPosition cell = _selectedWord!.cells[i];
      String cellKey = _cellKey(cell.row, cell.col);
      _userAnswers[cellKey] = cleanAnswer[i];
      if (!_correctCells.contains(cellKey)) {
        _hintedCells.add(cellKey); // Tüm hücreleri ipucu olarak işaretle
      }
    }
    _hintWordCount++;

    _completedWordIds.add(_selectedWord!.id);
    for (var cell in _selectedWord!.cells) {
      _correctCells.add(_cellKey(cell.row, cell.col));
    }

    notifyListeners();
  }

  // Oyun istatistiklerini getir
  Map<String, dynamic> getGameStats() {
    if (_currentPuzzle == null) return {};
    
    // Toplam hücre sayısı (tüm kelimelerdeki hücrelerin birleşimi)
    Set<String> allCellKeys = {};
    for (var word in _currentPuzzle!.words) {
      for (var cell in word.cells) {
        allCellKeys.add(_cellKey(cell.row, cell.col));
      }
    }
    int totalCells = allCellKeys.length;
    int hintedCellCount = _hintedCells.length;
    int userFilledCells = totalCells - hintedCellCount;
    if (userFilledCells < 0) userFilledCells = 0;
    
    // Puan: Sadece kullanıcının kendi doldurduğu hücrelerden puan kazanır
    int puzzleScore = userFilledCells;
    int maxPossibleScore = totalCells;
    
    // Süre hesapla
    int durationSeconds = 0;
    if (_gameStartTime != null) {
      durationSeconds = DateTime.now().difference(_gameStartTime!).inSeconds;
    }
    
    return {
      'totalWords': _currentPuzzle!.words.length,
      'completedWords': _completedWordIds.length,
      'completionPercentage': 
          (_completedWordIds.length / _currentPuzzle!.words.length * 100).round(),
      'isCompleted': isGameCompleted,
      'totalCells': totalCells,
      'hintedCells': hintedCellCount,
      'userFilledCells': userFilledCells,
      'puzzleScore': puzzleScore,
      'maxPossibleScore': maxPossibleScore,
      'hintLetterCount': _hintLetterCount,
      'hintWordCount': _hintWordCount,
      'durationSeconds': durationSeconds,
      'totalScore': _storageService.stats.totalScore,
    };
  }

  /// Oyun sonucunu kaydeder ve yeni rozetleri döndürür
  Future<List<GameBadge>> recordGameResult() async {
    if (_currentPuzzle == null || _gameResultRecorded) return [];
    _gameResultRecorded = true;

    final stats = getGameStats();
    final int puzzleScore = stats['puzzleScore'] ?? 0;
    final int maxPossibleScore = stats['maxPossibleScore'] ?? 0;
    final int durationSeconds = stats['durationSeconds'] ?? 0;
    final bool usedAnyHint = _hintedCells.isNotEmpty;

    List<GameBadge> newBadges;

    if (_isAIPuzzle) {
      // AI bulmacası için özel kayıt
      newBadges = await _storageService.recordAIPuzzleResult(
        puzzleScore: puzzleScore,
        maxPossibleScore: maxPossibleScore,
        wordsCompleted: _completedWordIds.length,
        hintsUsed: _hintLetterCount + _hintWordCount,
        lettersRevealed: _hintedCells.length,
        wordsRevealed: _hintWordCount,
        cellsFilledByUser: stats['userFilledCells'] ?? 0,
        durationSeconds: durationSeconds,
        usedAnyHint: usedAnyHint,
      );
    } else {
      // Kaçırılan soruları hesapla (tamamlanmamış kelimeler)
      final List<String> missedClues = _currentPuzzle!.words
          .where((w) => !_completedWordIds.contains(w.id))
          .map((w) => '${w.question}|||${w.answer}')
          .toList();

      newBadges = await _storageService.recordPuzzleResult(
        puzzleScore: puzzleScore,
        maxPossibleScore: maxPossibleScore,
        wordsCompleted: _completedWordIds.length,
        totalWords: _currentPuzzle!.words.length,
        hintsUsed: _hintLetterCount + _hintWordCount,
        lettersRevealed: _hintedCells.length,
        wordsRevealed: _hintWordCount,
        cellsFilledByUser: stats['userFilledCells'] ?? 0,
        durationSeconds: durationSeconds,
        usedAnyHint: usedAnyHint,
        missedClues: missedClues,
        categoryId: _currentCategoryId,
      );
    }

    // Sunucuya senkronize et (giriş yapılmışsa)
    AuthService.instance.syncAfterPuzzle();

    notifyListeners();
    return newBadges;
  }

  // Oyunu sıfırla
  void resetGame() {
    _userAnswers.clear();
    _completedWordIds.clear();
    _correctCells.clear();
    _hintedCells.clear();
    _hintLetterCount = 0;
    _hintWordCount = 0;
    _gameStartTime = DateTime.now();
    _gameResultRecorded = false;
    if (_currentPuzzle != null && _currentPuzzle!.words.isNotEmpty) {
      _selectedWord = _currentPuzzle!.words.first;
      _selectedCell = CellPosition(_selectedWord!.row, _selectedWord!.col);
    }
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
