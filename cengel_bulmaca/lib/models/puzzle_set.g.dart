// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'puzzle_set.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PuzzleSet _$PuzzleSetFromJson(Map<String, dynamic> json) => PuzzleSet(
      id: json['id'] as String,
      title: json['title'] as String,
      difficulty: (json['difficulty'] as num).toInt(),
      clues: (json['clues'] as List<dynamic>)
          .map((e) => PuzzleClue.fromJson(e as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$PuzzleSetToJson(PuzzleSet instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'difficulty': instance.difficulty,
      'clues': instance.clues,
      'description': instance.description,
    };
