// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topic.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Topic _$TopicFromJson(Map<String, dynamic> json) => Topic(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      puzzleSets: (json['puzzleSets'] as List<dynamic>)
          .map((e) => PuzzleSet.fromJson(e as Map<String, dynamic>))
          .toList(),
      iconPath: json['iconPath'] as String?,
    );

Map<String, dynamic> _$TopicToJson(Topic instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'puzzleSets': instance.puzzleSets,
      'iconPath': instance.iconPath,
    };
