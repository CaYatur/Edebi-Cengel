// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crossword_clue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CrosswordClue _$CrosswordClueFromJson(Map<String, dynamic> json) =>
    CrosswordClue(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 2,
    );

Map<String, dynamic> _$CrosswordClueToJson(CrosswordClue instance) =>
    <String, dynamic>{
      'id': instance.id,
      'question': instance.question,
      'answer': instance.answer,
      'difficulty': instance.difficulty,
    };
