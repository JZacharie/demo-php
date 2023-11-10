
# Create Demo Project
docker run -u `id -u`:`id -g` --rm -v `pwd`:/var/www/html pimcore/pimcore:php8.2-latest composer create-project pimcore/demo pimcore
#Copy ENV
cp int.env ./pimcore/.env
cp 30* pimcore/
cp docker-compose.yaml pimcore/
#Go in Project
cd pimcore
#Patch User
sed -i "s|#user: '1000:1000'|user: '1000:1000'|" docker-compose.yaml
#Start MicroServices
docker-compose pull
docker-compose up -d
sleep 5
. .env
pwd
#Configure pimcore from ENV
docker compose exec php vendor/bin/pimcore-install --no-interaction
docker compose exec php composer require pimcore/data-importer
docker compose exec php bin/console pimcore:bundle:list
docker compose exec php bin/console pimcore:search-backend-reindex
#Configure SMTP
sed -i 's/#    mailer:/    mailer:/' config/config.yaml
sed -i 's/#        transports:/        transports:/' config/config.yaml
sed -i 's/#            main: /            main: /' config/config.yaml
sed -i "s|main: smtp://user:pass@smtp.example.com:port|main: $PIMCORE_INSTALL_SMTP|" config/config.yaml
