import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Çoklu oyuncu REST API + Long Polling servisi.
/// Socket.IO yerine saf HTTP kullanır - Cloudflare üzerinden sorunsuz çalışır.
class MultiplayerService {
  static final MultiplayerService instance = MultiplayerService._();
  MultiplayerService._();

  static const String _apiUrl = 'https://app.cayadev.com/edebi-cengel-server';

  // Oturum durumu
  String? _playerId;
  String? _roomCode;
  String? _authToken;
  String? _userId;
  bool _isConnected = false;
  int _lastEventId = 0;
  bool _isPolling = false;
  Timer? _heartbeatTimer;

  // Stream Controllers
  final StreamController<Map<String, dynamic>> _roomCreatedController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _roomJoinedController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _roomUpdatedController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _playerJoinedController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _playerLeftController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _gameStartedController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _playerProgressController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _playerCompletedController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _gameEndedController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _errorController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _playerDisconnectedController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _gameCancelledController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController.broadcast();

  // Streams
  Stream<Map<String, dynamic>> get onRoomCreated =>
      _roomCreatedController.stream;
  Stream<Map<String, dynamic>> get onRoomJoined =>
      _roomJoinedController.stream;
  Stream<Map<String, dynamic>> get onRoomUpdated =>
      _roomUpdatedController.stream;
  Stream<Map<String, dynamic>> get onPlayerJoined =>
      _playerJoinedController.stream;
  Stream<Map<String, dynamic>> get onPlayerLeft =>
      _playerLeftController.stream;
  Stream<Map<String, dynamic>> get onGameStarted =>
      _gameStartedController.stream;
  Stream<Map<String, dynamic>> get onPlayerProgress =>
      _playerProgressController.stream;
  Stream<Map<String, dynamic>> get onPlayerCompleted =>
      _playerCompletedController.stream;
  Stream<Map<String, dynamic>> get onGameEnded =>
      _gameEndedController.stream;
  Stream<Map<String, dynamic>> get onError => _errorController.stream;
  Stream<Map<String, dynamic>> get onPlayerDisconnected =>
      _playerDisconnectedController.stream;
  Stream<Map<String, dynamic>> get onGameCancelled =>
      _gameCancelledController.stream;
  Stream<Map<String, dynamic>> get onChatMessage =>
      _chatMessageController.stream;

  bool get isConnected => _isConnected;
  String? get playerId => _playerId;
  String? get roomCode => _roomCode;

  /// Auth token ayarla
  void setAuthToken(String token, String userId) {
    _authToken = token;
    _userId = userId;
  }

  /// Bağlantıyı başlat (REST API'de sadece flag set eder)
  void connect() {
    _isConnected = true;
    debugPrint('[Multiplayer] ✅ REST API modu - bağlantı hazır');
  }

  /// Bağlantıyı kes
  void disconnect() {
    _stopPolling();
    _heartbeatTimer?.cancel();
    _isConnected = false;
    _roomCode = null;
    _playerId = null;
    _lastEventId = 0;
    debugPrint('[Multiplayer] 🔌 Bağlantı kesildi');
  }

  /// Servisi tamamen yok et
  void dispose() {
    disconnect();
    _roomCreatedController.close();
    _roomJoinedController.close();
    _roomUpdatedController.close();
    _playerJoinedController.close();
    _playerLeftController.close();
    _gameStartedController.close();
    _playerProgressController.close();
    _playerCompletedController.close();
    _gameEndedController.close();
    _errorController.close();
    _playerDisconnectedController.close();
    _gameCancelledController.close();
    _chatMessageController.close();
    debugPrint('[Multiplayer] 🗑️ Servis yok edildi');
  }

  /// Yeniden bağlan
  void reconnect() {
    if (_roomCode != null && !_isPolling) {
      _startPolling();
      _startHeartbeat();
    }
  }

  /// Bağlan ve hazır olana kadar bekle
  Future<bool> connectAndWait(
      {Duration timeout = const Duration(seconds: 10)}) async {
    _isConnected = true;
    return true; // HTTP her zaman bağlı
  }

  // ==================== ODA İŞLEMLERİ ====================

  /// Oda oluştur
  Future<bool> createRoom({
    required String displayName,
    String? userId,
    Map<String, dynamic>? settings,
  }) async {
    try {
      debugPrint('[Multiplayer] 🏠 Oda oluşturuluyor...');
      final response = await http
          .post(
            Uri.parse('$_apiUrl/api/mp/rooms'),
            headers: _headers,
            body: json.encode({
              'displayName': displayName,
              'userId': userId ?? _userId,
              'settings': settings,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _roomCode = data['roomCode'] as String;
        _playerId = data['playerId'] as String;
        _lastEventId = 0;

        debugPrint('[Multiplayer] ✅ Oda oluşturuldu: $_roomCode');

        // Stream'e bildir
        final roomData = Map<String, dynamic>.from(data['room']);
        _roomCreatedController.add(roomData);

        // Polling ve heartbeat başlat
        _startPolling();
        _startHeartbeat();
        return true;
      } else {
        final data = _tryParseJson(response.body);
        final message = data?['message'] ?? 'Oda oluşturulamadı';
        _errorController.add({'message': message});
        debugPrint('[Multiplayer] ❌ Oda oluşturulamadı: $message');
        return false;
      }
    } catch (e) {
      debugPrint('[Multiplayer] ❌ Oda oluşturma hatası: $e');
      _errorController.add({'message': 'Sunucuya bağlanılamadı: $e'});
      return false;
    }
  }

  /// Odaya katıl
  Future<bool> joinRoom({
    required String roomId,
    required String displayName,
    String? userId,
  }) async {
    try {
      debugPrint('[Multiplayer] 👤 Odaya katılınıyor: $roomId');
      final response = await http
          .post(
            Uri.parse('$_apiUrl/api/mp/rooms/$roomId/join'),
            headers: _headers,
            body: json.encode({
              'displayName': displayName,
              'userId': userId ?? _userId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _roomCode = data['roomCode'] as String;
        _playerId = data['playerId'] as String;
        _lastEventId = 0;

        debugPrint('[Multiplayer] ✅ Odaya katılındı: $_roomCode');

        // Stream'e bildir
        final roomData = Map<String, dynamic>.from(data['room']);
        _roomJoinedController.add(roomData);

        // Polling ve heartbeat başlat
        _startPolling();
        _startHeartbeat();
        return true;
      } else {
        final data = _tryParseJson(response.body);
        final message = data?['message'] ?? 'Odaya katılınamadı';
        _errorController.add({'message': message});
        debugPrint('[Multiplayer] ❌ Katılma hatası: $message');
        return false;
      }
    } catch (e) {
      debugPrint('[Multiplayer] ❌ Katılma hatası: $e');
      _errorController.add({'message': 'Sunucuya bağlanılamadı: $e'});
      return false;
    }
  }

  /// Oda ayarlarını güncelle
  Future<void> updateSettings({
    required String roomId,
    required Map<String, dynamic> settings,
  }) async {
    await _postAction('$_apiUrl/api/mp/rooms/$roomId/settings', {
      'playerId': _playerId,
      'settings': settings,
    });
  }

  /// Hazır durumunu değiştir
  Future<void> toggleReady({required String roomId}) async {
    await _postAction('$_apiUrl/api/mp/rooms/$roomId/ready', {
      'playerId': _playerId,
    });
  }

  /// Oyunu başlat (puzzleData gerekli)
  Future<bool> startGame({
    required String roomId,
    Map<String, dynamic>? puzzleData,
  }) async {
    try {
      debugPrint('[Multiplayer] 🎮 Oyun başlatılıyor...');
      final response = await http
          .post(
            Uri.parse('$_apiUrl/api/mp/rooms/$roomId/start'),
            headers: _headers,
            body: json.encode({
              'playerId': _playerId,
              'puzzleData': puzzleData,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('[Multiplayer] ✅ Oyun başlatıldı');
        return true;
      } else {
        final data = _tryParseJson(response.body);
        final message = data?['message'] ?? 'Oyun başlatılamadı';
        _errorController.add({'message': message});
        debugPrint('[Multiplayer] ❌ Oyun başlatma hatası: $message');
        return false;
      }
    } catch (e) {
      debugPrint('[Multiplayer] ❌ Oyun başlatma hatası: $e');
      return false;
    }
  }

  /// İlerleme güncelle
  Future<void> updateProgress({
    required String roomId,
    required int progress,
    required int score,
  }) async {
    await _postAction('$_apiUrl/api/mp/rooms/$roomId/progress', {
      'playerId': _playerId,
      'completedWords': progress,
      'score': score,
    });
  }

  /// Oyuncu bitirdi
  Future<void> playerFinished({
    required String roomId,
    required int score,
    required int finalTime,
  }) async {
    await _postAction('$_apiUrl/api/mp/rooms/$roomId/finished', {
      'playerId': _playerId,
      'score': score,
      'durationSeconds': finalTime,
    });
  }

  /// Oyunu zorla bitir (host)
  Future<void> endGame({required String roomId}) async {
    await _postAction('$_apiUrl/api/mp/rooms/$roomId/end', {
      'playerId': _playerId,
    });
  }

  /// Odadan ayrıl
  Future<void> leaveRoom({required String roomId}) async {
    _stopPolling();
    _heartbeatTimer?.cancel();
    await _postAction('$_apiUrl/api/mp/rooms/$roomId/leave', {
      'playerId': _playerId,
    });
    _roomCode = null;
    _playerId = null;
    _lastEventId = 0;
  }

  /// Mesaj gönder
  Future<void> sendMessage({
    required String roomId,
    required String message,
  }) async {
    await _postAction('$_apiUrl/api/mp/rooms/$roomId/chat', {
      'playerId': _playerId,
      'message': message,
    });
  }

  /// Açık odaları getir
  Future<List<Map<String, dynamic>>> getPublicRooms() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_apiUrl/rooms/public/list'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rooms = List<Map<String, dynamic>>.from(data['rooms'] ?? []);
        return rooms;
      }
      return [];
    } catch (e) {
      debugPrint('[Multiplayer] Açık odalar getirilemedi: $e');
      return [];
    }
  }

  // ==================== PRIVATE METHODS ====================

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// Genel POST action helper
  Future<bool> _postAction(String url, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Multiplayer] POST error ($url): $e');
      return false;
    }
  }

  /// JSON parse helper
  Map<String, dynamic>? _tryParseJson(String body) {
    try {
      return json.decode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ==================== LONG POLLING ====================

  void _startPolling() {
    _isPolling = true;
    debugPrint('[Multiplayer] 📡 Long polling başlatıldı');
    _pollLoop();
  }

  void _stopPolling() {
    _isPolling = false;
    debugPrint('[Multiplayer] ⏹️ Long polling durduruldu');
  }

  /// Sürekli poll döngüsü
  Future<void> _pollLoop() async {
    int errorCount = 0;

    while (_isPolling && _roomCode != null) {
      try {
        final url = '$_apiUrl/api/mp/rooms/$_roomCode/poll'
            '?since=$_lastEventId&playerId=$_playerId';

        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));

        if (!_isPolling) break; // Polling durdurulduysa çık

        if (response.statusCode == 200) {
          errorCount = 0;
          final data = json.decode(response.body);
          final events =
              List<Map<String, dynamic>>.from(data['events'] ?? []);

          for (final event in events) {
            final eventId = event['id'] as int;
            if (eventId > _lastEventId) _lastEventId = eventId;
            _dispatchEvent(
              event['type'] as String,
              Map<String, dynamic>.from(event['data']),
            );
          }
        } else if (response.statusCode == 404) {
          // Oda artık mevcut değil
          debugPrint('[Multiplayer] ❌ Oda bulunamadı, polling durduruluyor');
          _errorController.add({'message': 'Oda artık mevcut değil.'});
          _stopPolling();
          break;
        } else {
          errorCount++;
          debugPrint(
              '[Multiplayer] ⚠️ Poll hatası: ${response.statusCode} (deneme: $errorCount)');
          await Future.delayed(
              Duration(seconds: errorCount.clamp(1, 5)));
        }
      } catch (e) {
        if (!_isPolling) break;
        errorCount++;
        debugPrint(
            '[Multiplayer] ⚠️ Poll exception: $e (deneme: $errorCount)');
        await Future.delayed(
            Duration(seconds: errorCount.clamp(1, 10)));
      }
    }
  }

  /// Event'i ilgili stream'e yönlendir
  void _dispatchEvent(String type, Map<String, dynamic> data) {
    debugPrint('[Multiplayer] 📨 Event: $type');
    switch (type) {
      case 'room_updated':
        _roomUpdatedController.add(data);
        break;
      case 'player_joined':
        _playerJoinedController.add(data);
        break;
      case 'player_left':
        _playerLeftController.add(data);
        break;
      case 'game_started':
        _gameStartedController.add(data);
        break;
      case 'player_progress':
        _playerProgressController.add(data);
        break;
      case 'player_completed':
        _playerCompletedController.add(data);
        break;
      case 'game_ended':
        _gameEndedController.add(data);
        break;
      case 'error_msg':
        _errorController.add(data);
        break;
      case 'player_disconnected':
        _playerDisconnectedController.add(data);
        break;
      case 'game_cancelled':
        _gameCancelledController.add(data);
        break;
      case 'chat_message':
        _chatMessageController.add(data);
        break;
      default:
        debugPrint('[Multiplayer] ⚠️ Bilinmeyen event: $type');
    }
  }

  // ==================== HEARTBEAT ====================

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_roomCode != null && _playerId != null) {
        _postAction('$_apiUrl/api/mp/rooms/$_roomCode/heartbeat', {
          'playerId': _playerId,
        });
      }
    });
  }
}
