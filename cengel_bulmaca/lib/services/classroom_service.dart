import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Sınıf Modu REST + Long Polling servisi.
/// Çoklu oyuncudan tamamen ayrı; /api/classroom/... uç noktalarına bağlanır.
class ClassroomService {
  static final ClassroomService instance = ClassroomService._();
  ClassroomService._();

  static const String _apiUrl = 'https://app.cayadev.com/edebi-cengel-server';

  String? _authToken;
  String? _playerId;
  String? _roomCode;
  bool _isPolling = false;
  int _lastEventId = 0;
  Timer? _heartbeatTimer;

  // --- olay akışları ---
  final _roomCreated = StreamController<Map<String, dynamic>>.broadcast();
  final _roomJoined = StreamController<Map<String, dynamic>>.broadcast();
  final _roomUpdated = StreamController<Map<String, dynamic>>.broadcast();
  final _studentJoined = StreamController<Map<String, dynamic>>.broadcast();
  final _studentLeft = StreamController<Map<String, dynamic>>.broadcast();
  final _studentKicked = StreamController<Map<String, dynamic>>.broadcast();
  final _gameStarted = StreamController<Map<String, dynamic>>.broadcast();
  final _playerProgress = StreamController<Map<String, dynamic>>.broadcast();
  final _playerFinished = StreamController<Map<String, dynamic>>.broadcast();
  final _gameEnded = StreamController<Map<String, dynamic>>.broadcast();
  final _roomClosed = StreamController<Map<String, dynamic>>.broadcast();
  final _disconnected = StreamController<Map<String, dynamic>>.broadcast();
  final _error = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onRoomCreated => _roomCreated.stream;
  Stream<Map<String, dynamic>> get onRoomJoined => _roomJoined.stream;
  Stream<Map<String, dynamic>> get onRoomUpdated => _roomUpdated.stream;
  Stream<Map<String, dynamic>> get onStudentJoined => _studentJoined.stream;
  Stream<Map<String, dynamic>> get onStudentLeft => _studentLeft.stream;
  Stream<Map<String, dynamic>> get onStudentKicked => _studentKicked.stream;
  Stream<Map<String, dynamic>> get onGameStarted => _gameStarted.stream;
  Stream<Map<String, dynamic>> get onPlayerProgress => _playerProgress.stream;
  Stream<Map<String, dynamic>> get onPlayerFinished => _playerFinished.stream;
  Stream<Map<String, dynamic>> get onGameEnded => _gameEnded.stream;
  Stream<Map<String, dynamic>> get onRoomClosed => _roomClosed.stream;
  Stream<Map<String, dynamic>> get onDisconnected => _disconnected.stream;
  Stream<Map<String, dynamic>> get onError => _error.stream;

  String? get playerId => _playerId;
  String? get roomCode => _roomCode;

  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Çıkış / hesap değişimi sonrasında singleton'daki tüm hassas state'i sil:
  /// auth token, oda kodu, oyuncu kimliği, polling, heartbeat. Bu çağrı sonrası
  /// servise yapılan istekler artık önceki kullanıcının yetkisini taşımaz ve
  /// önceki ekranlarda görüntülenen sorular yeniden çekilirse boş döner.
  void clearAuth() {
    _authToken = null;
    _stopPolling();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _roomCode = null;
    _playerId = null;
    _lastEventId = 0;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken!.isNotEmpty)
          'Authorization': 'Bearer $_authToken',
      };

  // -------------------- Oda işlemleri --------------------

  Future<Map<String, dynamic>?> createRoom({
    required String displayName,
    required Map<String, dynamic> settings,
    required Map<String, dynamic> meta,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_apiUrl/api/classroom/rooms'),
            headers: _headers,
            body: jsonEncode({
              'displayName': displayName,
              'settings': settings,
              'meta': meta,
            }),
          )
          .timeout(const Duration(seconds: 12));
      final data = _safeDecode(r.body);
      if (r.statusCode == 200 && data?['success'] == true) {
        _roomCode = data!['roomCode'] as String;
        _playerId = data['playerId'] as String;
        _lastEventId = 0;
        // Sunucudan dönen `isTeacher` ve `playerId` bayraklarını event verisine
        // gömerek provider'ın doğru rolü almasını garantile
        final eventData = Map<String, dynamic>.from(data['room']);
        eventData['_isTeacher'] = true;
        eventData['_selfPlayerId'] = _playerId;
        _roomCreated.add(eventData);
        _startPolling();
        _startHeartbeat();
        return data;
      } else {
        _error.add({'message': data?['message'] ?? 'Oda oluşturulamadı'});
        return null;
      }
    } catch (e) {
      _error.add({'message': 'Sunucuya ulaşılamadı: $e'});
      return null;
    }
  }

  Future<Map<String, dynamic>?> joinRoom({
    required String code,
    required String displayName,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_apiUrl/api/classroom/rooms/$code/join'),
            headers: _headers,
            body: jsonEncode({'displayName': displayName}),
          )
          .timeout(const Duration(seconds: 12));
      final data = _safeDecode(r.body);
      if (r.statusCode == 200 && data?['success'] == true) {
        _roomCode = data!['roomCode'] as String;
        _playerId = data['playerId'] as String;
        _lastEventId = 0;
        // Sunucu, aynı kullanıcı tekrar katılırsa öğretmen olarak da
        // dönebileceğinden `isTeacher` bayrağını yetkili kaynaktan al
        final eventData = Map<String, dynamic>.from(data['room']);
        eventData['_isTeacher'] = data['isTeacher'] == true;
        eventData['_selfPlayerId'] = _playerId;
        _roomJoined.add(eventData);
        _startPolling();
        _startHeartbeat();
        return data;
      } else {
        _error.add({'message': data?['message'] ?? 'Odaya katılamadı'});
        return null;
      }
    } catch (e) {
      _error.add({'message': 'Sunucuya ulaşılamadı: $e'});
      return null;
    }
  }

  Future<Map<String, dynamic>?> peekRoom(String code) async {
    try {
      final r = await http
          .get(Uri.parse('$_apiUrl/api/classroom/rooms/$code/peek'),
              headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) return _safeDecode(r.body);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateSettings({
    required Map<String, dynamic> settings,
    Map<String, dynamic>? meta,
  }) async {
    if (_roomCode == null) return false;
    return _post('/api/classroom/rooms/$_roomCode/settings', {
      'settings': settings,
      if (meta != null) 'meta': meta,
    });
  }

  Future<bool> startGame(Map<String, dynamic> puzzleData) async {
    if (_roomCode == null) return false;
    return _post('/api/classroom/rooms/$_roomCode/start', {
      'puzzleData': puzzleData,
    });
  }

  Future<bool> updateProgress({
    required int completedWords,
    required int totalWords,
    required int score,
    required int hintsUsed,
    required int lettersRevealed,
    required int wordsRevealed,
  }) async {
    if (_roomCode == null || _playerId == null) return false;
    return _post('/api/classroom/rooms/$_roomCode/progress', {
      'playerId': _playerId,
      'completedWords': completedWords,
      'totalWords': totalWords,
      'score': score,
      'hintsUsed': hintsUsed,
      'lettersRevealed': lettersRevealed,
      'wordsRevealed': wordsRevealed,
    });
  }

  Future<bool> finishGame({
    required int score,
    required int completedWords,
    required int totalWords,
    required int hintsUsed,
    required int lettersRevealed,
    required int wordsRevealed,
    required int durationSeconds,
  }) async {
    if (_roomCode == null || _playerId == null) return false;
    return _post('/api/classroom/rooms/$_roomCode/finished', {
      'playerId': _playerId,
      'score': score,
      'completedWords': completedWords,
      'totalWords': totalWords,
      'hintsUsed': hintsUsed,
      'lettersRevealed': lettersRevealed,
      'wordsRevealed': wordsRevealed,
      'durationSeconds': durationSeconds,
    });
  }

  Future<bool> endExam() async {
    if (_roomCode == null) return false;
    return _post('/api/classroom/rooms/$_roomCode/end', {});
  }

  Future<bool> kickStudent(String studentId) async {
    if (_roomCode == null) return false;
    return _post('/api/classroom/rooms/$_roomCode/kick', {'studentId': studentId});
  }

  Future<void> leaveRoom() async {
    final code = _roomCode;
    final pid = _playerId;
    _stopPolling();
    _heartbeatTimer?.cancel();
    if (code != null && pid != null) {
      try {
        await http
            .post(
              Uri.parse('$_apiUrl/api/classroom/rooms/$code/leave'),
              headers: _headers,
              body: jsonEncode({'playerId': pid}),
            )
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
    _roomCode = null;
    _playerId = null;
    _lastEventId = 0;
  }

  // -------------------- Özel sorular --------------------

  Future<List<Map<String, dynamic>>> listCustomQuestions() async {
    try {
      final r = await http
          .get(Uri.parse('$_apiUrl/api/classroom/questions'),
              headers: _headers)
          .timeout(const Duration(seconds: 8));
      final data = _safeDecode(r.body);
      if (r.statusCode == 200 && data?['success'] == true) {
        return List<Map<String, dynamic>>.from(
          (data!['questions'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> addCustomQuestions(
      List<Map<String, dynamic>> questions) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_apiUrl/api/classroom/questions'),
            headers: _headers,
            body: jsonEncode({'questions': questions}),
          )
          .timeout(const Duration(seconds: 10));
      final data = _safeDecode(r.body);
      if (r.statusCode == 200 && data?['success'] == true) {
        return List<Map<String, dynamic>>.from(
          (data!['added'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (_) {}
    return [];
  }

  Future<bool> deleteCustomQuestion(String id) async {
    try {
      final r = await http
          .delete(Uri.parse('$_apiUrl/api/classroom/questions/$id'),
              headers: _headers)
          .timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAllCustomQuestions() async {
    try {
      final r = await http
          .delete(Uri.parse('$_apiUrl/api/classroom/questions'),
              headers: _headers)
          .timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // -------------------- Sınav arşivi --------------------

  Future<List<Map<String, dynamic>>> listHistory() async {
    try {
      final r = await http
          .get(Uri.parse('$_apiUrl/api/classroom/history'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      final data = _safeDecode(r.body);
      if (r.statusCode == 200 && data?['success'] == true) {
        return List<Map<String, dynamic>>.from(
          (data!['history'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getHistoryRecord(String id) async {
    try {
      final r = await http
          .get(Uri.parse('$_apiUrl/api/classroom/history/$id'),
              headers: _headers)
          .timeout(const Duration(seconds: 8));
      final data = _safeDecode(r.body);
      if (r.statusCode == 200 && data?['success'] == true) {
        return Map<String, dynamic>.from(data!['record']);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deleteHistoryRecord(String id) async {
    try {
      final r = await http
          .delete(Uri.parse('$_apiUrl/api/classroom/history/$id'),
              headers: _headers)
          .timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // -------------------- iç --------------------

  Future<bool> _post(String path, Map<String, dynamic> body) async {
    try {
      final mergedBody = {
        if (_playerId != null) 'playerId': _playerId,
        ...body,
      };
      final r = await http
          .post(Uri.parse('$_apiUrl$path'),
              headers: _headers, body: jsonEncode(mergedBody))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return true;
      final data = _safeDecode(r.body);
      if (data?['message'] != null) {
        _error.add({'message': data!['message']});
      }
      return false;
    } catch (e) {
      debugPrint('[Classroom] POST $path hata: $e');
      return false;
    }
  }

  Map<String, dynamic>? _safeDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // -------------------- Long polling --------------------

  void _startPolling() {
    if (_isPolling) return;
    _isPolling = true;
    _pollLoop();
  }

  void _stopPolling() {
    _isPolling = false;
  }

  Future<void> _pollLoop() async {
    int errors = 0;
    while (_isPolling && _roomCode != null) {
      try {
        final url = Uri.parse(
            '$_apiUrl/api/classroom/rooms/$_roomCode/poll?since=$_lastEventId&playerId=$_playerId');
        final r = await http.get(url).timeout(const Duration(seconds: 30));
        if (!_isPolling) break;
        if (r.statusCode == 200) {
          errors = 0;
          final data = _safeDecode(r.body);
          final events = List<Map<String, dynamic>>.from(
              (data?['events'] ?? []).map((e) => Map<String, dynamic>.from(e)));
          for (final ev in events) {
            final id = ev['id'] as int;
            if (id > _lastEventId) _lastEventId = id;
            _dispatch(ev['type'] as String,
                Map<String, dynamic>.from(ev['data'] ?? {}));
          }
        } else if (r.statusCode == 404) {
          _error.add({'message': 'Oda artık mevcut değil.'});
          _stopPolling();
          break;
        } else {
          errors++;
          await Future.delayed(Duration(seconds: errors.clamp(1, 5)));
        }
      } catch (e) {
        if (!_isPolling) break;
        errors++;
        await Future.delayed(Duration(seconds: errors.clamp(1, 8)));
      }
    }
  }

  void _dispatch(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'room_updated':
        _roomUpdated.add(data);
        break;
      case 'student_joined':
        _studentJoined.add(data);
        break;
      case 'student_left':
        _studentLeft.add(data);
        break;
      case 'student_kicked':
        _studentKicked.add(data);
        break;
      case 'game_started':
        _gameStarted.add(data);
        break;
      case 'player_progress':
        _playerProgress.add(data);
        break;
      case 'player_finished':
        _playerFinished.add(data);
        break;
      case 'game_ended':
        _gameEnded.add(data);
        break;
      case 'room_closed':
        _roomClosed.add(data);
        break;
      case 'player_disconnected':
        _disconnected.add(data);
        break;
      default:
        debugPrint('[Classroom] bilinmeyen olay: $type');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_roomCode != null && _playerId != null) {
        _post('/api/classroom/rooms/$_roomCode/heartbeat', {});
      }
    });
  }
}
