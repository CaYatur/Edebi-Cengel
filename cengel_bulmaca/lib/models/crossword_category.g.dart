// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crossword_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CrosswordCategory _$CrosswordCategoryFromJson(Map<String, dynamic> json) =>
    CrosswordCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      clues: (json['clues'] as List<dynamic>)
          .map((e) => CrosswordClue.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CrosswordCategoryToJson(CrosswordCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'clues': instance.clues,
    };
