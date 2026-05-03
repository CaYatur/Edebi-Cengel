import 'package:json_annotation/json_annotation.dart';
import 'crossword_word.dart';

part 'crossword_puzzle.g.dart';

@JsonSerializable()
class CrosswordPuzzle {
  final String id;
  final String title;
  final int difficulty;
  final String description;
  final int gridRows;
  final int gridCols;
  final List<CrosswordWord> words;

  CrosswordPuzzle({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.description,
    required this.gridRows,
    required this.gridCols,
    required this.words,
  });

  factory CrosswordPuzzle.fromJson(Map<String, dynamic> json) =>
      _$CrosswordPuzzleFromJson(json);

  Map<String, dynamic> toJson() => _$CrosswordPuzzleToJson(this);

  // Yatay kelimeler
  List<CrosswordWord> get acrossWords =>
      words.where((w) => w.isAcross).toList()..sort((a, b) => a.number.compareTo(b.number));

  // Dikey kelimeler
  List<CrosswordWord> get downWords =>
      words.where((w) => w.isDown).toList()..sort((a, b) => a.number.compareTo(b.number));

  // Belirli bir hücrede kelime numarası var mı?
  int? getNumberAt(int row, int col) {
    for (var word in words) {
      if (word.row == row && word.col == col) {
        return word.number;
      }
    }
    return null;
  }

  // Belirli bir hücrede hangi kelimeler var?
  List<CrosswordWord> getWordsAt(int row, int col) {
    return words.where((w) => w.containsCell(row, col)).toList();
  }

  // Belirli bir hücre bulmacada mı?
  bool isCellActive(int row, int col) {
    return words.any((w) => w.containsCell(row, col));
  }

  // Doğru harfi getir
  String? getCorrectLetterAt(int row, int col) {
    for (var word in words) {
      String? letter = word.letterAt(row, col);
      if (letter != null) return letter;
    }
    return null;
  }

  // Grid'i oluştur
  List<List<String?>> generateGrid() {
    List<List<String?>> grid = List.generate(
      gridRows,
      (_) => List.generate(gridCols, (_) => null),
    );

    for (var word in words) {
      String cleanAnswer = word.answer.replaceAll(' ', '');
      for (int i = 0; i < cleanAnswer.length; i++) {
        int r = word.isAcross ? word.row : word.row + i;
        int c = word.isAcross ? word.col + i : word.col;
        
        if (r < gridRows && c < gridCols) {
          grid[r][c] = cleanAnswer[i];
        }
      }
    }

    return grid;
  }
}
