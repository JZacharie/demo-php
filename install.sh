#!/usr/bin/env bash

#curl -L https://github.com/JZacharie/demo-php/raw/main/install.sh | bash
set -o errexit
set -o nounset
set -o pipefail

echo "Installing pimcore..."

ARCHITECTURE="$(uname -m)"
# Not supported on 32 bits systems
if [[ "$ARCHITECTURE" == "armv7"* ]] || [[ "$ARCHITECTURE" == "i686" ]] || [[ "$ARCHITECTURE" == "i386" ]]; then
  echo "pimcore is not supported on 32 bits systems"
  exit 1
fi

### --------------------------------
### CLI arguments
### --------------------------------
UPDATE="false"
VERSION="latest"
while [ -n "${1-}" ]; do
    case "$1" in
    --update) UPDATE="true" ;;
    --version)
        shift # Move to the next parameter
        VERSION="$1" # Assign the value to VERSION
        if [ -z "$VERSION" ]; then
            echo "Option --version requires a value" && exit 1
        fi
        ;;
    --)
        shift # The double dash makes them parameters
        break
        ;;
    *) echo "Option $1 not recognized" && exit 1 ;;
    esac
    shift
done


OS="$(cat /etc/[A-Za-z]*[_-][rv]e[lr]* | grep "^ID=" | cut -d= -f2 | uniq | tr '[:upper:]' '[:lower:]' | tr -d '"')"
SUB_OS="$(cat /etc/[A-Za-z]*[_-][rv]e[lr]* | grep "^ID_LIKE=" | cut -d= -f2 | uniq | tr '[:upper:]' '[:lower:]' | tr -d '"' || echo 'unknown')"

function install_generic() {
  local dependency="${1}"
  local os="${2}"

  if [[ "${os}" == "debian" ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${dependency}"
    return 0
  elif [[ "${os}" == "ubuntu" || "${os}" == "pop" ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${dependency}"
    return 0
  elif [[ "${os}" == "centos" ]]; then
    sudo yum install -y --allowerasing "${dependency}"
    return 0
  elif [[ "${os}" == "fedora" ]]; then
    sudo dnf -y install "${dependency}"
    return 0
  elif [[ "${os}" == "arch" ]]; then
    if ! sudo pacman -Sy --noconfirm "${dependency}" ; then
      if command -v yay > /dev/null 2>&1 ; then
        sudo -u $SUDO_USER yay -Sy --noconfirm "${dependency}"
      else
        echo "Could not install \"${dependency}\", either using pacman or the yay AUR helper. Please try installing it manually."
        return 1
      fi
    fi
    return 0
  else
    return 1
  fi
}

function install_docker() {
  local os="${1}"
  echo "Installing docker for os ${os}"

  if [[ "${os}" == "debian" ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    return 0
  elif [[ "${os}" == "ubuntu" || "${os}" == "pop" ]]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    return 0
  elif [[ "${os}" == "centos" ]]; then
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y --allowerasing docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
    return 0
  elif [[ "${os}" == "fedora" ]]; then
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
    return 0
  elif [[ "${os}" == "arch" ]]; then
    sudo pacman -Sy --noconfirm docker docker-compose
    sudo systemctl start docker.service
    sudo systemctl enable docker.service
    return 0
  else
    return 1
  fi
}

if ! command -v docker >/dev/null; then
  echo "Installing docker"
  install_docker "${OS}"
  docker_result=$?

  if [[ docker_result -eq 0 ]]; then
    echo "Docker installed"
  else
    echo "Your system ${OS} is not supported trying with sub_os ${SUB_OS}"
    install_docker "${SUB_OS}"
    docker_sub_result=$?

    if [[ docker_sub_result -eq 0 ]]; then
      echo "Docker installed"
    else
      echo "Your system ${SUB_OS} is not supported please install docker manually"
      exit 1
    fi
  fi
fi

function check_dependency_and_install() {
  local dependency="${1}"

  if ! command -v "${dependency}" >/dev/null; then
    echo "Installing ${dependency}"
    install_generic "${dependency}" "${OS}"
    install_result=$?

    if [[ install_result -eq 0 ]]; then
      echo "${dependency} installed"
    else
      echo "Your system ${OS} is not supported trying with sub_os ${SUB_OS}"
      install_generic "${dependency}" "${SUB_OS}"
      install_sub_result=$?

      if [[ install_sub_result -eq 0 ]]; then
        echo "${dependency} installed"
      else
        echo "Your system ${SUB_OS} is not supported please install ${dependency} manually"
        exit 1
      fi
    fi
  fi
}

# Example
# check_dependency_and_install "openssl"

# Check if git is installed
if ! command -v git >/dev/null; then
  echo "Git is not installed. Please install git and restart the script."
  exit 1
fi

# Create Demo Project
docker run -u `id -u`:`id -g` --rm -v `pwd`:/var/www/html pimcore/pimcore:php8.2-latest composer create-project pimcore/demo pimcore
#Copy ENV

cat >./pimcore/.env <<EOF
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
#cp int.env ./pimcore/.env

cat >./pimcore/30-pimcore-php.ini<<EOF
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
#            PIMCORE_INSTALL_MYSQL_USERNAME: pimcore
#            PIMCORE_INSTALL_MYSQL_PASSWORD: pimcore
#            PIMCORE_INSTALL_ADMIN_USERNAME: admin
#            PIMCORE_INSTALL_ADMIN_PASSWORD: admin
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
#cp 30* pimcore/

# cp docker-compose.yaml pimcore/



# #Go in Project
# cd pimcore
# #Patch User
# sed -i "s|#user: '1000:1000'|user: '1000:1000'|" docker-compose.yaml
# #Start MicroServices
# docker-compose pull
# docker-compose up -d
# sleep 5
# . .env
# pwd
# #Configure pimcore from ENV
# docker compose exec php vendor/bin/pimcore-install --no-interaction
# docker compose exec php composer require pimcore/data-importer
# docker compose exec php bin/console pimcore:bundle:list
# docker compose exec php bin/console pimcore:search-backend-reindex
# #Configure SMTP
# sed -i 's/#    mailer:/    mailer:/' config/config.yaml
# sed -i 's/#        transports:/        transports:/' config/config.yaml
# sed -i 's/#            main: /            main: /' config/config.yaml
# sed -i "s|main: smtp://user:pass@smtp.example.com:port|main: $PIMCORE_INSTALL_SMTP|" config/config.yaml