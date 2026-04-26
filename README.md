# Edebi Çengel
- Edebî Çengel: Edebiyat Öğretiminde Dijital Bulmacalar
- **Edebî Çengel**, Türk edebiyatı ve kültürü temalı **modern bir çengel bulmaca** uygulamasıdır. Tek oyunculu deneyimin yanında arkadaşlarınla yarışabileceğin **çok oyunculu** mod sunar. **Offline-first** mimarisi sayesinde internet olmadan da tam oyun deneyimi sağlar; çevrimiçi olunduğunda ise profil, puan ve istatistikler **senkronize** edilebilir.

> **Amaç:** Türk edebiyatını oyunlaştırarak daha eğlenceli, erişilebilir ve sürdürülebilir bir öğrenme/tekrar deneyimine dönüştürmek.

---

## ✨ Öne Çıkan Özellikler

### 🧩 Çengel Bulmaca Sistemi
- Kısmi harf gösterimiyle **tahmin + tamamlama** mekanikleri
- **Dinamik zorluk seviyesi (Kolay, Orta, Zor)**: Kolaydan zora kademeli ilerleme
- **Türkçe karakter desteği**: Ç, Ğ, İ, Ö, Ş, Ü sorunsuz çalışır  
- Otomatik **Türkçe karakter normalizasyonu** ile daha rahat giriş deneyimi

---

## 👥 Çok Oyunculu (Multiplayer) — REST API Tabanlı

- Edebî Çengel’in çok oyunculu altyapısı, **Socket/WebSocket yerine REST API’ye taşınmış** bir mimariyle çalışır. Bu yaklaşım, bazı ağ/CDN güvenlik kısıtlamalarında daha stabil bağlantı ve daha kolay yönetilebilir sunucu mimarisi sağlar.

### 🎮 Multiplayer İçeriği
- **Oda sistemi**
  - Oda oluşturma / katılma / ayrılma
  - **Herkese açık / özel oda** seçeneği
- **Host kontrolü**
  - Oda sahibi oyun ayarlarını yönetir
- **Oyuncu durumu**
  - Hazır durumu (ready), oyuncu listesi, oda durumu senkronizasyonu
- **Skor & ilerleme senkronizasyonu**
  - Oyuncuların ilerlemesi ve puanları oyun boyunca güncellenir
- **Oyun sonuç ekranı**
  - Oyun bitiminde sıralama, puanlar ve sonuç özeti görüntülenir
- (Opsiyonel) **Chat** desteği

---

## 🤖 AI Destekli Bulmaca Üretimi

- Dinamik üretim mantığıyla **tekrarsız** bulmaca deneyimi
- “AI Bulmaca” modu ile **sınırsız** oynanış hissi
- Kategori/tema yapısına uyumlu içerik üretimi yaklaşımı
- **Esnek üretim seçenekleri:** Kullanıcı isterse üretimi **tamamen yapay zekaya bırakır**, isterse **kategori/tema seçerek** oluşturur; ayrıca dilerse **kendi belirlediği konuyu yazarak** (serbest metin) o konuya özel bulmaca ürettirebilir.  
> **Not:** AI Bulmaca özelliği, sunucu maliyetleri nedeniyle **bazı dönemlerde geçici olarak kapalı** olabilir. Özellik kapalıyken uygulamada menü/ekran olarak **görünmez** (kullanıcıya kapalı olduğu dönemde gösterilmez).

---

## 🧑‍💻 Profil, İstatistikler ve Gelişim

### 📌 Oyuncu Profili
- İsteğe bağlı **kayıt / giriş** sistemi (JWT tabanlı kimlik doğrulama)
- Profil üzerinden puan, unvan, rozet ve istatistik takibi

### 📊 Detaylı İstatistikler
- **Çözülen bulmaca** sayısı
- **Tamamlanan kelime** sayısı
- **Doldurulan hücre** sayısı
- **Kullanılan ipucu** sayısı
- **En hızlı çözüm** süresi
- **En iyi seri** (streak) gibi başarı ölçümleri

### 🏅 Rozetler (Badges) & Başarı Sistemi
- Belirli hedefleri tamamladıkça açılan **rozetler**
- Koleksiyon mantığı: kazanılan rozetler profil ekranında görüntülenir
- Oyun motivasyonunu artıran **hedef/ödül** döngüsü

### ⭐ Puan & Unvan Sistemi
- Oyun içi aksiyonlara göre puan kazanımı
- Oyuncu seviyesine göre **unvan/rütbe** görünümü (örn. “Acemi Çözücü”)

---

## 🏆 Liderlik Tablosu (Leaderboard)

- **Tüm zamanlar / aylık / haftalık** filtreleme
- Oyuncu sıralaması ve **🥇🥈🥉 madalya sistemi**
- Seviye ve rütbe bazlı görünüm (isteğe göre kademeli ilerleme)

---

## 🎨 Tema ve Kişiselleştirme

- Uygulama içinden **tema seçimi**
  - Örn: **Teal (Orijinal), Turuncu, Mor, Mavi, Pembe, Yeşil, Indigo**
- Dinamik tema altyapısı
- **Ses ve animasyon** ayarları
- Oyun deneyimini kişiye göre ayarlayan seçenekler

---

## 🔌 Offline-First Deneyim

Edebî Çengel, internet yokken de çalışacak şekilde tasarlanmıştır:

- İnternetsiz **tam oyun deneyimi**
- Offline oynanan ilerleme ve istatistikler, çevrimiçi olunduğunda **isteğe bağlı senkronize** edilebilir
- Öğrenme/tekrar odaklı kullanım için stabil deneyim

---

## 🖥️ Platform Desteği

Tek kod tabanı ile birden fazla platformda çalışır:

- **Windows**
- **Android**
- **iOS** (Kısıtlamalardan ötürü şuanda kullanılamıyor.)
- **Web**

---

## 🧱 Teknik Özet (Kısa)

### Frontend
- **Flutter (Dart)** ile çok platformlu geliştirme
- Modern arayüz + özelleştirilmiş bileşenler
- State yönetimi ve modüler ekran yapısı

### Backend
- **Node.js (Express)** altyapısı
- Multiplayer ve kullanıcı işlemleri için **REST API**
- Kimlik doğrulama: **JWT**
- İstatistik senkronizasyonu + offline-first yaklaşımı

---

## 🎯 Hedef Kitle

- 📚 Türk edebiyatı meraklıları  
- 🎮 Bulmaca seven kullanıcılar  
- 🏫 Okullar ve eğitim kurumları  
- 👥 Arkadaşlarıyla yarışmayı seven oyuncular  

---

## ✅ Neden Edebi Çengel?

- **Omnichannel:** Windows + Mobil + Web (tek kod tabanı)
- **Offline-first:** İnternet olmadan da tam deneyim
- **REST tabanlı multiplayer:** Daha stabil ve kolay yönetilebilir altyapı
- **AI destekli içerik:** Tekrarsız, uzun süreli oynanış
- **Rozet/puan/leaderboard:** Motivasyon ve rekabet döngüsü
- **Tam Türkçe uyumu:** Dil ve karakter desteği odaklı tasarım

---

**Edebî Çengel**, eğlence ve öğrenmeyi bir araya getiren, Türk edebiyatı severleri için tasarlanmış, tamamen offline çalışan bir oyundur. Yalnızca Web sürümü, çok oyunculu özellikleri, AI destekli bulmacalar için internet gereklidir.
