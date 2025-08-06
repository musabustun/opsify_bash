# Opsify Bash Kurulum Scripti

Bu script, bir Ubuntu sunucusunda WhatsApp Web API (go-whatsapp-web-multidevice), PostgreSQL, Docker, n8n ve Cloudflared gibi servislerin otomatik kurulumunu ve yapılandırmasını sağlar.

## Özellikler
- Sistem güncellemesi
- Swap alanı oluşturma
- Temel paketlerin kurulumu
- Cloudflared kurulumu
- Docker kurulumu
- Go dili kurulumu
- PostgreSQL kurulumu ve yapılandırması
- go-whatsapp-web-multidevice reposunun indirilip derlenmesi
- WhatsApp API için systemd servisi oluşturulması
- n8n için Docker container kurulumu ve PostgreSQL bağlantısı

## Kullanım
1. Script'i indirin veya kopyalayın.
2. Terminalde script'in bulunduğu dizine gidin.
3. Script'e çalıştırma izni verin:
   ```bash
   chmod +x opsify.sh
   ```
4. Script'i çalıştırın:
   ```bash
   ./opsify.sh
   ```

> **Not:** Script sudo yetkileri gerektirir. Gerekli durumlarda şifre isteyebilir.

## Gereksinimler
- Ubuntu tabanlı bir sunucu
- İnternet bağlantısı

## Güvenlik Uyarısı
Script içerisinde veritabanı kullanıcı adı ve şifresi gibi hassas bilgiler bulunmaktadır. Kendi ortamınıza göre düzenleyiniz ve paylaşmayınız.

## Katkı
Katkıda bulunmak için pull request gönderebilir veya issue açabilirsiniz.

---

**Yazar:** Musab
