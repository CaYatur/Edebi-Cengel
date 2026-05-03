import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/topic.dart';

class DataService {
  static const String _dataFileName = 'topics.json';
  
  List<Topic> _topics = [];
  
  // Getters
  List<Topic> get topics => _topics;
  
  // Initialization
  Future<void> initialize() async {
    await _loadTopics();
  }

  // Konuları yükle (sadece assets'ten)
  Future<void> _loadTopics() async {
    try {
      // Assets'ten yükle
      try {
        final jsonString = await rootBundle.loadString('assets/data/$_dataFileName');
        final Map<String, dynamic> data = json.decode(jsonString);
        
        if (data['topics'] != null) {
          _topics = (data['topics'] as List)
              .map((topicJson) => Topic.fromJson(topicJson))
              .toList();
        }
      } catch (e) {
        // Assets'te dosya yoksa boş liste oluştur
        _topics = [];
        print('Assets\'te $_dataFileName bulunamadı: $e');
      }
    } catch (e) {
      print('Konular yüklenirken hata oluştu: $e');
      _topics = [];
    }
  }

  // Topic'i ID'ye göre getir
  Topic? getTopicById(String topicId) {
    try {
      return _topics.firstWhere((topic) => topic.id == topicId);
    } catch (e) {
      return null;
    }
  }

  // Tüm topic'leri getir
  List<Topic> getAllTopics() {
    return List.unmodifiable(_topics);
  }
}
