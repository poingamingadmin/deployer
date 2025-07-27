#!/bin/bash

# === Konfigurasi ===
LARAVEL_USER="kmzwayxx"
APP_PATH="/var/www/html"
PHP_VERSION="8.3"

echo "=== Buat User Baru: $LARAVEL_USER ==="
adduser --disabled-password --gecos "" $LARAVEL_USER

echo "=== Tambahkan $LARAVEL_USER ke grup sudo dan www-data ==="
usermod -aG sudo $LARAVEL_USER
usermod -aG www-data $LARAVEL_USER

echo "=== Update & Upgrade Ubuntu (Non-Interactive) ==="
export DEBIAN_FRONTEND=noninteractive
apt update
apt -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    upgrade -yq

echo "=== Tambah PPA PHP ==="
add-apt-repository ppa:ondrej/php -y
apt update

echo "=== Install PHP & Extensions ==="
apt install -y php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-bcmath php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-mysql php${PHP_VERSION}-redis php${PHP_VERSION}-fpm unzip nginx mysql-server git curl

echo "=== Install Node.js & npm (untuk Laravel Vite, Tailwind, dll) ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

echo "=== Install Composer ==="
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

echo "=== Setup Nginx ==="
cat > /etc/nginx/sites-available/laravel <<EOF
server {
    listen 80;
    server_name _;

    root ${APP_PATH}/public;
    index index.php index.html;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "=== Restart dan Enable Service ==="
systemctl restart php${PHP_VERSION}-fpm
systemctl restart nginx
systemctl enable php${PHP_VERSION}-fpm
systemctl enable nginx

echo "=== Laravel Setup Completed at ${APP_PATH} ==="
