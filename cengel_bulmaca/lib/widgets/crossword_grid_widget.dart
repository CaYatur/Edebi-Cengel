import 'package:flutter/material.dart';
import '../models/crossword_puzzle.dart';
import '../models/crossword_word.dart';
import '../services/settings_service.dart';

class CrosswordGridWidget extends StatelessWidget {
  final CrosswordPuzzle puzzle;
  final Map<String, String> userAnswers; // cellKey -> letter
  final CrosswordWord? selectedWord;
  final CellPosition? selectedCell;
  final Function(int row, int col)? onCellTap;
  final Set<String> correctCells; // Doğru cevaplanan hücreler
  final Set<String> hintedCells; // İpucu ile açılan hücreler

  const CrosswordGridWidget({
    super.key,
    required this.puzzle,
    required this.userAnswers,
    this.selectedWord,
    this.selectedCell,
    this.onCellTap,
    this.correctCells = const {},
    this.hintedCells = const {},
  });

  String _cellKey(int row, int col) => '$row-$col';

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    // Grid boyutları kontrolü
    if (puzzle.gridRows <= 0 || puzzle.gridCols <= 0) {
      return Center(
        child: Text('Bulmaca yüklenemedi - geçersiz grid boyutu',
          style: TextStyle(fontSize: 14 * settings.fontSize),
        ),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Grid boyutunu hesapla - border için 4 piksel çıkar
        double availableWidth = constraints.maxWidth - 8;
        double availableHeight = constraints.maxHeight - 8;
        
        // Sıfıra bölme kontrolü
        if (puzzle.gridCols == 0 || puzzle.gridRows == 0) {
          return Center(
            child: Text('Geçersiz bulmaca',
              style: TextStyle(fontSize: 14 * settings.fontSize),
            ),
          );
        }
        
        // Hücre boyutunu hem genişlik hem yüksekliğe göre hesapla
        double cellByWidth = availableWidth / puzzle.gridCols;
        double cellByHeight = availableHeight / puzzle.gridRows;
        
        // İkisinden küçük olanı seç ki taşma olmasın
        double cellSize = cellByWidth < cellByHeight ? cellByWidth : cellByHeight;
        cellSize = cellSize.clamp(18.0, 40.0);
        
        double gridWidth = cellSize * puzzle.gridCols;
        double gridHeight = cellSize * puzzle.gridRows;

        return Center(
          child: Container(
            width: gridWidth + 4, // border için
            height: gridHeight + 4,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF37474F), width: 2),
              color: const Color(0xFF37474F),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(puzzle.gridRows, (row) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(puzzle.gridCols, (col) {
                    return _buildCell(row, col, cellSize, settings);
                  }),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(int row, int col, double cellSize, SettingsService settings) {
    bool isActive = puzzle.isCellActive(row, col);
    String cellKey = _cellKey(row, col);
    String? userLetter = userAnswers[cellKey];
    int? number = puzzle.getNumberAt(row, col);
    bool isSelected = selectedCell?.row == row && selectedCell?.col == col;
    bool isInSelectedWord = selectedWord?.containsCell(row, col) ?? false;
    bool isCorrect = correctCells.contains(cellKey);
    bool isHinted = hintedCells.contains(cellKey);

    if (!isActive) {
      // Boş hücre
      return Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: const Color(0xFF37474F),
          border: Border.all(color: const Color(0xFF37474F), width: 0.5),
        ),
      );
    }

    // Aktif hücre (beyaz)
    Color bgColor = Colors.white;
    if (isCorrect && isHinted) {
      bgColor = Colors.orange.shade100; // İpucu ile açılan doğru hücre
    } else if (isCorrect) {
      bgColor = Colors.green.shade100;
    } else if (isSelected) {
      bgColor = Colors.blue.shade300;
    } else if (isInSelectedWord) {
      bgColor = Colors.blue.shade100;
    }

    // Harf rengi
    Color letterColor = Colors.black;
    if (isCorrect && isHinted) {
      letterColor = Colors.orange.shade800;
    } else if (isCorrect) {
      letterColor = Colors.green.shade800;
    }

    return GestureDetector(
      onTap: () => onCellTap?.call(row, col),
      child: Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: const Color(0xFF546E7A), width: 0.5),
        ),
        child: Stack(
          children: [
            // Numara (sol üst)
            if (number != null)
              Positioned(
                left: 2,
                top: 1,
                child: Text(
                  number.toString(),
                  style: TextStyle(
                    fontSize: cellSize * 0.25 * settings.fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
            // Harf (orta)
            Center(
              child: Text(
                userLetter ?? '',
                style: TextStyle(
                  fontSize: cellSize * 0.5 * settings.fontSize,
                  fontWeight: FontWeight.bold,
                  color: letterColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
