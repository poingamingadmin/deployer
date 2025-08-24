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
apt install -y php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-fpm php${PHP_VERSION}-bcmath php${PHP_VERSION}-gd php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-mysql php${PHP_VERSION}-redis php${PHP_VERSION}-fpm unzip

echo "=== Install Composer ==="
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

echo "=== Install Nginx ==="
apt install -y nginx certbot python3-certbot-nginx
 
echo "=== Setup Nginx ==="
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /var/www/html/public;
    index index.php index.html;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

nginx -t && systemctl reload nginx

ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "=== Restart dan Enable Service ==="
systemctl restart php${PHP_VERSION}-fpm
systemctl restart nginx
systemctl enable php${PHP_VERSION}-fpm
systemctl enable nginx

#!/bin/bash
set -e

echo "=== Update packages ==="
sudo apt update

echo "=== Install Redis ==="
sudo apt install -y redis-server

echo "=== Configure Redis supervised mode ==="
sudo sed -i 's/^supervised .*/supervised systemd/' /etc/redis/redis.conf

echo "=== Configure Redis bind and password ==="
sudo sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf
sudo sed -i "s/^# requirepass .*/requirepass kmzwayxx/" /etc/redis/redis.conf

echo "=== Restart Redis service ==="
sudo systemctl restart redis-server

echo "=== Enable Redis on boot ==="
sudo systemctl enable redis-server

echo "=== Test Redis with password ==="
redis-cli -a kmzwayxx ping

echo "=== Laravel Setup Completed at ${APP_PATH} ==="
