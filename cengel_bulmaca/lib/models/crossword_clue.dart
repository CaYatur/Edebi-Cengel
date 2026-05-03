import 'package:json_annotation/json_annotation.dart';

part 'crossword_clue.g.dart';

/// Tek bir çengel bulmaca ipucu/sorusu
@JsonSerializable()
class CrosswordClue {
  final String id;
  final String question;
  final String answer;
  final int difficulty; // 1: Kolay, 2: Orta, 3: Zor

  CrosswordClue({
    required this.id,
    required this.question,
    required this.answer,
    this.difficulty = 2,
  });

  factory CrosswordClue.fromJson(Map<String, dynamic> json) =>
      _$CrosswordClueFromJson(json);

  Map<String, dynamic> toJson() => _$CrosswordClueToJson(this);

  /// Cevabın uzunluğu (boşluksuz)
  int get answerLength => answer.replaceAll(' ', '').length;

  /// Cevap büyük harfle ve temizlenmiş
  String get cleanAnswer => answer.toUpperCase().replaceAll(' ', '');

  @override
  String toString() => 'CrosswordClue($id: $question -> $answer)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrosswordClue &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
