# 📋 ÇENGEL BULMACA OYUNU - PROJE ANALİZ RAPORU

**Proje Adı:** Çengel Bulmaca 

---

## 📑 İÇİNDEKİLER

1. [Proje Özeti](#proje-özeti)
2. [Teknoloji Yığını](#teknoloji-yığını)
3. [Mimarı ve Yapı](#mimarı-ve-yapı)
4. [Kullanılan Kütüphaneler](#kullanılan-kütüphaneler)
5. [Veri Modelleri](#veri-modelleri)
6. [Bileşenler](#bileşenler)
7. [İş Mantığı ve Akışlar](#iş-mantığı-ve-akışlar)
8. [Geliştirme Ortamı](#geliştirme-ortamı)
9. [Proje Özellikleri](#proje-özellikleri)
10. [Dosya Yapısı](#dosya-yapısı)

---

## 🎯 PROJE ÖZETI

### Proje Tanımı
**Çengel Bulmaca**, Türk edebiyatı ve kültürü temalı, çeşitli konularda bilgi-kültür bulmacaları sunan bir oyundur. Kullanıcılar offline ortamda çalışan uygulamayı Windows, Android, iOS ve Web platformlarında oynayabilirler.

### Ana Özellikler
- **Çok Platform Desteği:** Windows, Android, iOS, Web
- **Çevrimdışı Çalışma:** İnternet bağlantısı gerektirmez
- **Çoklu Konu:** Farklı kategorilerdeki bulmacalar
- **Zorluk Seviyeleri:** 5 farklı zorluk seviyesi (1-5)
- **Medya Desteği:** Video ve ses dosyaları içerebilir
- **Skor Sistemi:** Zorluk seviyesine göre puanlama
- **İçerik Yöneticisi:** Web tabanlı içerik ekleme/düzenleme arayüzü

### Hedef Kullanıcılar
- Öğrenciler ve genel kullanıcılar
- Eğitim kurumları
- Türk edebiyatı ve kültürü meraklıları

---

## 🛠️ TEKNOLOJİ YIĞINI

### Yazılım Dilleri
| Dil | Kullanım Alanı | Sürüm |
|-----|-----------------|-------|
| **Dart** | Mobil ve masaüstü uygulama | 3.9.0+ |
| **Flutter Framework** | UI/UX ve uygulama geliştirme | Çeşitli paketler |
| **JavaScript** | Content Manager (web arayüzü) | ES6+ |
| **HTML/CSS** | Web tabanlı içerik yöneticisi | 5/3 |
| **Kotlin** | Android native bileşenler | Gradle KTS |
| **Swift** | iOS native bileşenler | - |

### Geliştirme Ortamı
- **IDE:** Visual Studio Code (VSCode)
- **Build System:** Flutter SDK + Gradle (Android) + CMake (Windows)
- **Package Manager:** pub (Dart)
- **Version Control:** Git (muhtemelen)
- **Target Platforms:** 
  - Windows (CMake)
  - Android (Gradle)
  - iOS (Xcode)
  - Web

### Sistem Gereksinimleri
- **Flutter SDK:** 3.9.0 veya üzeri
- **Dart SDK:** Flutter ile birlikte
- **Java JDK:** Android derleme için
- **Android Studio:** Android development
- **Xcode:** iOS development (macOS)
- **Visual Studio:** Windows development
- **CMake:** Windows uygulaması derleme

---

## 🏗️ MİMARİ VE YAPISAL TASARIM

### Tasarım Desenleri
1. **Model-View-ViewModel (MVVM)** - Provider pattern ile
2. **State Management** - Provider kütüphanesi kullanarak
3. **Repository Pattern** - DataService sınıfı
4. **Dependency Injection** - Sağlayıcılar aracılığıyla

### Katmanlar

#### 1. **Presentation Layer (Sunum Katmanı)**
- **Screens:** HomeScreen, GameScreen
- **Widgets:** Görsel bileşenler
- **Kullanıcı arayüzü ve etkileşimler**

#### 2. **Business Logic Layer (İş Mantığı Katmanı)**
- **Providers:** GameProvider (state yönetimi)
- **Oyun kuralları, cevap kontrolü, puanlama**

#### 3. **Data Layer (Veri Katmanı)**
- **DataService:** Veri yükleme ve yönetimi
- **Models:** Veri yapıları
- **Local Storage:** Assets'ten JSON dosyaları

### Veri Akışı
```
Assets (topics.json)
        ↓
DataService (Veri yükleme)
        ↓
GameProvider (State Management)
        ↓
Screens & Widgets (UI Rendering)
        ↓
Kullanıcı Etkileşimi
```

---

## 📦 KULLANILAN KÜTÜPHANELER

### Ana Kütüphaneler (pubspec.yaml)

#### UI Framework
```yaml
flutter: ^latest          # Flutter framework
cupertino_icons: ^1.0.8   # iOS stili ikonlar
```

#### State Management
```yaml
provider: ^6.1.5+1        # Reactive state management
```

#### Veri Yönetimi
```yaml
path_provider: ^2.1.5     # Platform belirtileri
sqflite: ^2.4.2           # Yerel SQL veritabanı
path: ^1.9.1              # Dosya yolu yönetimi
```

#### JSON İşlemleri
```yaml
json_annotation: ^4.9.0           # JSON anotasyonları
json_serializable: ^6.8.0         # Kod üretim (dev)
```

#### Medya Oynatıcı
```yaml
video_player: ^2.10.0             # Video oynatma
audioplayers: ^6.5.0              # Ses oynatma
```

#### UI Bileşenleri
```yaml
flutter_staggered_grid_view: ^0.7.0  # Dinamik grid layout
```

#### Kod Üretimi (Dev)
```yaml
build_runner: ^2.4.12             # Kod üretim aracı
flutter_lints: ^5.0.0             # Linting kuralları
```

---

## 📊 VERI MODELLERİ

### 1. **Topic (Konu)**
Konuları temsil eden temel model.

```dart
class Topic {
  String id;                        // Benzersiz tanımlayıcı
  String name;                      // Konu adı (örn: "Türk Edebiyatı")
  String description;               // Açıklama
  List<PuzzleSet> puzzleSets;      // Bulmaca setleri
  String? iconPath;                 // Opsiyonel ikon yolu
}
```

**Alanlar:**
- `id`: Benzersiz konu kimliği
- `name`: Görüntülenmek üzere konu adı
- `description`: Konunun açıklaması
- `puzzleSets`: Konuya ait bulmaca setleri
- `iconPath`: Opsiyonel ikon dosyası

### 2. **PuzzleSet (Bulmaca Seti)**
Bir konuya ait bulmaca grubunu temsil eder.

```dart
class PuzzleSet {
  String id;                        // Benzersiz tanımlayıcı
  String title;                     // Başlık
  int difficulty;                   // Zorluk seviyesi (1-5)
  List<PuzzleClue> clues;          // Sorular/İpuçları
  String? description;              // Opsiyonel açıklama
}
```

**Özellikler:**
- **Zorluk Seviyeleri:** 1 (en kolay) - 5 (en zor)
- **Dinamik Soruları Destekler:** Setler birden fazla soru içerebilir

### 3. **PuzzleClue (Bulmaca İpucu/Soru)**
Münferit soru ve cevap setini temsil eder.

```dart
class PuzzleClue {
  String id;                        // Benzersiz soru kimliği
  String question;                  // Soru metni
  String answer;                    // Doğru cevap
  int visibleLetterCount;           // Gösterilen harf sayısı
  List<int> visiblePositions;       // Belirli pozisyonlar
  String? mediaPath;                // Opsiyonel medya dosyası
  String? mediaType;                // 'video' veya 'audio'
}
```

**Temel Özellikler:**
- **Maskeleme:** `_maskAnswerByCount()` - İlk N harfi gösterir
- **Pozisyon Tabanlı Maskeleme:** Spesifik pozisyonları gösterir
- **Cevap Doğrulama:** Türkçe karakterleri normalize ederek kontrol
- **Medya Desteği:** Video/ses dosyaları için opsiyonel

**Normalizasyon (Türkçe İçin):**
```
ı → i, İ → i, I → i
ğ → g, Ğ → g
ü → u, Ü → u
ş → s, Ş → s
ö → o, Ö → o
```

### 4. **GameSession (Oyun Oturumu)**
Kullanıcının bir oyun seansını takip eder.

```dart
class GameSession {
  String id;                        // Oturum kimliği
  String topicId;                   // Oynanılan konu
  String topicName;                 // Konu adı
  List<String> puzzleSetIds;        // Bulmaca set kimlikleri
  Map<String, bool> completedPuzzles;  // Tamamlanan bulmacalar
  Map<String, int> scores;          // Bulmaca puanları
  DateTime startTime;               // Başlama zamanı
  DateTime? endTime;                // Bitiş zamanı
  bool isCompleted;                 // Tamamlanma durumu
}
```

**Hesaplanmış Özellikler:**
- `totalScore`: Toplam puan
- `completionPercentage`: Tamamlanma yüzdesi
- `totalDuration`: Toplam süre

---

## 🎨 BILEŞENLER (COMPONENTS)

### A. EKRANLAR (Screens)

#### 1. **HomeScreen**
Uygulamanın giriş ekranı. Mevcut konuları listeler.

**Fonksiyonlar:**
- Konuların yüklenmesi ve başlatılması
- Konu seçimi
- Hata durumunda bilgi gösterme
- Yükleme durumunda spinner gösterme

**State Management:** GameProvider kullanır

#### 2. **GameScreen**
Ana oyun ekranı. Soruları gösterir ve cevapları alır.

**Komponenler:**
- Soru gösterimi
- Medya oynatıcı (opsiyonel)
- Cevap giriş alanı
- Navigasyon butonları
- İlerleme göstergesi
- Skor gösterimi

---

### B. GÖRSEL BİLEŞENLER (Widgets)

#### 1. **ClueWidget**
Soru/İpucu gösterimi için.

**Görüntü:**
- Soru metni
- Görsel olarak çengel bulmaca

#### 2. **AnswerBoxesWidget**
Çengel bulmaca cevapını kutular halinde gösterir.

**Özellikler:**
- Görünür harfleri vurgular
- Maskelenen harfleri (`_`) gösterir
- Düzgün yerleşim

#### 3. **AnswerInputWidget & AnswerInputWidgetNew**
Kullanıcı cevap girişi için.

**Özellikler:**
- Metin giriş alanı
- Klavye desteği
- Gönder buttonu
- Enter tuşu desteği

#### 4. **CustomKeyboard & KeyboardWidget**
Özel Türkçe klavye (opsiyonel).

**Özellikler:**
- Türkçe karakterler (ç, ğ, ş, ü, ö, ı)
- Dokunmatik treptin desteği

#### 5. **MediaPlayerWidget**
Ses ve video oynatıcı.

**Destekler:**
- Video oynatma (video_player)
- Ses oynatma (audioplayers)
- Medya iletişim kontrolleri

#### 6. **MediaDialog**
Medya gösterim diyalogu.

#### 7. **ProgressIndicatorWidget**
Oyun ilerlemesi göstergesi.

**Gösterir:**
- Tamamlanan soru sayısı
- Kalan soru sayısı
- İlerleme yüzdesi (görsel)

---

### C. SAHNELİ LAYOUT

Oyun ekranında sayfa geçişleri için `PageController` kullanılır.
- Soruları yatay olarak geçişlemenizi sağlar
- Hızlı navigasyon

---

## 🎮 İŞ MANTIGI VE AKIŞLAR

### 1. OYUN İNİSİYALİZASYONU

```
Uygulama Başlatılır
    ↓
HomeScreen Yüklenir
    ↓
GameProvider.initialize() Çağrılır
    ↓
DataService.loadTopics()
    ↓
assets/data/topics.json Okunur
    ↓
JSON → Dart Nesnelerine Dönüştürülür
    ↓
Konular UI'da Görüntülenir
```

### 2. OYUN BAŞLATMA

```
Konu Seçilir
    ↓
GameProvider.startNewGame(topicId) Çağrılır
    ↓
10 Rastgele Soru Seçilir (Tüm Zorluklardan)
    ↓
PuzzleClue.maskedAnswer Hesaplanır
    ↓
GameScreen Açılır
    ↓
İlk Soru Gösterilir
```

### 3. CEVAP KONTROL SÜRECİ

```
Kullanıcı Cevap Yazar
    ↓
Gönder Butonu Basılır
    ↓
GameProvider.checkAnswer() Çağrılır
    ↓
PuzzleClue.checkAnswer() ile Doğru/Yanlış Kontrolü
    ↓
Türkçe Karakterler Normalleştirilir
    ↓
Boşluklar Kaldırılır
    ↓
Büyük/Küçük Harf Farkı Yoksayılır
```

### 4. CEVAP DOĞRULAMA ALGORİTMASI

**Normalizasyon Adımları:**
1. Tüm harfleri küçük harfe çevir
2. Başında/sonunda boşlukları kaldır
3. Tüm iç boşlukları kaldır
4. Türkçe karakterleri standartlaştır

**Örnek:**
```
Giriş: "  İNCE MEMEd  "
1. Küçük: "  ince memeded  "
2. Trim: "ince memeded"
3. Boşluk: "incememeded"
4. Türkçe: "incemededed"

Cevap: "İNCE MEMED"
1. Küçük: "ince memed"
2. Trim: "ince memed"
3. Boşluk: "incememed"
4. Türkçe: "incememed"

Karşılaştırma: "incememeded" ≠ "incememed" → YANLIŞ
```

### 5. PUANLAMA HESAPLAMASI

```
Skor = 10 × Zorluk_Seviyesi
```

**Örnek:**
- Zorluk 1: 10 puan
- Zorluk 3: 30 puan
- Zorluk 5: 50 puan

---

## 💾 VERİ YÖNETİMİ

### DataService (Veri Servisi)

```dart
class DataService {
  List<Topic> _topics = [];
  
  // Konuları assets'ten yükle
  Future<void> _loadTopics()
  
  // Konu ID'ye göre getir
  Topic? getTopicById(String topicId)
}
```

### Veri Kaynağı

#### 1. **Birincil:** assets/data/topics.json
```json
{
  "topics": [
    {
      "id": "edebiyat",
      "name": "Türk Edebiyatı",
      "description": "...",
      "puzzleSets": [...]
    }
  ]
}
```

#### 2. **Local Storage** (İsteğe Bağlı)
- `sqflite` ile yerel veritabanı
- Oyun seansları ve istatistikler
- Path provider ile dosya yönetimi

---

## 🔌 STATE MANAGEMENT

### GameProvider (ChangeNotifier)

**Durumlar (State):**
```dart
List<Topic> _topics              // Yüklenen konular
Topic? _currentTopic             // Oynadığı konu
List<PuzzleClue> _currentQuestions   // Seçilen sorular
int _currentQuestionIndex        // Mevcut soru indeksi
Map<String, String> _userAnswers     // Doğru cevaplar
Map<String, String> _userInputs      // Yazılan girdiler
bool _isLoading                  // Yükleme durumu
String? _error                   // Hata mesajı
```

**Ana Metodlar:**
- `initialize()` - İlk veriler yüklendi
- `startNewGame(topicId)` - Yeni oyun başlatma
- `checkAnswer(answer)` - Cevap doğrulama
- `nextQuestion()` - Sonraki soruya git
- `previousQuestion()` - Önceki soruya dön
- `saveUserInput()` - Kullanıcı girişini kaydet
- `getGameStats()` - Oyun istatistikleri

**Bildirim Mekanizması:**
- `notifyListeners()` - UI'ı güncelle
- Consumers otomatik olarak dinler

---

## 📱 PLATFORM SPESIFIK YAPIKLANDIRMALAR

### Windows (CMake)
```cmake
CMakeLists.txt              # Windows uygulama derleme
flutter/CMakeLists.txt      # Flutter plugin yönetimi
runner/                     # Native Windows uygulaması
```

### Android (Gradle)
```gradle
android/build.gradle.kts         # Kök build yapılandırması
android/app/build.gradle.kts     # Uygulama spesifik
android/settings.gradle.kts      # Module ayarları
gradle/wrapper/                  # Gradle sarmalayıcısı
```

### iOS (Xcode)
```swift
ios/Runner/                      # iOS uygulaması
ios/Runner/AppDelegate.swift     # Ana iOS delegesi
ios/Runner.xcodeproj/            # Xcode proje dosyaları
```

---

## 🌐 İÇERİK YÖNETİCİSİ (Web)

### Teknoloji
- **HTML5** - Yapı
- **CSS3** - Tasarım
- **JavaScript ES6+** - İş mantığı
- **LocalStorage** - Veri saklama

### Özellikler
1. **Konu Yönetimi**
   - Konu ekleme
   - Konu düzenleme
   - Konu silme

2. **Bulmaca Yönetimi**
   - Bulmaca seti oluşturma
   - Soru ekleme
   - Medya yönetimi

3. **İçe/Dışa Aktarma**
   - JSON formatında dışa aktarma
   - JSON içe aktarma
   - Yedekleme

4. **Canlı Önizleme**
   - Çengel bulmaca görünümü
   - Soru ve cevap kontrolü

---

## 🛠️ GELİŞTİRME ORTAMI

### Visual Studio Code Kurulumu

#### Tavsiye Edilen Uzantılar
```
Dart (Dart Code)
Flutter
Provider Snippet
JSON Editor
Pubspec Assist
```

#### Yapılandırma Dosyaları
- `.vscode/settings.json` - VSCode ayarları
- `.vscode/launch.json` - Hata ayıklama konfigürasyonu
- `.vscode/tasks.json` - Build görevleri (opsiyonel)

### Proje Yapılandırması

#### pubspec.yaml
```yaml
name: cengel_bulmaca
description: Çengel bulmaca oyunu
version: 1.0.0+1

environment:
  sdk: ^3.9.0

dependencies:
  # UI Framework
  flutter: ^latest
  cupertino_icons: ^1.0.8
  
  # State Management
  provider: ^6.1.5+1
  
  # Data
  path_provider: ^2.1.5
  sqflite: ^2.4.2
  path: ^1.9.1
  
  # JSON
  json_annotation: ^4.9.0
  
  # Media
  video_player: ^2.10.0
  audioplayers: ^6.5.0
  
  # UI
  flutter_staggered_grid_view: ^0.7.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.12
  json_serializable: ^6.8.0

flutter:
  uses-material-design: true
  assets:
    - assets/data/
    - assets/media/
```

#### analysis_options.yaml
```yaml
# Linting kuralları (Flutter standartları)
```

---

## 📂 DOSYA YAPISI (DETAYLı)

```
GameKelime/                              # Proje Kökü
├── PROJE_RAPORU.md                      # Bu Dosya
├── README.md                            # Proje Açıklaması
├── KULLANIM_KILAVUZU.md                 # Kullanıcı Kılavuzu
│
├── cengel_bulmaca/                      # Flutter Uygulaması
│   ├── pubspec.yaml                     # Bağımlılıklar
│   ├── analysis_options.yaml            # Linting Kuralları
│   ├── cengel_bulmaca.iml               # IDE Dosyası
│   │
│   ├── lib/                             # Kaynak Kodu
│   │   ├── main.dart                    # Uygulama Entry Point
│   │   ├── main_new.dart                # Alternatif Entry Point
│   │   │
│   │   ├── models/                      # Veri Modelleri
│   │   │   ├── topic.dart               # Konu Modeli
│   │   │   ├── topic.g.dart             # JSON Kod Üretimi
│   │   │   ├── puzzle_set.dart          # Bulmaca Seti Modeli
│   │   │   ├── puzzle_set.g.dart        # JSON Kod Üretimi
│   │   │   ├── puzzle_clue.dart         # Soru Modeli
│   │   │   ├── puzzle_clue.g.dart       # JSON Kod Üretimi
│   │   │   ├── game_session.dart        # Oyun Oturumu Modeli
│   │   │   └── game_session.g.dart      # JSON Kod Üretimi
│   │   │
│   │   ├── services/                    # İş Mantığı Servisleri
│   │   │   └── data_service.dart        # Veri Yükleme Servisi
│   │   │
│   │   ├── providers/                   # State Management
│   │   │   └── game_provider.dart       # GameProvider (ChangeNotifier)
│   │   │
│   │   ├── screens/                     # Ekranlar
│   │   │   ├── home_screen.dart         # Ana Ekran
│   │   │   └── game_screen.dart         # Oyun Ekranı
│   │   │
│   │   └── widgets/                     # UI Bileşenleri
│   │       ├── clue_widget.dart         # Soru Gösterimi
│   │       ├── answer_boxes_widget.dart # Çengel Kutular
│   │       ├── answer_input_widget.dart # Cevap Girişi
│   │       ├── answer_input_widget_new.dart # Yeni Cevap Girişi
│   │       ├── custom_keyboard.dart     # Türkçe Klavye
│   │       ├── keyboard_widget.dart     # Klavye Widget
│   │       ├── media_player_widget.dart # Medya Oynatıcı
│   │       ├── media_dialog.dart        # Medya Diyalogu
│   │       └── progress_indicator_widget.dart # İlerleme Göstergesi
│   │
│   ├── assets/                          # Statik Kaynaklar
│   │   ├── data/
│   │   │   └── topics.json              # Bulmaca Veri Dosyası
│   │   └── media/                       # Video/Ses Dosyaları
│   │
│   ├── android/                         # Android Platformu
│   │   ├── build.gradle.kts             # Kök Build Config
│   │   ├── settings.gradle.kts          # Module Ayarları
│   │   ├── gradle.properties            # Gradle Özellikleri
│   │   ├── gradlew                      # Unix Gradle Wrapper
│   │   ├── gradlew.bat                  # Windows Gradle Wrapper
│   │   ├── local.properties             # Yerel Yapılandırma
│   │   ├── app/                         # Ana Uygulama Modülü
│   │   │   ├── build.gradle.kts         # Uygulama Build Config
│   │   │   └── src/                     # Android Kaynak Kodu
│   │   └── gradle/                      # Gradle Yapılandırması
│   │       └── wrapper/                 # Gradle Wrapper JAR'ları
│   │
│   ├── ios/                             # iOS Platformu
│   │   ├── Runner.xcworkspace/          # Xcode Workspace
│   │   ├── Runner.xcodeproj/            # Xcode Projesi
│   │   ├── Runner/                      # Ana Uygulama
│   │   │   ├── AppDelegate.swift        # iOS App Delegate
│   │   │   ├── Info.plist               # iOS Yapılandırması
│   │   │   └── Assets.xcassets/         # iOS Assets
│   │   ├── RunnerTests/                 # Test Dosyaları
│   │   └── Flutter/                     # Flutter Config
│   │       ├── AppFrameworkInfo.plist   # Framework Info
│   │       ├── Debug.xcconfig           # Debug Config
│   │       └── Release.xcconfig         # Release Config
│   │
│   ├── windows/                         # Windows Platformu
│   │   ├── CMakeLists.txt               # CMake Build Script
│   │   ├── flutter/                     # Flutter Plugin Config
│   │   │   └── generated_plugin_registrant.cc
│   │   └── runner/                      # Native Windows App
│   │
│   ├── web/                             # Web Platformu
│   │   ├── index.html                   # Web Ana Sayfa
│   │   ├── manifest.json                # Web Manifest
│   │   └── icons/                       # Web İkonları
│   │
│   └── build/                           # Derlenmiş Çıktı
│       ├── flutter_assets/              # Flutter Assets
│       ├── windows/                     # Windows Build
│       └── reports/                     # Build Raporları
│
└── content_manager/                     # Web İçerik Yöneticisi
    └── index.html                       # Tek Sayfa Uygulama
        ├── CSS Stilleri
        ├── JavaScript Kod
        └── LocalStorage Yönetimi
```

---

## 🎯 PROJE ÖZELLİKLERİ

### Mevcut Özellikler
- ✅ Çok platform desteği (Windows, Android, iOS, Web)
- ✅ Çeşitli konularda bulmacalar
- ✅ 5 zorluk seviyesi
- ✅ Çengel bulmaca sistemi (maskeleme)
- ✅ Skor ve istatistik sistemi
- ✅ Medya desteği (video/ses) - opsiyonel
- ✅ Web tabanlı içerik yöneticisi
- ✅ Offline çalışma
- ✅ Türkçe karakter desteği

### Geliştirilebilir Alanlar
- 📌 Veritabanı entegrasyonu (sqflite)
- 📌 Sunucudan veri senkronizasyonu
- 📌 Çok oyunculu mod
- 📌 Başarı / Badge sistemi
- 📌 Zorluk adaptif (AI)
- 📌 Ses arama
- 📌 Sosyal paylaşım
- 📌 Animasyonlar
- 📌 Performans optimizasyonu

---

## 🔄 KODU ÜRETİMİ (Code Generation)

### Build Runner Kullanımı

**Kod Üretimi İçin Komutlar:**
```bash
# Kod üret
dart run build_runner build

# İzleme modunda kod üret
dart run build_runner watch

# Temizle
dart run build_runner clean
```

### Üretilen Dosyalar
- `*.g.dart` - JSON serialization/deserialization
- Model sınıflarına ek metodlar ekler
  - `fromJson()` - JSON → Dart
  - `toJson()` - Dart → JSON

**Örnek:**
```dart
// topic.dart
@JsonSerializable()
class Topic { ... }

// topic.g.dart (Otomatik Üretilir)
class _$TopicFromJson { ... }
class _$TopicToJson { ... }
```

---

## 📊 VERİ AKIŞI DİYAGRAMI

```
┌─────────────────────────────────────────────────────────┐
│                   UYGULAMA BAŞLANGICI                    │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              main.dart - runApp()                        │
│          CengelBulmacaApp() Oluşturulur                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│        ChangeNotifierProvider                           │
│         (GameProvider Sağla)                            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              HomeScreen Göster                           │
│      - Yükleme durumunu kontrol et                      │
│      - Konuları listele                                 │
└────────────────────┬────────────────────────────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
    ▼ (Konu Seç)       ▼ (Hata)
    GameProvider      Error Widget
    .startNewGame()      Göster

┌─────────────────────────────────────────────────────────┐
│        GameProvider.startNewGame(topicId)               │
│  - Konu seç                                             │
│  - 10 rastgele soru al                                  │
│  - State güncelle                                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              GameScreen Aç                              │
│  - Soru göster                                          │
│  - Medya (varsa)                                        │
│  - Cevap giriş alanı                                    │
│  - Kontrol butonları                                    │
└────────────────────┬────────────────────────────────────┘
                     │
      ┌──────────────┴──────────────┐
      │                             │
▼ (Cevap Gönder)          ▼ (Navigasyon)
GameProvider.check       .nextQuestion()
Answer()                .previousQuestion()

┌─────────────────────────────────────────────────────────┐
│       PuzzleClue.checkAnswer()                          │
│  - Normalleştir                                         │
│  - Karşılaştır                                          │
│  - Doğru/Yanlış dön                                     │
└────────────────────┬────────────────────────────────────┘
                     │
      ┌──────────────┴──────────────┐
      │                             │
▼ (Doğru)                    ▼ (Yanlış)
- Skor Ekle               - Hata Mesajı
- Sonraki Soruya Git      - Yeniden Deneyin
- UI Güncelle             - Input'u Temizle

┌─────────────────────────────────────────────────────────┐
│       Tüm Sorular Tamamlanmış mı?                       │
└────────────────────┬────────────────────────────────────┘
                     │
      ┌──────────────┴──────────────┐
      │                             │
▼ (Hayır)                    ▼ (Evet)
- Sonraki Soru            - Sonuç Ekranı
- Göster                  - Toplam Skor
- Devam Et                - Home'a Dön
```

---

## 🚀 PERFORMANS NOTLARI

### Optimizasyonlar
1. **Lazy Loading:** Konuları ihtiyaç duyulduğunda yükle
2. **Image Caching:** Flutter otomatik image caching
3. **State Management:** Provider ile etkili state yönetimi
4. **JSON Serialization:** build_runner ile hızlı serialization

### Potansiyel Darboğazlar
- Büyük JSON dosyaları (1000+ bulmaca)
- Medya dosyaları (video/ses çözünürlüğü)
- Ekran boyutuna responsive design

---

## 🔐 GÜVENLİK NOTLARI

### Mevcut Güvenlik
- ✅ Offline çalışma (internet riskleri yok)
- ✅ Veri sadece client tarafında
- ✅ JSON validasyonu

### Geliştirilebilir Güvenlik
- 📌 JSON şifrelemesi (medya dosyaları için)
- 📌 Cihaz depolaması şifreleme
- 📌 İçerik Yöneticisi kimlik doğrulaması
- 📌 API güvenliği (sunucu entegrasyonu ile)

---

## 📚 REFERANSLAR VE KAYNAKLAR

### Flutter Dokümantasyonu
- https://flutter.dev/docs
- https://pub.dev (Package Manager)

### Kullanılan Paketler
- **Provider:** https://pub.dev/packages/provider
- **Video Player:** https://pub.dev/packages/video_player
- **AudioPlayers:** https://pub.dev/packages/audioplayers
- **SQLite:** https://pub.dev/packages/sqflite
- **JSON Serializable:** https://pub.dev/packages/json_serializable

### IDE & Tools
- **Flutter SDK:** https://flutter.dev/docs/get-started/install
- **VS Code:** https://code.visualstudio.com/
- **Dart Extensions:** VS Code Market Place

---

## 📝 SON NOTLAR

### Proje Özeti
Çengel Bulmaca, modern Flutter mimarisi kullanarak geliştirilen, çok platformlu, yüksek performanslı bir eğitim oyunudur. Provider state management deseni ve JSON tabanlı veri yönetimi ile, kod kalitesi ve bakım edilebilirliği yüksek seviyede tutmaktadır.

### Geliştirme Tavsiyesi
- VSCode ile geliştirme önerilir
- DevTools kullanarak UI/Performance debugging
- Hot Reload kullanarak hızlı geliştirme döngüsü
- Linting rules'e uygun kod yazma (flutter_lints)

### Kod Kalitesi
- ✅ SOLID prensiplerini izler
- ✅ Temiz mimarı yapısı
- ✅ Type-safe (null safety)
- ✅ Hata yönetimi
- ✅ Türkçe karakter desteği
