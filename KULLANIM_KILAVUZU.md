# 📖 Çengel Bulmaca - Kullanım Kılavuzu

## 🎮 Oyuncu Kılavuzu

### Oyuna Başlama
1. **Uygulama açılışı**: Ana ekranda mevcut konular görünür
2. **Konu seçimi**: Oynamak istediğiniz konuya tıklayın
3. **Oyun başlatma**: "Oyun başlatılıyor..." mesajından sonra ilk bulmaca yüklenir

### Oyun Oynama
1. **Soru okuma**: Ekranda gösterilen soruyu okuyun
2. **Çengel bulmaca**: Bazı harfler gösterilir, eksik harfleri tamamlayın
3. **Cevap yazma**: Alt kısımdaki kutuya cevabınızı yazın
4. **Gönderme**: "Cevabı Gönder" butonuna tıklayın veya Enter'a basın
5. **Sonraki soru**: Doğru cevap verirseniz otomatik olarak sonraki soruya geçer

### Navigasyon
- **Önceki**: Bir önceki soruya geri dönmek için
- **İpucu**: Ekstra bir harf görmek için
- **Sonraki**: Manuel olarak sonraki soruya geçmek için
- **Tamamla**: Son soruda bulmaca setini bitirmek için

### Puanlama
- Her doğru cevap için puan kazanırsınız
- Zorluk seviyesi puanı çoğaltır
- **Hesaplama**: Doğru Cevap × 10 × Zorluk Seviyesi

## 🛠️ İçerik Yöneticisi Kılavuzu

### İlk Kurulum
1. `content_manager/index.html` dosyasını tarayıcıda açın
2. İlk açılışta örnek veriler yüklenir
3. Veriler tarayıcı hafızasında (LocalStorage) saklanır

### Konu Ekleme
1. **"Konu Ekle"** sekmesine gidin
2. **Konu Adı**: Açıklayıcı bir isim girin (örn: "Osmanlı Tarihi")
3. **Açıklama**: Konu hakkında kısa bilgi
4. **"Konu Oluştur"** butonuna tıklayın

### Bulmaca Seti Ekleme
1. **"Bulmaca Ekle"** sekmesine gidin
2. **Konu Seçin**: Önceden oluşturduğunuz konulardan birini seçin
3. **Zorluk Seviyesi**: 1 (en kolay) - 5 (en zor) arası
4. **Başlık**: Bulmaca setine açıklayıcı isim
5. **Açıklama**: Opsiyonel detay bilgi

### Soru Ekleme
1. **"➕ Yeni Soru Ekle"** butonuna tıklayın
2. **Soru**: Net ve anlaşılır soru yazın
3. **Cevap**: Doğru cevabı tam olarak yazın
4. **Görünür Harf Sayısı**: Kaç harfin gösterileceğini belirleyin
5. **Önizleme**: Sağ altta maskelenmiş hali görünür
6. İhtiyacınız kadar soru ekleyin
7. **"Bulmaca Setini Kaydet"** ile tamamlayın

### Veri Yönetimi

#### Dışa Aktarma
1. **"İçe/Dışa Aktar"** sekmesine gidin
2. **"İndir (JSON)"** butonuna tıklayın
3. Tüm verileriniz JSON dosyası olarak indirilir

#### İçe Aktarma
1. **"JSON Dosyası Seçin"** ile dosya seçin
2. **"Yükle"** butonuna tıklayın
3. Seçilen dosyadaki veriler mevcut verilerin üzerine yazar

#### Oyuna Aktarma
1. **"Oyuna Aktar"** butonuna tıklayın
2. `topics.json` dosyası indirilir
3. Bu dosyayı `cengel_bulmaca/assets/data/` klasörüne kopyalayın
4. Flutter uygulamasını yeniden başlatın

## 🎯 En İyi Uygulamalar

### Soru Yazma İpuçları
- **Net sorular**: Belirsizlikten kaçının
- **Tek cevap**: Sorunun tek doğru cevabı olmalı
- **Uygun zorluk**: Hedef kitleye uygun sorular
- **Kısa cevaplar**: Çok uzun cevaplardan kaçının

### Çengel Bulmaca Tasarımı
- **Kolay seviye**: Cevabın %40-50'sini gösterin
- **Orta seviye**: Cevabın %25-35'ini gösterin  
- **Zor seviye**: Cevabın %15-25'ini gösterin
- **İlk harfler**: Genelde ilk harfleri göstermek daha kolay

### Zorluk Seviyesi Önerileri
1. **Seviye 1**: Genel kültür, bilinen konular
2. **Seviye 2**: Biraz araştırma gerektiren konular
3. **Seviye 3**: Ortalama bilgi gerektiren konular
4. **Seviye 4**: Uzman bilgisi gerektiren konular
5. **Seviye 5**: Çok detaylı/spesifik bilgiler

## 🔧 Teknik İpuçları

### Performans
- Her konu için maksimum 50-100 bulmaca seti
- Her sette maksimum 10-15 soru
- Medya dosyalarını küçük tutun (video: max 10MB, ses: max 5MB)

### Dosya Yönetimi
- **Düzenli yedekleme**: Verilerinizi düzenli olarak JSON'a aktarın
- **Medya organizasyonu**: Video/ses dosyalarını `assets/media/` klasöründe organize edin
- **Test etme**: Yeni içerikleri mutlaka test edin

### Hata Giderme
- **Veriler görünmüyor**: Tarayıcı önbelleğini temizleyin
- **JSON hatası**: Dosya formatını kontrol edin
- **Uygulama açılmıyor**: Flutter dependencies'i kontrol edin

## 📊 İçerik Planlama

### Önerilen Konu Yapısı
```
Konu (örn: Türk Edebiyatı)
├── Temel Seviye (Zorluk 1-2)
│   ├── Ünlü yazarlar
│   ├── Başlıca eserler
│   └── Genel bilgiler
├── Orta Seviye (Zorluk 3)
│   ├── Edebi akımlar
│   ├── Dönem özellikleri
│   └── Detaylı eser bilgisi
└── İleri Seviye (Zorluk 4-5)
    ├── Spesifik detaylar
    ├── Analiz soruları
    └── Uzman bilgisi
```

### Soru Dağılımı Önerisi
- **%40** Kolay sorular (Zorluk 1-2)
- **%40** Orta sorular (Zorluk 3)
- **%20** Zor sorular (Zorluk 4-5)

## 🎵 Medya İçerik Rehberi

### Video Dosyaları
- **Format**: MP4 önerilen
- **Çözünürlük**: 720p yeterli
- **Süre**: 10-30 saniye ideal
- **Boyut**: Maksimum 10MB

### Ses Dosyaları
- **Format**: MP3 önerilen
- **Kalite**: 128kbps yeterli
- **Süre**: 5-15 saniye ideal
- **Boyut**: Maksimum 5MB

### Medya Kullanım Örnekleri
- **Şiir okuması**: Ünlü şiirlerin sesli okuması
- **Tarihi anlar**: Önemli olayların kısa videoları
- **Müzik parçaları**: Klasik Türk müziği örnekleri
- **Konuşma kayıtları**: Ünlü kişilerin ses kayıtları

## 🎮 Oyun Stratejileri

### Oyuncular İçin İpuçları
1. **Önce kolay konularla başlayın**
2. **İpucunu hemen kullanmayın, önce düşünün**
3. **Cevap yazarken büyük/küçük harf önemli değil**
4. **Türkçe karakterleri doğru kullanın**

### Eğitmenler İçin Öneriler
1. **Sınıf yarışması**: Takımlar halinde oynayın
2. **Ev ödevi**: Belirli konularda bulmaca çözme
3. **Değerlendirme**: Öğrenme durumunu test etme aracı
4. **Motivasyon**: Skor sistemiyle rekabet

## 🔄 Güncelleme ve Bakım

### Düzenli Görevler
- [ ] Haftalık: Yeni içerik ekleme
- [ ] Aylık: Mevcut içerikleri gözden geçirme
- [ ] 3 Aylık: Oyuncu geri bildirimlerini değerlendirme
- [ ] 6 Aylık: Zorluk seviyelerini yeniden dengeleme

### Version Control
- **v1.0**: İlk stabil sürüm
- **v1.1**: Yeni içerik ekleme
- **v1.2**: Hata düzeltmeleri
- **v2.0**: Büyük özellik güncellemeleri

---

❓ **Sorularınız için**: README.md dosyasındaki iletişim bilgilerini kullanın.
