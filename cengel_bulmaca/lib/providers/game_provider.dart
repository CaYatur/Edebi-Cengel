import 'package:flutter/foundation.dart';
import '../models/topic.dart';
import '../models/puzzle_clue.dart';
import '../services/data_service.dart';

class GameProvider extends ChangeNotifier {
  final DataService _dataService = DataService();
  
  List<Topic> _topics = [];
  Topic? _currentTopic;
  List<PuzzleClue> _currentQuestions = [];
  int _currentQuestionIndex = 0;
  Map<String, String> _userAnswers = {};
  Map<String, String> _userInputs = {}; // Kullanıcının yazdığı harfler
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Topic> get topics => _topics;
  Topic? get currentTopic => _currentTopic;
  List<PuzzleClue> get currentQuestions => _currentQuestions;
  int get currentQuestionIndex => _currentQuestionIndex;
  PuzzleClue? get currentQuestion => _currentQuestions.isNotEmpty 
      ? _currentQuestions[_currentQuestionIndex] 
      : null;
  Map<String, String> get userAnswers => _userAnswers;
  Map<String, String> get userInputs => _userInputs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  bool get isLastQuestion => _currentQuestions.isNotEmpty && 
      _currentQuestionIndex >= _currentQuestions.length - 1;
      
  bool get isGameCompleted => _currentQuestions.isNotEmpty && 
      _userAnswers.length == _currentQuestions.length;

  // Initialization
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _dataService.initialize();
      _topics = _dataService.topics;
      _setError(null);
    } catch (e) {
      _setError('Veriler yüklenirken hata oluştu: $e');
    }
    _setLoading(false);
  }

  // Yeni oyun başlat
  Future<void> startNewGame(String topicId) async {
    _setLoading(true);
    try {
      final topic = _topics.firstWhere((t) => t.id == topicId);
      _currentTopic = topic;
      
      // Toplam 10 tane rastgele soru al (tüm zorluklardan karışık)
      _currentQuestions = topic.getRandomQuestions(maxQuestions: 10);
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _userInputs.clear();
      
      _setError(null);
    } catch (e) {
      _setError('Oyun başlatılırken hata oluştu: $e');
    }
    _setLoading(false);
  }

  // Kullanıcı girişini kaydet (tam olmasa bile)
  void saveUserInput(String questionId, String input) {
    _userInputs[questionId] = input;
    notifyListeners();
  }

  // Belirli bir soru için kullanıcı girişini getir
  String getUserInput(String questionId) {
    return _userInputs[questionId] ?? '';
  }

  // Soru cevaplandı mı kontrol et
  bool isQuestionAnswered(String questionId) {
    return _userAnswers.containsKey(questionId);
  }

  // Cevap kontrol et
  bool checkAnswer(String answer) {
    final question = currentQuestion;
    if (question == null) return false;

    final isCorrect = question.checkAnswer(answer);
    if (isCorrect) {
      _userAnswers[question.id] = answer;
      notifyListeners();
    }
    
    return isCorrect;
  }

  // Sonraki soruya geç
  void nextQuestion() {
    if (_currentQuestions.isNotEmpty && _currentQuestionIndex < _currentQuestions.length - 1) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  // Önceki soruya geç
  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  // Oyunu tamamla
  Future<void> completeGame() async {
    if (_currentTopic == null || _currentQuestions.isEmpty) return;
    
    // Bu basit implementasyon - gelecekte daha kompleks olabilir
    notifyListeners();
  }

  // Skor hesapla
  int calculateScore() {
    if (_currentQuestions.isEmpty) return 0;
    return _userAnswers.length * 10; // Her doğru cevap 10 puan
  }

  // Oyunu sıfırla
  void _resetCurrentGame() {
    _currentTopic = null;
    _currentQuestions = [];
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Medya dosyası var mı kontrol et
  bool hasMedia(String questionId) {
    try {
      final question = _currentQuestions.firstWhere((q) => q.id == questionId);
      return question.mediaPath != null;
    } catch (e) {
      return false;
    }
  }

  // Medya tipini getir
  String? getMediaType(String questionId) {
    try {
      final question = _currentQuestions.firstWhere((q) => q.id == questionId);
      return question.mediaType;
    } catch (e) {
      return null;
    }
  }

  // Oyun istatistiklerini getir
  Map<String, dynamic> getGameStats() {
    if (_currentQuestions.isEmpty) return {};
    
    return {
      'totalQuestions': _currentQuestions.length,
      'answeredQuestions': _userAnswers.length,
      'score': calculateScore(),
      'completionPercentage': (_userAnswers.length / _currentQuestions.length * 100).round(),
      'isCompleted': isGameCompleted,
    };
  }
}
