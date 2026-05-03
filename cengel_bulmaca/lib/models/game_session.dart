import 'package:json_annotation/json_annotation.dart';

part 'game_session.g.dart';

@JsonSerializable()
class GameSession {
  final String id;
  final String topicId;
  final String topicName;
  final List<String> puzzleSetIds;
  final Map<String, bool> completedPuzzles;
  final Map<String, int> scores;
  final DateTime startTime;
  DateTime? endTime;
  bool isCompleted;
  
  GameSession({
    required this.id,
    required this.topicId,
    required this.topicName,
    required this.puzzleSetIds,
    Map<String, bool>? completedPuzzles,
    Map<String, int>? scores,
    required this.startTime,
    this.endTime,
    this.isCompleted = false,
  }) : completedPuzzles = completedPuzzles ?? {},
       scores = scores ?? {};

  factory GameSession.fromJson(Map<String, dynamic> json) =>
      _$GameSessionFromJson(json);

  Map<String, dynamic> toJson() => _$GameSessionToJson(this);

  void markPuzzleCompleted(String puzzleSetId, int score) {
    completedPuzzles[puzzleSetId] = true;
    scores[puzzleSetId] = score;
    
    if (completedPuzzles.length == puzzleSetIds.length) {
      isCompleted = true;
      endTime = DateTime.now();
    }
  }

  int get totalScore => scores.values.fold(0, (sum, score) => sum + score);

  double get completionPercentage {
    if (puzzleSetIds.isEmpty) return 0.0;
    return (completedPuzzles.length / puzzleSetIds.length) * 100;
  }

  Duration? get totalDuration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }
}
