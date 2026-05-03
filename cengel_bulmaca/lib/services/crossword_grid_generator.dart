import 'package:cengel_bulmaca/models/crossword_word.dart';

class CrosswordGridGenerator {
  /// Basit linear layout: kelimeler sırayla açılı konumlandırılır
  /// Across ve Down kelimeleri alternating olarak yerleştir
  static List<CrosswordWord> generateSimpleLayout(
    List<Map<String, String>> wordData, {
    int gridRows = 15,
    int gridCols = 15,
  }) {
    if (wordData.isEmpty) return [];

    final words = <CrosswordWord>[];
    int currentRow = 1;
    int currentCol = 1;
    int number = 1;
    bool useAcross = true;

    for (int i = 0; i < wordData.length; i++) {
      final data = wordData[i];
      final answer = (data['answer'] ?? '').toUpperCase();
      final direction = useAcross ? 'across' : 'down';

      // Sınırları aş sanız, konumları sıfırla ve diğer yöne geç
      if (useAcross && currentCol + answer.length >= gridCols - 1) {
        currentRow += 3;
        currentCol = 1;
      } else if (!useAcross && currentRow + answer.length >= gridRows - 1) {
        currentCol += 5;
        currentRow = 1;
      }

      words.add(CrosswordWord(
        id: data['id'] ?? 'word_$i',
        question: data['question'] ?? '',
        answer: answer,
        row: currentRow,
        col: currentCol,
        direction: direction,
        number: number,
      ));

      // Sonraki kelime için konumu güncelle
      if (useAcross) {
        currentRow += 2; // Satırı kısa atla
      } else {
        currentCol += 3; // Sütunu atla
      }

      useAcross = !useAcross;
      number++;
    }

    return words;
  }

  /// Kesişimli layout: kelimeler arasında harfleri kesiştirir
  static List<CrosswordWord> generateIntersectingLayout(
    List<Map<String, String>> wordData, {
    int gridRows = 16,
    int gridCols = 16,
  }) {
    if (wordData.isEmpty) return [];

    final words = <CrosswordWord>[];
    final occupiedCells = <String, String>{}; // cell -> letter
    int number = 1;

    // İlk kelimeyi ortaya yerleştir (across)
    final firstData = wordData[0];
    final firstAnswer = (firstData['answer'] ?? '').toUpperCase();
    const firstRow = 7;
    final firstCol = (gridCols - firstAnswer.length) ~/ 2;

    words.add(CrosswordWord(
      id: firstData['id'] ?? 'word_0',
      question: firstData['question'] ?? '',
      answer: firstAnswer,
      row: firstRow,
      col: firstCol,
      direction: 'across',
      number: number++,
    ));

    // İlk kelimenin hücrelerini kaydet
    for (int i = 0; i < firstAnswer.length; i++) {
      occupiedCells['${firstRow},${firstCol + i}'] = firstAnswer[i];
    }

    // Diğer kelimeleri yerleştir
    for (int i = 1; i < wordData.length; i++) {
      final data = wordData[i];
      final answer = (data['answer'] ?? '').toUpperCase();
      bool placed = false;

      // Mevcut kelimelerle kesişmeyi dene
      for (final entry in occupiedCells.entries) {
        if (placed) break;

        final cellKey = entry.key;
        final cellLetter = entry.value;
        final parts = cellKey.split(',');
        final refRow = int.parse(parts[0]);
        final refCol = int.parse(parts[1]);

        // Eğer cevapda aynı harf varsa
        for (int letterIdx = 0; letterIdx < answer.length; letterIdx++) {
          if (answer[letterIdx] != cellLetter) continue;

          // Bu harfi kesişme noktası olarak kullan
          final direction =
              words.isEmpty || words.last.direction == 'across'
                  ? 'down'
                  : 'across';

          int newRow, newCol;
          if (direction == 'across') {
            newRow = refRow;
            newCol = refCol - letterIdx;
          } else {
            newRow = refRow - letterIdx;
            newCol = refCol;
          }

          // Grid sınırlarını kontrol et
          if (newRow < 0 || newCol < 0) continue;
          if (direction == 'across' &&
              newCol + answer.length >= gridCols) continue;
          if (direction == 'down' &&
              newRow + answer.length >= gridRows) continue;

          // Çakışma kontrolü
          bool hasConflict = false;
          for (int j = 0; j < answer.length; j++) {
            final checkRow = direction == 'across' ? newRow : newRow + j;
            final checkCol = direction == 'across' ? newCol + j : newCol;
            final key = '$checkRow,$checkCol';

            if (occupiedCells.containsKey(key) &&
                occupiedCells[key] != answer[j]) {
              hasConflict = true;
              break;
            }
          }

          if (hasConflict) continue;

          // Yerleştir
          words.add(CrosswordWord(
            id: data['id'] ?? 'word_$i',
            question: data['question'] ?? '',
            answer: answer,
            row: newRow,
            col: newCol,
            direction: direction,
            number: number++,
          ));

          // Hücreler kaydını güncelle
          for (int j = 0; j < answer.length; j++) {
            final checkRow = direction == 'across' ? newRow : newRow + j;
            final checkCol = direction == 'across' ? newCol + j : newCol;
            occupiedCells['$checkRow,$checkCol'] = answer[j];
          }

          placed = true;
          break;
        }
      }

      if (!placed) {
        print('⚠️ ${data['answer']} kelimesi yerleştirilemedi!');
      }
    }

    return words;
  }
}
