# Edebi Çengel - Proje Özeti

**Edebi Çengel**, Türk edebiyatı ve kültürü temalı, çoklu oyuncu desteğine sahip modern bir çengel bulmaca uygulamasıdır. Flutter teknolojisi kullanılarak geliştirilen platform, Windows, Android, iOS ve Web ortamlarında sorunsuzca çalışırken aynı zamanda tamamen offline mod desteği sunmaktadır.

---

## 🎯 Temel Özellikler

### 1. **Çengel Bulmaca Sistemi**
- Belirli harfler gösterilerek, oyuncuların diğer harfleri tahmin ederek cevabı tamamladığı mekanik
- Dinamik zorluk seviyeleri (1-5 arasında ayarlanabilir)
- Türkçe karakter desteği (Ç, Ğ, İ, Ö, Ş, Ü otomatik normalizasyon)

### 2. **Çoklu Oyuncu - Real-time Multiplayer** ⭐
- **REST-API** tabanlı real-time bağlantı
- Oda sistemi: Oyuncular oda oluşturabilir veya mevcut odalara katılabilir
- Canlı skor takibi ve oyuncu durumu güncellemeleri
- Liderlik tablosu ve sıralamalar
- Host kontrolü: Oda sahibi ayarları kontrol eder
- Herkese açık/özel oda seçeneği

### 3. **AI Bulmaca Üretimi** ⭐
- `dynamic_crossword_generator.dart` ile dinamik bulmaca oluşturma
- AI Puzzle Screen modu
- Sonsuz tekrarlanan oyun deneyimi

### 4. **Oyuncu Profil & İstatistikler**
- Kullanıcı kaydı ve giriş sistemi (JWT token-based)
- Istatistik senkronizasyonu (offline oynanıp online senkronize edilebilir)
- Başarı rozetleri (badges) ve seviyeler
- Oynanan kategoriler takibi
- En hızlı bulmaca rekordu

### 5. **Liderlik Tablosu**
- Dönem filtrelemesi: Tüm zamanlar, aylık, haftalık
- Oyuncu sıralaması ve medalet (🥇🥈🥉)
- Seviye sistemi (1-8 seviye)
- Rütbe sistemi (Yeni Başlayan → Edebiyat Efsanesi)
- Web arayüzü (`/leaderboard/web`)

### 6. **Özelleştirme & Ayarlar**
- Dinamik tema sistemi
- Ses ve animasyon ayarları
- Sınıf zorluk seviyeleri
- Bulmaca kelime sayısı ayarı

### 7. **Medya Desteği**
- Video oynatıcı (video_player 2.8.1)
- Ses oynatıcı (audioplayers 6.1.0)
- Medya klasörü entegrasyonu

---

## 💻 Teknik Mimarı

### **Frontend**
- **Framework**: Flutter (Dart 3.5.0+)
- **State Management**: Provider (6.1.5+1)
- **UI Bileşenleri**: Material Design + Custom Widgets
- **Grid Layout**: flutter_staggered_grid_view

### **Backend**
- **Runtime**: Node.js (Express.js)
- **Real-time**: Socket.IO
- **Kimlik Doğrulama**: JWT (JSON Web Tokens)
- **Veri Depolama**: JSON dosyaları
- **Şifreleme**: bcryptjs

### **Veri Yönetimi**
- **Yerel Depolama**: SQLite + SharedPreferences
- **Senkronizasyon**: API ve offline-first yaklaşımı
- **JSON Serialization**: json_serializable

### **Platformlar**
- **Android**: Gradle build system
- **Windows**: CMake
- **iOS**: Xcode (İçerik desteklenmiş, App Store kısıtlamaları var)
- **Web**: Flutter Web

---

## 📦 Veri Modelleri

```
├── CrosswordPuzzle          # Ana bulmaca modeli
├── CrosswordWord            # Bulmacadaki kelimeler
├── CrosswordCategory        # Konular ve kategoriler
├── CrosswordClue            # İpuçları
├── PuzzleSet                # Bulmaca serileri
├── PlayerStats              # Oyuncu istatistikleri
├── GameBadge                # Başarı rozetleri
├── GameSession              # Oturum geçmişi
├── MultiplayerPlayer        # Multiplayer oyuncu bilgisi
├── AppSettings              # Uygulama ayarları
└── AppTheme                 # Tema konfigürasyonları
```

---

## 🖥️ Ekranlar & Modüller

| Ekran | Açıklama |
|-------|----------|
| **CrosswordHomeScreen** | Ana menu - kategori seçimi, çoklu oyuncu, liderlik tablosu |
| **CrosswordGameScreen** | Tekli oyun ekranı - bulmaca çözme mekaniksi |
| **MultiplayerLobbyScreen** | Çoklu oyuncu arayı - oda oluştur/katıl |
| **MultiplayerRoomScreen** | Oda yönetimi - oyuncular, ayarlar, başlat düğmesi |
| **MultiplayerGameScreen** | Canlı multiplayer oyun |
| **AIPuzzleScreen** | AI tarafından üretilen bulmacalar |
| **LeaderboardScreen** | Sıralamalar ve istatistikler |
| **AuthScreen** | Giriş ve kayıt |
| **SettingsScreen** | Uygulama ayarları |

---

## 🔐 Backend API Endpoints

```
POST   /auth/register           # Hesap oluşturma
POST   /auth/login              # Giriş
GET    /user/profile            # Profil bilgisi (JWT gerekli)
POST   /user/stats/sync         # İstatistik senkronizasyonu (JWT gerekli)
GET    /leaderboard             # API leaderboard
GET    /leaderboard/web         # Web leaderboard HTML
GET    /room/:code              # Oda bilgisi
GET    /rooms/count             # Aktif odaların sayısı
GET    /rooms/public/list       # Herkese açık odaları listele
```

---

## 🔌 Socket.IO Events (Real-time)

**Server → Client:**
- `room_created` - Oda oluşturuldu
- `room_joined` - Oyuncu odaya katıldı
- `room_updated` - Oda durumu güncellendi
- `player_joined` - Yeni oyuncu katıldı
- `game_started` - Oyun başladı
- `game_ended` - Oyun bitti (sonuçlarla)
- `player_progress` - Oyuncu ilerledi
- `player_completed` - Oyuncu bitti
- `player_left` - Oyuncu ayrıldı
- `chat_message` - Sohbet mesajı

**Client → Server:**
- `create_room` - Oda oluştur
- `join_room` - Odaya katıl
- `update_settings` - Ayarları güncelle
- `toggle_ready` - Hazır durumunu değiştir
- `start_game` - Oyunu başlat
- `update_progress` - İlerleme bildir
- `player_finished` - Oyunu bitir
- `leave_room` - Odadan ayrıl

---

## 📊 Sunucu Özellikleri

- **Port**: 9889 (varsayılan)
- **Rate Limiting**: IP bazlı kayıt/giriş sınırlaması
- **Oda Yönetimi**: Otomatik eski odaları temizleme (30 dakika)
- **Sıralamalar**: Haftalık, aylık, tüm zamanlar filtrelemesi
- **Responsive Web**: Mobile ve desktop uyumlu leaderboard sayfası

---

## 🚀 Kurulum & Çalıştırma

### Flutter Uygulaması
```bash
cd cengel_bulmaca
flutter pub get
flutter run
```

### Backend Sunucu
```bash
cd server
npm install
npm start
```

### İçerik Yönetimi
- Web tab tarayıcısında `content_manager/index.html` dosyasını açın
- Demo verisi yükleyin veya kendi içeriğinizi oluşturun
- JSON dosyasını `assets/data/topics.json` olarak kaydedin

---

## 🎓 Hedef Kitle

- 📚 Türk edebiyatı meraklıları
- 🎮 Bulmaca oynayanlar
- 🏫 Eğitim kurumları
- 👥 Sosyal oyun oynayan kullanıcılar

---

## ⭐ Öne Çıkan Avantajlar

✅ **Omnichannel**: Windows, Android, iOS, Web desteği (1 codebase)  
✅ **Offline-First**: İnternet olmadan tam oyun deneyimi  
✅ **Real-time Multiplayer**: Socket.IO ile anlık çok oyunculuk  
✅ **AI Desteği**: Dinamik bulmaca üretimi  
✅ **Sınıflandırma Sistemi**: Liderlik tablosu, yazılımlar ve rütbeler  
✅ **Türkçe Odaklı**: Tam Türkçe karakter desteği  
✅ **Profesyonel Mimarı**: MVVM + Repository Pattern + Dependency Injection  
✅ **Responsive Design**: Tüm ekran boyutlarına uyumlu  

---

## 📈 Gelişmiş Özellikler

- Ses efektleri ve animasyonlar
- Tema özelleştirmesi (koyu/açık mod)
- Hint sistemi
- Oyun oturumu geçmişi
- Senkronizasyon mekanizması
- Herkese açık/özel oda seçeneği
- Chat sistemi

---

**Versyon**: 1.0.0  
**Geliştirici**: Edebi Çengel Team  
**Tarih**: 2026
