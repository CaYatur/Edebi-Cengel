import 'package:json_annotation/json_annotation.dart';

part 'crossword_word.g.dart';

enum WordDirection { across, down }

@JsonSerializable()
class CrosswordWord {
  final String id;
  final String question;
  final String answer;
  final int row; // Başlangıç satırı (0-indexed)
  final int col; // Başlangıç sütunu (0-indexed)
  final String direction; // 'across' veya 'down'
  final int number; // Bulmacadaki numara (1, 2, 3...)
  final String? mediaPath;
  final String? mediaType;

  CrosswordWord({
    required this.id,
    required this.question,
    required this.answer,
    required this.row,
    required this.col,
    required this.direction,
    required this.number,
    this.mediaPath,
    this.mediaType,
  });

  factory CrosswordWord.fromJson(Map<String, dynamic> json) =>
      _$CrosswordWordFromJson(json);

  Map<String, dynamic> toJson() => _$CrosswordWordToJson(this);

  WordDirection get wordDirection =>
      direction == 'across' ? WordDirection.across : WordDirection.down;

  bool get isAcross => direction == 'across';
  bool get isDown => direction == 'down';

  int get length => answer.replaceAll(' ', '').length;

  // Kelimenin kapladığı tüm hücreleri döndür
  List<CellPosition> get cells {
    List<CellPosition> positions = [];
    String cleanAnswer = answer.replaceAll(' ', '');
    
    for (int i = 0; i < cleanAnswer.length; i++) {
      if (isAcross) {
        positions.add(CellPosition(row, col + i));
      } else {
        positions.add(CellPosition(row + i, col));
      }
    }
    return positions;
  }

  // Belirli bir pozisyondaki harfi döndür
  String? letterAt(int r, int c) {
    String cleanAnswer = answer.replaceAll(' ', '');
    
    if (isAcross && r == row && c >= col && c < col + cleanAnswer.length) {
      return cleanAnswer[c - col];
    } else if (isDown && c == col && r >= row && r < row + cleanAnswer.length) {
      return cleanAnswer[r - row];
    }
    return null;
  }

  // Bu kelime belirli bir hücreyi kapsıyor mu?
  bool containsCell(int r, int c) {
    return cells.any((cell) => cell.row == r && cell.col == c);
  }
}

class CellPosition {
  final int row;
  final int col;

  CellPosition(this.row, this.col);

  @override
  bool operator ==(Object other) {
    if (other is CellPosition) {
      return row == other.row && col == other.col;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row, $col)';
}
