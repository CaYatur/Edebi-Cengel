import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/crossword_puzzle.dart';

class CrosswordDataService {
  List<CrosswordPuzzle> _puzzles = [];
  
  List<CrosswordPuzzle> get puzzles => _puzzles;
  
  Future<void> initialize() async {
    try {
      final String response = await rootBundle.loadString('assets/data/crosswords.json');
      final data = json.decode(response);
      
      if (data['puzzles'] != null) {
        _puzzles = (data['puzzles'] as List)
            .map((json) => CrosswordPuzzle.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('CrosswordDataService initialize error: $e');
      // Varsayılan demo puzzle oluştur
      _puzzles = [_createDemoPuzzle()];
    }
  }

  CrosswordPuzzle _createDemoPuzzle() {
    return CrosswordPuzzle(
      id: 'demo_puzzle',
      title: 'Demo Çengel Bulmaca',
      difficulty: 1,
      description: 'Örnek bir çengel bulmaca',
      gridRows: 10,
      gridCols: 10,
      words: [],
    );
  }
}
