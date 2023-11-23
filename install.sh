#!/usr/bin/env bash

#curl -L https://github.com/JZacharie/demo-php/raw/main/install.sh | bash
set -o errexit
set -o nounset
set -o pipefail

echo "Installing docker..."
sudo dnf update -y
sudo dnf install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
sudo yum install python-pip -y
sudo yum remove python3-requests -y
sudo pip install docker-compose
docker-compose -v

sudo mkdir -p /var/www/html
sudo -i
cd /var/www/html

# Create Demo Project
docker run -u `id -u`:`id -g` --rm -v `pwd`:/var/www/html pimcore/pimcore:php8.2-latest composer create-project pimcore/demo .
#Copy ENV

cat >.env <<EOF
APP_ENV=dev
FOO=BAR
PIMCORE_INSTALL_ADMIN_PASSWORD=admin
PIMCORE_INSTALL_ADMIN_USERNAME=admin
PIMCORE_INSTALL_MYSQL_PASSWORD=pimcore
PIMCORE_INSTALL_MYSQL_USERNAME=pimcore
PIMCORE_INSTALL_MYSQL_HOST_SOCKET=db 
PIMCORE_INSTALL_MYSQL_DATABASE=pimcore
PIMCORE_INSTALL_INSTALL_BUNDLES=PimcoreDataHubBundle
PIMCORE_INSTALL_SMTP=smtps://serviceaccountsmtp:changeit@smtp.societe.io:463
#TRUSTED_PROXIES=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
#TRUSTED_HOSTS='^(localhost|example\.com)$'
###< symfony/framework-bundle ###
EOF

cat >./30-pimcore-php.ini<<EOF
upload_max_filesize = 10G
memory_limit = 512M
post_max_size = 10G
realpath_cache_size = 4M
date.timezone = Europe/Paris
EOF

cat >./docker-compose.yaml<<EOF
services:
    redis:
        image: redis:alpine
        command: [ redis-server, --maxmemory, 128mb, --maxmemory-policy, volatile-lru, --save, '""' ]

    db:
        image: mariadb:10.11
        working_dir: /application
        command: [ mysqld, --character-set-server=utf8mb4, --collation-server=utf8mb4_unicode_ci, --innodb-file-per-table=1 ]
        volumes:
            - pimcore-demo-database:/var/lib/mysql
        environment:
            MYSQL_ROOT_PASSWORD: ROOT
            MYSQL_DATABASE: pimcore
            MYSQL_USER: pimcore
            MYSQL_PASSWORD: pimcore
    nginx:
        image: nginx:stable-alpine
        ports:
            - "80:80"
        volumes:
            - .:/var/www/html:ro
            - ./.docker/nginx.conf:/etc/nginx/conf.d/default.conf:ro
        depends_on:
            - php

    php:
        user: '1000:1000' # set to your uid:gid
        image: pimcore/pimcore:php8.2-debug-latest
        environment:
            COMPOSER_HOME: /var/www/html
            PHP_IDE_CONFIG: serverName=localhost
        env_file:
            - .env
        depends_on:
            - db
        volumes:
            - .:/var/www/html
            - ./30-pimcore-php.ini:/usr/local/etc/php/conf.d/30-pimcore-php.ini

    supervisord:
        user: '1000:1000' # set to your uid:gid
        image: pimcore/pimcore:php8.2-supervisord-latest
        depends_on:
            - db
        volumes:
            - .:/var/www/html
            - ./.docker/supervisord.conf:/etc/supervisor/conf.d/pimcore.conf:ro

    chrome:
        image: browserless/chrome

    gotenberg:
        image: gotenberg/gotenberg:7

volumes:
    pimcore-demo-database:
EOF

#Pull MicroServices
docker-compose pull
#Start MicroServices
docker-compose up -d
sleep 5
. .env
pwd

#Configure pimcore from ENV
chown 1000:1000 . -R
docker-compose exec php vendor/bin/pimcore-install --no-interaction
docker-compose exec php composer require pimcore/data-importer
docker-compose exec php bin/console pimcore:bundle:list
docker-compose exec php bin/console pimcore:search-backend-reindex

#Configure SMTP
sed -i 's/#    mailer:/    mailer:/' config/config.yaml
sed -i 's/#        transports:/        transports:/' config/config.yaml
sed -i 's/#            main: /            main: /' config/config.yaml
sed -i "s|main: smtp://user:pass@smtp.example.com:port|main: $PIMCORE_INSTALL_SMTP|" config/config.yaml