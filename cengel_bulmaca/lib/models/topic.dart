import 'package:json_annotation/json_annotation.dart';
import 'puzzle_set.dart';
import 'puzzle_clue.dart';

part 'topic.g.dart';

@JsonSerializable()
class Topic {
  final String id;
  final String name;
  final String description;
  final List<PuzzleSet> puzzleSets;
  final String? iconPath;
  
  Topic({
    required this.id,
    required this.name,
    required this.description,
    required this.puzzleSets,
    this.iconPath,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);

  Map<String, dynamic> toJson() => _$TopicToJson(this);

  // Zorluk seviyesine göre puzzle setleri getir
  List<PuzzleSet> getPuzzleSetsByDifficulty(int difficulty) {
    return puzzleSets.where((set) => set.difficulty == difficulty).toList();
  }

  // Mevcut zorluk seviyelerini getir
  List<int> getAvailableDifficulties() {
    return puzzleSets.map((set) => set.difficulty).toSet().toList()..sort();
  }

  // Rastgele puzzle set seç (tüm zorluklardan)
  List<PuzzleSet> getRandomPuzzleSets({int? count}) {
    List<PuzzleSet> shuffled = List.from(puzzleSets)..shuffle();
    if (count != null && count < shuffled.length) {
      return shuffled.take(count).toList();
    }
    return shuffled;
  }

  // Her zorluk seviyesinden rastgele seç
  List<PuzzleSet> getRandomMixedDifficulty({int? maxPerDifficulty}) {
    List<PuzzleSet> result = [];
    List<int> difficulties = getAvailableDifficulties();
    
    for (int difficulty in difficulties) {
      List<PuzzleSet> setsOfDifficulty = getPuzzleSetsByDifficulty(difficulty);
      setsOfDifficulty.shuffle();
      
      int takeCount = maxPerDifficulty ?? setsOfDifficulty.length;
      result.addAll(setsOfDifficulty.take(takeCount));
    }
    
    result.shuffle();
    return result;
  }
  
  // Toplam 10 tane rastgele soru getir (tüm zorluklardan karışık)
  List<PuzzleClue> getRandomQuestions({int maxQuestions = 10}) {
    List<PuzzleClue> allQuestions = [];
    
    // Tüm puzzle setlerden tüm soruları topla
    for (PuzzleSet set in puzzleSets) {
      allQuestions.addAll(set.clues);
    }
    
    // Karıştır ve max sayı kadar al
    allQuestions.shuffle();
    return allQuestions.take(maxQuestions).toList();
  }
}
