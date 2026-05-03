import 'package:json_annotation/json_annotation.dart';
import 'puzzle_clue.dart';

part 'puzzle_set.g.dart';

@JsonSerializable()
class PuzzleSet {
  final String id;
  final String title;
  final int difficulty;
  final List<PuzzleClue> clues;
  final String? description;
  
  PuzzleSet({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.clues,
    this.description,
  });

  factory PuzzleSet.fromJson(Map<String, dynamic> json) =>
      _$PuzzleSetFromJson(json);

  Map<String, dynamic> toJson() => _$PuzzleSetToJson(this);
}
