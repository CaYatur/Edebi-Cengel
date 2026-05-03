// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GameSession _$GameSessionFromJson(Map<String, dynamic> json) => GameSession(
      id: json['id'] as String,
      topicId: json['topicId'] as String,
      topicName: json['topicName'] as String,
      puzzleSetIds: (json['puzzleSetIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      completedPuzzles:
          (json['completedPuzzles'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as bool),
      ),
      scores: (json['scores'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );

Map<String, dynamic> _$GameSessionToJson(GameSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'topicId': instance.topicId,
      'topicName': instance.topicName,
      'puzzleSetIds': instance.puzzleSetIds,
      'completedPuzzles': instance.completedPuzzles,
      'scores': instance.scores,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'isCompleted': instance.isCompleted,
    };
