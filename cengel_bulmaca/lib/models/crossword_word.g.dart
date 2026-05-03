// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crossword_word.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CrosswordWord _$CrosswordWordFromJson(Map<String, dynamic> json) =>
    CrosswordWord(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      row: (json['row'] as num).toInt(),
      col: (json['col'] as num).toInt(),
      direction: json['direction'] as String,
      number: (json['number'] as num).toInt(),
      mediaPath: json['mediaPath'] as String?,
      mediaType: json['mediaType'] as String?,
    );

Map<String, dynamic> _$CrosswordWordToJson(CrosswordWord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'question': instance.question,
      'answer': instance.answer,
      'row': instance.row,
      'col': instance.col,
      'direction': instance.direction,
      'number': instance.number,
      'mediaPath': instance.mediaPath,
      'mediaType': instance.mediaType,
    };
