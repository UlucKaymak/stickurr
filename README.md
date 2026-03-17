# StickersApp 🎨

macOS masaüstünüz için hafif (lightweight), yerli (native) ve şık bir PNG sticker uygulaması.

![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%2013.0+-blue.svg)

## Özellikler

- 🕊️ **Hafif ve Hızlı:** Sadece SwiftUI ve AppKit kullanılarak geliştirildi. Electron veya web teknolojileri içermez, minimum kaynak tüketir.
- ✨ **Otomatik Outline:** Eklediğiniz her PNG dosyasının etrafına otomatik olarak beyaz bir kenarlık ve hafif bir gölge eklenerek "sticker" görünümü verilir.
- 🖱️ **Sürükle-Bırak:** Stickerları masaüstünüzde dilediğiniz yere sürükleyip bırakabilirsiniz.
- ☁️ **Arka Planda Çalışma:** Uygulama Dock'ta yer kaplamaz, sadece Menü Çubuğu'nda (Status Bar) bir ikon olarak görünür.
- 🖼️ **Şeffaf Katman:** Stickerlar şeffaf pencerelerde (NSPanel) çalışır, böylece masaüstüyle bütünleşik görünürler.

## Kurulum ve Çalıştırma

### Hazır Paketi Çalıştırma
Eğer projeyi derlediyseniz, ana dizindeki uygulamayı şu komutla başlatabilirsiniz:

```bash
open StickersApp.app
```

### Kaynaktan Derleme
Uygulamayı kendiniz derlemek isterseniz Terminal üzerinden şu komutu kullanabilirsiniz:

```bash
# Proje dizinine gidin
cd StickersApp

# Derleme ve Paketleme
swiftc -o StickersApp/StickersApp Sources/StickersApp/*.swift \
    -sdk $(xcrun --show-sdk-path --sdk macosx) \
    -framework SwiftUI -framework Cocoa -framework UniformTypeIdentifiers

# .app paketini güncelleme
cp StickersApp/StickersApp StickersApp.app/Contents/MacOS/StickersApp
```

## Kullanım Rehberi

1. **Uygulamayı Başlatın:** Menü çubuğunda (sağ üst) gülen yüz ikonu belirecektir.
2. **Sticker Ekleme:** İkona tıklayın ve `Yeni Sticker Ekle...` (veya `Cmd+N`) seçeneğini seçin.
3. **Dosya Seçimi:** Bilgisayarınızdan bir veya birden fazla PNG dosyası seçin.
4. **Yerleştirme:** Stickerlar ekranın ortasında belirecektir. İstediğiniz stickerı farenizle tutup sürükleyerek konumlandırabilirsiniz.
5. **Temizleme:** Tüm stickerları kaldırmak için menüden `Hepsini Temizle` seçeneğini kullanın.
6. **Çıkış:** Uygulamayı tamamen kapatmak için `Çıkış` seçeneğine tıklayın.

## Teknik Detaylar

- **NSPanel:** Sticker pencereleri `NSPanel` sınıfından türetilmiştir. Bu sayede `canJoinAllSpaces` özelliği ile tüm masaüstü alanlarında görünürler ve `floating` seviyesiyle diğer pencerelerin üstünde kalabilirler.
- **SwiftUI Shadows:** Outline efekti, performans kaybı yaşatmamak için çoklu gölge (shadow) katmanları kullanılarak simüle edilmiştir.
- **LSUIElement:** `Info.plist` içerisindeki bu anahtar sayesinde uygulama Dock'ta görünmez.

## Lisans
Bu proje eğitim amaçlı ve kişisel kullanım için tasarlanmıştır. İstediğiniz gibi geliştirebilir ve değiştirebilirsiniz.
