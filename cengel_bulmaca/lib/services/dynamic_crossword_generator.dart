import 'dart:math';
import '../models/crossword_clue.dart';
import '../models/crossword_word.dart';
import '../models/crossword_puzzle.dart';

/// Kelime yerleşim bilgisi
class PlacedWord {
  final CrosswordClue clue;
  final int row;
  final int col;
  final String direction; // 'across' veya 'down'
  final int number;

  PlacedWord({
    required this.clue,
    required this.row,
    required this.col,
    required this.direction,
    required this.number,
  });

  String get answer => clue.cleanAnswer;

  List<CellPosition> get cells {
    List<CellPosition> positions = [];
    for (int i = 0; i < answer.length; i++) {
      if (direction == 'across') {
        positions.add(CellPosition(row, col + i));
      } else {
        positions.add(CellPosition(row + i, col));
      }
    }
    return positions;
  }

  CrosswordWord toCrosswordWord() {
    return CrosswordWord(
      id: clue.id,
      question: clue.question,
      answer: answer,
      row: row,
      col: col,
      direction: direction,
      number: number,
    );
  }
}

/// Dinamik çengel bulmaca grid oluşturucu
class DynamicCrosswordGenerator {
  final int gridRows;
  final int gridCols;
  final Random _random;

  // Grid state
  late List<List<String?>> _grid;
  late List<PlacedWord> _placedWords;
  late Set<String> _occupiedCells;

  DynamicCrosswordGenerator({
    this.gridRows = 15,
    this.gridCols = 15,
    int? seed,
  }) : _random = seed != null ? Random(seed) : Random();

  /// Verilen ipuçlarından dinamik çengel bulmaca oluştur
  CrosswordPuzzle generatePuzzle({
    required String id,
    required String title,
    required List<CrosswordClue> clues,
    int difficulty = 1,
    String description = '',
    int maxWords = 12,
  }) {
    print('[Generator] generatePuzzle başladı: $title, ${clues.length} ipucu');
    
    _initializeGrid();
    print('[Generator] Grid initialized: ${gridRows}x${gridCols}');

    // Grid'e sığmayan kelimeleri filtrele
    final filteredClues = clues.where((c) {
      final len = c.answerLength;
      // En azından bir yöne sığmalı
      return len <= gridCols || len <= gridRows;
    }).toList();
    
    print('[Generator] Filtreleme sonrası: ${filteredClues.length} ipucu (${clues.length - filteredClues.length} elendi)');

    // Kelimeleri uzunluğa göre sırala (uzun kelimeler önce)
    final sortedClues = List<CrosswordClue>.from(filteredClues)
      ..sort((a, b) => b.answerLength.compareTo(a.answerLength));
    
    print('[Generator] Sıralanmış ipuçları: ${sortedClues.map((c) => c.cleanAnswer).take(5).toList()}...');

    // Kelimeleri yerleştir
    int wordNumber = 1;
    int attempts = 0;
    const maxAttempts = 100;

    for (var clue in sortedClues) {
      if (_placedWords.length >= maxWords) break;
      if (clue.answerLength < 2) continue;

      bool placed = false;

      if (_placedWords.isEmpty) {
        // İlk kelimeyi ortaya yerleştir
        placed = _placeFirstWord(clue, wordNumber);
      } else {
        // Kesişim noktası bul ve yerleştir
        placed = _placeWordWithIntersection(clue, wordNumber);
      }

      if (placed) {
        wordNumber++;
        attempts = 0;
      } else {
        attempts++;
        if (attempts > maxAttempts) break;
      }
    }

    // Grid'i optimize et (boş alanları temizle)
    final optimizedResult = _optimizeGrid();

    print('[Generator] Yerleştirme tamamlandı: ${_placedWords.length} kelime yerleştirildi');
    
    // Hiç kelime yerleştirilemediyse null döndürmek için kontrol
    if (_placedWords.isEmpty) {
      print('[Generator] UYARI: Hiç kelime yerleştirilemedi!');
      // En az bir kelimeyi zorla yerleştir
      if (sortedClues.isNotEmpty) {
        final firstClue = sortedClues.first;
        print('[Generator] İlk kelime zorla yerleştiriliyor: ${firstClue.cleanAnswer}');
        _placeFirstWord(firstClue, 1);
      }
    }

    // Hala boşsa varsayılan bulmaca döndür
    if (_placedWords.isEmpty) {
      return CrosswordPuzzle(
        id: id,
        title: title,
        difficulty: difficulty,
        description: description,
        gridRows: 10,
        gridCols: 10,
        words: [],
      );
    }

    // CrosswordWord listesini oluştur
    final words = _placedWords
        .map((pw) {
          int newRow = pw.row - optimizedResult.rowOffset;
          int newCol = pw.col - optimizedResult.colOffset;
          
          // Negatif pozisyon kontrolü
          if (newRow < 0 || newCol < 0) {
            print('[Generator] UYARI: Negatif pozisyon! word=${pw.answer}, row=$newRow, col=$newCol');
            newRow = max(0, newRow);
            newCol = max(0, newCol);
          }
          
          return CrosswordWord(
              id: pw.clue.id,
              question: pw.clue.question,
              answer: pw.answer,
              row: newRow,
              col: newCol,
              direction: pw.direction,
              number: pw.number,
            );
        })
        .toList();

    print('[Generator] Words listesi oluşturuldu: ${words.length} kelime');
    print('[Generator] Grid boyutu: ${optimizedResult.rows}x${optimizedResult.cols}');
    
    // Numaraları yeniden sırala (satır ve sütun sırasına göre)
    if (words.isNotEmpty) {
      _renumberWords(words);
    }
    print('[Generator] Numaralama tamamlandı');

    return CrosswordPuzzle(
      id: id,
      title: title,
      difficulty: difficulty,
      description: description,
      gridRows: optimizedResult.rows,
      gridCols: optimizedResult.cols,
      words: words,
    );
  }

  void _initializeGrid() {
    _grid = List.generate(
      gridRows,
      (_) => List.generate(gridCols, (_) => null),
    );
    _placedWords = [];
    _occupiedCells = {};
  }

  bool _placeFirstWord(CrosswordClue clue, int number) {
    final answer = clue.cleanAnswer;
    
    // Kelime grid'e sığıyor mu kontrol et
    if (answer.length > gridCols && answer.length > gridRows) {
      print('[Generator] İlk kelime çok uzun, grid\'e sığmıyor: ${answer.length} > $gridCols/$gridRows');
      return false;
    }
    
    // Yatay mı dikey mi seç - uzun kelimeleri uygun yöne yerleştir
    String direction;
    if (answer.length > gridCols) {
      direction = 'down'; // Yatay sığmıyorsa dikey yerleştir
    } else if (answer.length > gridRows) {
      direction = 'across'; // Dikey sığmıyorsa yatay yerleştir
    } else {
      direction = _random.nextBool() ? 'across' : 'down'; // İkisi de olur, rastgele seç
    }
    
    int row, col;
    
    if (direction == 'across') {
      // Kelime yatay sığmıyorsa başarısız döndür
      if (answer.length > gridCols) {
        print('[Generator] İlk kelime yataya sığmıyor: ${answer.length} > $gridCols');
        return false;
      }
      row = gridRows ~/ 2;
      col = (gridCols - answer.length) ~/ 2;
      // clamp için min değer max değerden büyük olmamalı
      int maxCol = gridCols - answer.length;
      if (maxCol < 0) {
        print('[Generator] İlk kelime için yer yok (yatay)');
        return false;
      }
      col = col.clamp(0, maxCol);
    } else {
      // Kelime dikey sığmıyorsa başarısız döndür
      if (answer.length > gridRows) {
        print('[Generator] İlk kelime dikeye sığmıyor: ${answer.length} > $gridRows');
        return false;
      }
      row = (gridRows - answer.length) ~/ 2;
      col = gridCols ~/ 2;
      // clamp için min değer max değerden büyük olmamalı
      int maxRow = gridRows - answer.length;
      if (maxRow < 0) {
        print('[Generator] İlk kelime için yer yok (dikey)');
        return false;
      }
      row = row.clamp(0, maxRow);
    }

    if (!_canPlaceWord(answer, row, col, direction)) {
      return false;
    }

    _placeWord(clue, row, col, direction, number);
    return true;
  }

  bool _placeWordWithIntersection(CrosswordClue clue, int number) {
    final answer = clue.cleanAnswer;
    
    // Mümkün yerleşimleri bul
    List<_PlacementOption> options = [];

    // Tüm yerleştirilmiş kelimelerle kesişimi dene
    for (var placed in _placedWords) {
      final placedAnswer = placed.answer;
      
      // Zıt yönde yerleştir
      final newDirection = placed.direction == 'across' ? 'down' : 'across';

      for (int i = 0; i < placedAnswer.length; i++) {
        final placedLetter = placedAnswer[i];

        for (int j = 0; j < answer.length; j++) {
          if (answer[j] != placedLetter) continue;

          int newRow, newCol;

          if (newDirection == 'across') {
            // Yatay yerleştir
            newRow = placed.direction == 'across' 
                ? placed.row 
                : placed.row + i;
            newCol = placed.direction == 'across' 
                ? placed.col + i - j 
                : placed.col - j;
          } else {
            // Dikey yerleştir
            newRow = placed.direction == 'across' 
                ? placed.row - j 
                : placed.row + i - j;
            newCol = placed.direction == 'across' 
                ? placed.col + i 
                : placed.col;
          }

          if (_canPlaceWord(answer, newRow, newCol, newDirection)) {
            // Skor hesapla - daha fazla kesişim daha iyi
            int score = _calculatePlacementScore(answer, newRow, newCol, newDirection);
            options.add(_PlacementOption(
              row: newRow,
              col: newCol,
              direction: newDirection,
              score: score,
            ));
          }
        }
      }
    }

    if (options.isEmpty) {
      return false;
    }

    // En iyi yerleşimi seç (biraz rastgelelik ekle)
    options.sort((a, b) => b.score.compareTo(a.score));
    
    // En iyi 3 seçenek arasından rastgele seç
    final topOptions = options.take(3).toList();
    final selected = topOptions[_random.nextInt(topOptions.length)];

    _placeWord(clue, selected.row, selected.col, selected.direction, number);
    return true;
  }

  bool _canPlaceWord(String answer, int row, int col, String direction) {
    // Grid sınırlarını kontrol et
    if (row < 0 || col < 0) return false;
    
    if (direction == 'across') {
      if (col + answer.length > gridCols) return false;
      if (row >= gridRows) return false;
    } else {
      if (row + answer.length > gridRows) return false;
      if (col >= gridCols) return false;
    }

    // Kelime başından önceki hücre boş olmalı
    {
      int prevR = direction == 'across' ? row : row - 1;
      int prevC = direction == 'across' ? col - 1 : col;
      if (_isValidCell(prevR, prevC) && _grid[prevR][prevC] != null) {
        return false;
      }
    }

    // Kelime sonundan sonraki hücre boş olmalı
    {
      int nextR = direction == 'across' ? row : row + answer.length;
      int nextC = direction == 'across' ? col + answer.length : col;
      if (_isValidCell(nextR, nextC) && _grid[nextR][nextC] != null) {
        return false;
      }
    }

    bool hasIntersection = false;

    // Her hücreyi kontrol et
    for (int i = 0; i < answer.length; i++) {
      int r = direction == 'across' ? row : row + i;
      int c = direction == 'across' ? col + i : col;

      String? existingLetter = _grid[r][c];
      
      if (existingLetter != null) {
        // Çakışma kontrolü - harf eşleşmeli
        if (existingLetter != answer[i]) {
          return false;
        }
        // Kesişim var - aynı yönde bir kelimeyle çakışmadığından emin ol
        if (_isSameDirectionWordAt(r, c, direction)) {
          return false; // Aynı yönde başka bir kelime zaten bu hücreyi kullanıyor
        }
        hasIntersection = true;
      } else {
        // Hücre boş - yan hücreleri kontrol et (paralel bitişik kelime olmamalı)
        if (direction == 'across') {
          // Üst hücre dolu mu?
          if (_isValidCell(r - 1, c) && _grid[r - 1][c] != null) {
            return false; // Yatay kelimeye paralel bitişik hücre
          }
          // Alt hücre dolu mu?
          if (_isValidCell(r + 1, c) && _grid[r + 1][c] != null) {
            return false; // Yatay kelimeye paralel bitişik hücre
          }
        } else {
          // Sol hücre dolu mu?
          if (_isValidCell(r, c - 1) && _grid[r][c - 1] != null) {
            return false; // Dikey kelimeye paralel bitişik hücre
          }
          // Sağ hücre dolu mu?
          if (_isValidCell(r, c + 1) && _grid[r][c + 1] != null) {
            return false; // Dikey kelimeye paralel bitişik hücre
          }
        }
      }
    }

    // İlk kelime hariç, en az bir kesişim gerekli
    if (_placedWords.isNotEmpty && !hasIntersection) {
      return false;
    }

    return true;
  }

  /// Belirli bir hücrede belirli yönde bir kelime olup olmadığını kontrol eder
  bool _isSameDirectionWordAt(int row, int col, String direction) {
    for (var placed in _placedWords) {
      if (placed.direction != direction) continue;
      for (var cell in placed.cells) {
        if (cell.row == row && cell.col == col) {
          return true; // Bu hücrede aynı yönde bir kelime var
        }
      }
    }
    return false;
  }

  bool _isValidCell(int row, int col) {
    return row >= 0 && row < gridRows && col >= 0 && col < gridCols;
  }

  int _calculatePlacementScore(String answer, int row, int col, String direction) {
    int score = 0;

    for (int i = 0; i < answer.length; i++) {
      int r = direction == 'across' ? row : row + i;
      int c = direction == 'across' ? col + i : col;

      // Kesişim puanı
      if (_grid[r][c] != null && _grid[r][c] == answer[i]) {
        score += 10;
      }
    }

    // Merkeze yakınlık puanı
    int centerRow = gridRows ~/ 2;
    int centerCol = gridCols ~/ 2;
    int distFromCenter = (row - centerRow).abs() + (col - centerCol).abs();
    score -= distFromCenter;

    return score;
  }

  void _placeWord(CrosswordClue clue, int row, int col, String direction, int number) {
    final answer = clue.cleanAnswer;

    for (int i = 0; i < answer.length; i++) {
      int r = direction == 'across' ? row : row + i;
      int c = direction == 'across' ? col + i : col;
      _grid[r][c] = answer[i];
      _occupiedCells.add('$r,$c');
    }

    _placedWords.add(PlacedWord(
      clue: clue,
      row: row,
      col: col,
      direction: direction,
      number: number,
    ));
  }

  _GridOptimization _optimizeGrid() {
    print('[Generator] _optimizeGrid başladı');
    
    if (_placedWords.isEmpty) {
      print('[Generator] _optimizeGrid: placedWords boş, varsayılan döndürülüyor');
      return _GridOptimization(
        rows: gridRows,
        cols: gridCols,
        rowOffset: 0,
        colOffset: 0,
      );
    }

    int minRow = gridRows;
    int maxRow = 0;
    int minCol = gridCols;
    int maxCol = 0;

    for (var placed in _placedWords) {
      for (var cell in placed.cells) {
        minRow = min(minRow, cell.row);
        maxRow = max(maxRow, cell.row);
        minCol = min(minCol, cell.col);
        maxCol = max(maxCol, cell.col);
      }
    }
    
    print('[Generator] _optimizeGrid: minRow=$minRow, maxRow=$maxRow, minCol=$minCol, maxCol=$maxCol');

    // Kenar boşlukları ekle
    const padding = 1;
    minRow = max(0, minRow - padding);
    minCol = max(0, minCol - padding);
    maxRow = min(gridRows - 1, maxRow + padding);
    maxCol = min(gridCols - 1, maxCol + padding);

    // Minimum grid boyutu kontrolü
    final rows = max(5, maxRow - minRow + 1);
    final cols = max(5, maxCol - minCol + 1);
    
    print('[Generator] _optimizeGrid: rows=$rows, cols=$cols, rowOffset=$minRow, colOffset=$minCol');

    return _GridOptimization(
      rows: rows,
      cols: cols,
      rowOffset: minRow,
      colOffset: minCol,
    );
  }

  void _renumberWords(List<CrosswordWord> words) {
    print('[Generator] _renumberWords başladı: ${words.length} kelime');
    
    if (words.isEmpty) {
      print('[Generator] _renumberWords: Liste boş, atlanıyor');
      return;
    }
    
    try {
      // Pozisyona göre sırala (satır öncelikli, sonra sütun)
      final sortedIndices = List.generate(words.length, (i) => i);
      print('[Generator] sortedIndices oluşturuldu: ${sortedIndices.length} eleman');
      
      sortedIndices.sort((a, b) {
        final wordA = words[a];
        final wordB = words[b];
        int rowCompare = wordA.row.compareTo(wordB.row);
        if (rowCompare != 0) return rowCompare;
        return wordA.col.compareTo(wordB.col);
      });
      print('[Generator] sortedIndices sıralandı');

      // Yeni numaralar ata
      final newNumbers = <int, int>{};
      int number = 1;
      Set<String> assignedPositions = {};

      for (int idx in sortedIndices) {
        final word = words[idx];
        String posKey = '${word.row},${word.col}';

        if (!assignedPositions.contains(posKey)) {
          newNumbers[idx] = number;
          assignedPositions.add(posKey);
          number++;
        } else {
          // Aynı pozisyonda başka kelime var, aynı numarayı kullan
          for (int i = 0; i < words.length; i++) {
            if (words[i].row == word.row && words[i].col == word.col && newNumbers.containsKey(i)) {
              newNumbers[idx] = newNumbers[i]!;
              break;
            }
          }
          // Eğer hala atanmamışsa varsayılan numara ver
          if (!newNumbers.containsKey(idx)) {
            newNumbers[idx] = word.number;
          }
        }
      }
      print('[Generator] newNumbers oluşturuldu: ${newNumbers.length} eleman');

      // Numaraları güncelle
      for (int i = 0; i < words.length; i++) {
        final word = words[i];
        final newNumber = newNumbers[i] ?? word.number;
        words[i] = CrosswordWord(
          id: word.id,
          question: word.question,
          answer: word.answer,
          row: word.row,
          col: word.col,
          direction: word.direction,
          number: newNumber,
        );
      }
      
      print('[Generator] _renumberWords tamamlandı');
    } catch (e, stackTrace) {
      print('[Generator] _renumberWords HATA: $e');
      print('[Generator] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

class _PlacementOption {
  final int row;
  final int col;
  final String direction;
  final int score;

  _PlacementOption({
    required this.row,
    required this.col,
    required this.direction,
    required this.score,
  });
}

class _GridOptimization {
  final int rows;
  final int cols;
  final int rowOffset;
  final int colOffset;

  _GridOptimization({
    required this.rows,
    required this.cols,
    required this.rowOffset,
    required this.colOffset,
  });
}
