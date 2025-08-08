#!/bin/bash

# n8n için domain al
read -p "n8n için domain veya IP adresi girin (örn: musabustun.com veya https://musabustun.com): " N8N_DOMAIN
if [[ ! "$N8N_DOMAIN" =~ ^https?:// ]]; then
    N8N_DOMAIN="https://$N8N_DOMAIN"
fi

# Hata durumunda script'i durdur
set -e

# Hata kontrolü fonksiyonu
check_command() {
    if [ $? -ne 0 ]; then
        echo "❌ Hata: $1 başarısız!"
        exit 1
    fi
}

echo "🚀 Sistemi güncelliyoruz..."
sudo apt update && sudo apt upgrade -y
check_command "Sistem güncellemesi"

echo "🧠 Swap alanı oluşturuluyor..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    check_command "Swap alanı oluşturma"
    echo "✅ Swap alanı başarıyla oluşturuldu"
else
    echo "⏭️ Swap alanı zaten mevcut, atlaniyor"
fi

echo "🔧 Gerekli temel paketler yükleniyor..."
sudo apt install -y curl build-essential wget unzip gnupg ffmpeg git ca-certificates lsb-release
check_command "Temel paketlerin kurulması"

echo "🌩️ Cloudflared kuruluyor..."
if ! command -v cloudflared &> /dev/null; then
    sudo mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    check_command "Cloudflare GPG anahtarı ekleme"

    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
    check_command "Cloudflared repo ekleme"

    sudo apt-get update
    sudo apt-get install -y cloudflared
    check_command "Cloudflared kurulumu"
    echo "✅ Cloudflared başarıyla kuruldu"
else
    echo "⏭️ Cloudflared zaten kurulu, atlaniyor"
fi

echo "🐳 Docker kuruluyor..."
if ! command -v docker &> /dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    check_command "Docker GPG anahtarı ekleme"
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    check_command "Docker repository ekleme"
    
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    check_command "Docker kurulumu"
    
    sudo usermod -aG docker $USER
    check_command "Kullanıcıyı docker grubuna ekleme"
    
    sudo systemctl enable docker
    sudo systemctl start docker
    check_command "Docker servisi başlatma"
    
    echo "✅ Docker başarıyla kuruldu"
else
    echo "⏭️ Docker zaten kurulu, atlaniyor"
fi

echo "🐹 Go dili kuruluyor..."
GO_VERSION="1.22.0"
if [ ! -d "/usr/local/go" ]; then
    wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz
    check_command "Go indirme"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
    check_command "Go kurulumu"
    rm go$GO_VERSION.linux-amd64.tar.gz
    echo "✅ Go başarıyla kuruldu"
else
    echo "⏭️ Go zaten kurulu, atlaniyor"
fi

if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
    echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.bashrc
fi
export PATH=$PATH:/usr/local/go/bin

/usr/local/go/bin/go version
check_command "Go versiyon kontrolü"

echo "🐘 PostgreSQL kuruluyor..."
if ! command -v psql &> /dev/null; then
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    check_command "PostgreSQL repository ekleme"
    sudo apt update
    sudo apt install -y postgresql-15
    check_command "PostgreSQL kurulumu"
    echo "✅ PostgreSQL başarıyla kuruldu"
else
    echo "⏭️ PostgreSQL zaten kurulu, atlaniyor"
fi

echo "📊 PostgreSQL yapılandırılıyor..."
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw n8n_chat; then
    sudo -u postgres psql <<EOF
CREATE USER musab WITH PASSWORD 'f79ee6bb';
CREATE DATABASE n8n_chat OWNER musab;
EOF
    check_command "PostgreSQL kullanıcı ve veritabanı oluşturma"
    echo "✅ PostgreSQL veritabanı ve kullanıcı oluşturuldu"
else
    echo "⏭️ PostgreSQL veritabanı zaten mevcut, atlaniyor"
fi

echo "🔐 PostgreSQL bağlantıya yapılandırılıyor..."
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/15/main/postgresql.conf

if ! grep -q "host.*musab.*n8n_chat.*172.17.0.0/16" /etc/postgresql/15/main/pg_hba.conf; then
    echo "host    n8n_chat        musab           127.0.0.1/32           md5" | sudo tee -a /etc/postgresql/15/main/pg_hba.conf
    echo "host    n8n_chat        musab           172.17.0.0/16          md5" | sudo tee -a /etc/postgresql/15/main/pg_hba.conf
    echo "host    n8n_chat        musab           ::1/128                md5" | sudo tee -a /etc/postgresql/15/main/pg_hba.conf
fi

sudo systemctl restart postgresql
check_command "PostgreSQL yeniden başlatma"

echo "📂 go-whatsapp-web-multidevice reposu indiriliyor ve derleniyor..."
if [ -d "$HOME/go-whatsapp-web-multidevice" ]; then
    echo "Repo zaten var, güncelleniyor..."
    cd "$HOME/go-whatsapp-web-multidevice"
    git pull
    check_command "Repo güncelleme"
else
    git clone https://github.com/aldinokemal/go-whatsapp-web-multidevice.git "$HOME/go-whatsapp-web-multidevice"
    check_command "Repo klonlama"
    cd "$HOME/go-whatsapp-web-multidevice"
fi


# Opsify konfigürasyonu yapılıyor...
echo "🔧 Opsify ayarları yapılandırılıyor..."

# Format webhook URLs
webhook_urls="${N8N_DOMAIN}/webhook/opsify,${N8N_DOMAIN}/webhook-test/opsify"

# Copy .env.example to .env if it exists
if [ -f "src/.env.example" ]; then
    cp src/.env.example src/.env
    check_command ".env dosyası kopyalama"
else
    echo "❌ Hata: src/.env.example bulunamadı!"
    exit 1
fi

# Comment out line 13 in .env
sed -i.bak '13s/^/#/' src/.env
check_command ".env dosyası düzenleme (1/3)"

# Update line 5 with opsify:opsify
sed -i.bak '5s/.*$/BASIC_AUTH_CREDENTIALS=opsify:opsify/' src/.env
check_command ".env dosyası düzenleme (2/3)"

# Update line 15 with webhook URLs
sed -i.bak "15s|.*|WEBHOOK_URLS=$webhook_urls|" src/.env
check_command ".env dosyası düzenleme (3/3)"

# Update AppOs in settings.go
sed -i.bak 's/AppOs\s*=\s*"[^"]*"/AppOs                  = "OpsifyServer"/' src/config/settings.go
check_command "settings.go dosyası düzenleme"

# Remove backup files
rm -f src/.env.bak src/config/settings.go.bak

cd src
echo "🚀 Go build başlatılıyor..."
/usr/local/go/bin/go build -o whatsapp
check_command "Go build işlemi"

echo "🔧 WhatsApp API systemd servisi oluşturuluyor..."
sudo tee /etc/systemd/system/whatsapp-api.service > /dev/null <<EOF
[Unit]
Description=WhatsApp Web API Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/go-whatsapp-web-multidevice/src
ExecStart=$HOME/go-whatsapp-web-multidevice/src/whatsapp rest --webhook=${N8N_DOMAIN}/webhook/opsify --webhook=${N8N_DOMAIN}/webhook-test/opsify
Restart=always
RestartSec=10
Environment=PATH=/usr/local/go/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
check_command "Systemd daemon reload"

sudo systemctl enable whatsapp-api.service
check_command "WhatsApp servisi etkinleştirme"

sudo systemctl start whatsapp-api.service
check_command "WhatsApp servisi başlatma"

echo "🐳 n8n Docker klasörleri oluşturuluyor..."
mkdir -p $HOME/.n8n
mkdir -p $HOME/n8n_data
check_command "n8n klasörlerinin oluşturulması"

echo "⚡ n8n Docker container'ı başlatılıyor..."
if docker ps -a | grep -q n8n-container; then
    echo "Mevcut n8n container'ı durduruluyor..."
    docker stop n8n-container || true
    docker rm n8n-container || true
fi

sudo docker run -d \
  --name n8n-container \
  --network host \
  --restart unless-stopped \
  -v $HOME/n8n_data:/home/node/.n8n \
  -e N8N_HOST=0.0.0.0 \
  -e N8N_PORT=5678 \
  -e N8N_PROTOCOL=http \
  -e WEBHOOK_URL=$N8N_DOMAIN \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=localhost \
  -e DB_POSTGRESDB_PORT=5432 \
  -e DB_POSTGRESDB_DATABASE=n8n_chat \
  -e DB_POSTGRESDB_USER=musab \
  -e DB_POSTGRESDB_PASSWORD=f79ee6bb \
  n8nio/n8n

check_command "n8n Docker container başlatma"

echo ""
echo "✅ Her şey başarıyla kuruldu! 🔥"