import 'package:json_annotation/json_annotation.dart';
import 'dart:math';

part 'puzzle_clue.g.dart';

@JsonSerializable()
class PuzzleClue {
  final String id;
  final String question;
  final String answer;
  final int visibleLetterCount;
  final List<int> visiblePositions;
  final String? mediaPath;
  final String? mediaType; // 'video', 'audio', null
  
  PuzzleClue({
    required this.id,
    required this.question,
    required this.answer,
    this.visibleLetterCount = 1,
    this.visiblePositions = const [],
    this.mediaPath,
    this.mediaType,
  });

  factory PuzzleClue.fromJson(Map<String, dynamic> json) =>
      _$PuzzleClueFromJson(json);

  Map<String, dynamic> toJson() => _$PuzzleClueToJson(this);

  String get maskedAnswer {
    if (visiblePositions.isNotEmpty) {
      // Belirli pozisyonlar gösterilecek
      return _maskAnswerByPositions();
    } else {
      // İlk N harf gösterilecek
      return _maskAnswerByCount();
    }
  }

  String _maskAnswerByPositions() {
    List<String> chars = answer.split('');
    for (int i = 0; i < chars.length; i++) {
      if (!visiblePositions.contains(i) && chars[i] != ' ') {
        chars[i] = '_';
      }
    }
    return chars.join('');
  }

  String _maskAnswerByCount() {
    List<String> chars = answer.split('');
    List<int> letterPositions = [];
    
    // Harf pozisyonlarını bul (boşluk olmayanlar)
    for (int i = 0; i < chars.length; i++) {
      if (chars[i] != ' ') {
        letterPositions.add(i);
      }
    }
    
    if (letterPositions.isEmpty) return answer;
    
    // ID'ye göre sabit seed kullan - aynı ID her zaman aynı pozisyonları verir
    Random seededRandom = Random(id.hashCode);
    letterPositions.shuffle(seededRandom);
    int showCount = visibleLetterCount.clamp(1, letterPositions.length);
    Set<int> visiblePositions = Set.from(letterPositions.take(showCount));
    
    // Maskeleme yap
    for (int i = 0; i < chars.length; i++) {
      if (chars[i] != ' ' && !visiblePositions.contains(i)) {
        chars[i] = '_';
      }
    }
    
    return chars.join('');
  }

  bool checkAnswer(String userAnswer) {
    final normalizedAnswer = _normalizeText(answer);
    final normalizedUserAnswer = _normalizeText(userAnswer);
    
    return normalizedAnswer == normalizedUserAnswer;
  }

  String _normalizeText(String text) {
    return text.toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '') // Tüm boşlukları kaldır
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
  }
}
