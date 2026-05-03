import 'package:json_annotation/json_annotation.dart';
import 'crossword_clue.dart';
import 'dart:math';

part 'crossword_category.g.dart';

/// Bir çengel bulmaca kategorisi (örn: Divan Edebiyatı, Tanzimat, vb.)
@JsonSerializable()
class CrosswordCategory {
  final String id;
  final String name;
  final List<CrosswordClue> clues;

  CrosswordCategory({
    required this.id,
    required this.name,
    required this.clues,
  });

  factory CrosswordCategory.fromJson(Map<String, dynamic> json) =>
      _$CrosswordCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$CrosswordCategoryToJson(this);

  /// Toplam soru sayısı
  int get totalClues => clues.length;

  /// Kolay soruları getir
  List<CrosswordClue> get easyClues =>
      clues.where((c) => c.difficulty == 1).toList();

  /// Orta zorlukta soruları getir
  List<CrosswordClue> get mediumClues =>
      clues.where((c) => c.difficulty == 2).toList();

  /// Zor soruları getir
  List<CrosswordClue> get hardClues =>
      clues.where((c) => c.difficulty == 3).toList();

  /// Rastgele n adet soru seç (zorluk dengesini gözet)
  List<CrosswordClue> getRandomClues(int count, {int? seed}) {
    if (clues.isEmpty) return [];
    if (count >= clues.length) {
      final shuffled = List<CrosswordClue>.from(clues);
      if (seed != null) {
        shuffled.shuffle(Random(seed));
      } else {
        shuffled.shuffle();
      }
      return shuffled;
    }

    final random = seed != null ? Random(seed) : Random();
    final selected = <CrosswordClue>[];
    final available = List<CrosswordClue>.from(clues);

    // Zorluk dengesi: %40 kolay, %35 orta, %25 zor
    final easy = easyClues.toList()..shuffle(random);
    final medium = mediumClues.toList()..shuffle(random);
    final hard = hardClues.toList()..shuffle(random);

    final easyCount = (count * 0.4).ceil();
    final mediumCount = (count * 0.35).ceil();
    final hardCount = count - easyCount - mediumCount;

    // Kolay soruları ekle
    for (int i = 0; i < easyCount && i < easy.length && selected.length < count; i++) {
      selected.add(easy[i]);
    }

    // Orta soruları ekle
    for (int i = 0; i < mediumCount && i < medium.length && selected.length < count; i++) {
      if (!selected.contains(medium[i])) {
        selected.add(medium[i]);
      }
    }

    // Zor soruları ekle
    for (int i = 0; i < hardCount && i < hard.length && selected.length < count; i++) {
      if (!selected.contains(hard[i])) {
        selected.add(hard[i]);
      }
    }

    // Eğer hala eksik varsa, kalan sorulardan rastgele ekle
    available.shuffle(random);
    for (var clue in available) {
      if (selected.length >= count) break;
      if (!selected.contains(clue)) {
        selected.add(clue);
      }
    }

    selected.shuffle(random);
    return selected;
  }

  @override
  String toString() => 'CrosswordCategory($id: $name, ${clues.length} clues)';
}
