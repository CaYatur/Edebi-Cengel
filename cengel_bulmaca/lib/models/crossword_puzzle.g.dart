// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crossword_puzzle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CrosswordPuzzle _$CrosswordPuzzleFromJson(Map<String, dynamic> json) =>
    CrosswordPuzzle(
      id: json['id'] as String,
      title: json['title'] as String,
      difficulty: (json['difficulty'] as num).toInt(),
      description: json['description'] as String,
      gridRows: (json['gridRows'] as num).toInt(),
      gridCols: (json['gridCols'] as num).toInt(),
      words: (json['words'] as List<dynamic>)
          .map((e) => CrosswordWord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CrosswordPuzzleToJson(CrosswordPuzzle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'difficulty': instance.difficulty,
      'description': instance.description,
      'gridRows': instance.gridRows,
      'gridCols': instance.gridCols,
      'words': instance.words,
    };
