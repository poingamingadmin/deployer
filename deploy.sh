#!/bin/bash

# ================== PARSE ARGUMENTS ===================
USER_BARU="$1"
REPO_URL="$2"
APP_NAME="$3"
DB_DATABASE="$4"
CACHE_PREFIX="$5"
PUSHER_APP_ID="$6"
PUSHER_APP_KEY="$7"
PUSHER_APP_SECRET="$8"

PROJECT_DIR="/var/www/html"

# ============ CEK PARAMETER WAJIB =====================
REQUIRED_VARS=("USER_BARU" "REPO_URL" "APP_NAME" "DB_DATABASE" "CACHE_PREFIX" "PUSHER_APP_ID" "PUSHER_APP_KEY" "PUSHER_APP_SECRET")

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ ERROR: Parameter $var belum diisi."
        exit 1
    fi
done

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

apt-get update -y
apt-get upgrade -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold"

# =============== USER SETUP ==========================
echo "📦 Mengecek user..."
if id "$USER_BARU" &>/dev/null; then
    echo "✅ User $USER_BARU sudah ada."
else
    echo "👤 Membuat user $USER_BARU..."
    sudo adduser --disabled-password --gecos "" "$USER_BARU"
    sudo usermod -aG sudo "$USER_BARU"
    sudo usermod -aG www-data "$USER_BARU"
fi

# =============== SYSTEM UPDATE & DEPENDENCIES =========
echo "🔄 Update paket..."
sudo apt update -y

echo "🚀 Instalasi PHP dan modul-modul..."
sudo apt install -y php8.3 php8.3-fpm php8.3-mysql php8.3-xml php8.3-mbstring php8.3-curl php8.3-gd php8.3-cli php8.3-redis php8.3-zip

echo "🌐 Instalasi Nginx..."
if ! command -v nginx &>/dev/null; then
    sudo apt install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
fi

echo "🔐 Instalasi Certbot..."
if ! command -v certbot &>/dev/null; then
    sudo apt install -y certbot python3-certbot-nginx
fi

echo "🧰 Instalasi Unzip dan Git..."
sudo apt install -y unzip git

echo "🎼 Instalasi Composer..."
if ! command -v composer &>/dev/null; then
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
fi

# =============== CLONE PROJECT =========================
echo "📁 Menyiapkan direktori project..."
sudo rm -rf "$PROJECT_DIR"
sudo mkdir -p "$PROJECT_DIR"
sudo chown -R "$USER_BARU":www-data "$PROJECT_DIR"
sudo chmod -R 775 "$PROJECT_DIR"

echo "📂 Mengatur git safe directory..."
sudo -u "$USER_BARU" git config --global --add safe.directory "$PROJECT_DIR"

echo "🔃 Mengkloning repository Git..."
sudo -u "$USER_BARU" git clone "$REPO_URL" "$PROJECT_DIR"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Kloning project gagal. Periksa URL Git atau koneksi internet."
    exit 1
fi

cd "$PROJECT_DIR" || exit

# =============== SETUP ENV =============================
if [ ! -f .env ]; then
    cp .env.example .env
    echo "📄 File .env dibuat dari .env.example"
fi

update_env() {
    local key=$1
    local value=$2
    if grep -q "^$key=" .env; then
        sed -i "s|^$key=.*|$key=$value|" .env
    else
        echo "$key=$value" >>.env
    fi
}

update_env "APP_NAME" "$APP_NAME"
update_env "APP_ENV" "production"
update_env "DB_DATABASE" "$DB_DATABASE"
update_env "CACHE_PREFIX" "$CACHE_PREFIX"
update_env "PUSHER_APP_ID" "$PUSHER_APP_ID"
update_env "PUSHER_APP_KEY" "$PUSHER_APP_KEY"
update_env "PUSHER_APP_SECRET" "$PUSHER_APP_SECRET"

echo "✅ .env dikonfigurasi."

# =============== INSTALL DEPENDENCY LARAVEL =============
echo "📦 Install dependency Laravel..."
sudo -u "$USER_BARU" composer install --no-interaction --prefer-dist

# =============== PERBAIKI IZIN .env ====================
echo "🔒 Mengatur permission .env..."
sudo chown "$USER_BARU":www-data .env
sudo chmod 664 .env

# =============== LARAVEL APP KEY ========================
echo "🔑 Generate APP_KEY..."
sudo -u "$USER_BARU" php artisan key:generate --force

# =============== PERMISSION =============================
echo "📂 Set permission folder Laravel..."
sudo chown -R www-data:www-data storage bootstrap/cache
sudo chmod -R 775 storage bootstrap/cache
sudo find storage -type d -exec chmod 775 {} \;
sudo find bootstrap/cache -type d -exec chmod 775 {} \;

# =============== NGINX CONFIG ===========================
echo "🧹 Menulis ulang konfigurasi Nginx..."
sudo tee /etc/nginx/sites-available/default >/dev/null <<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root $PROJECT_DIR/public;
    index index.php index.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

# 🔗 Pastikan link-nya aktif
sudo ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# ✅ Uji konfigurasi Nginx sebelum restart
sudo nginx -t

# =============== RESTART SERVICE ========================
echo "🔁 Restart semua service..."
sudo systemctl restart php8.3-fpm
sudo systemctl restart nginx

# =============== DONE ===================================
echo ""
echo "🎉 DEPLOY SELESAI!"
