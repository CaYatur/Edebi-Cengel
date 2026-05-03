// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'puzzle_clue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PuzzleClue _$PuzzleClueFromJson(Map<String, dynamic> json) => PuzzleClue(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      visibleLetterCount: (json['visibleLetterCount'] as num?)?.toInt() ?? 1,
      visiblePositions: (json['visiblePositions'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      mediaPath: json['mediaPath'] as String?,
      mediaType: json['mediaType'] as String?,
    );

Map<String, dynamic> _$PuzzleClueToJson(PuzzleClue instance) =>
    <String, dynamic>{
      'id': instance.id,
      'question': instance.question,
      'answer': instance.answer,
      'visibleLetterCount': instance.visibleLetterCount,
      'visiblePositions': instance.visiblePositions,
      'mediaPath': instance.mediaPath,
      'mediaType': instance.mediaType,
    };
