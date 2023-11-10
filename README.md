# Installation de Pimcore et OroCommerce via Docker Compose

Ce guide vous guidera à travers le processus d'installation de Pimcore et OroCommerce en utilisant Docker Compose. 
A déployer sur une EC2 dans AWS.
Assurez-vous d'avoir Docker et Docker Compose installés sur votre système avant de commencer.

## Pimcore:
lancer :
```sh
./install.sh
```
Le script install une version demo et les composants identifiés dans la documentation que vous nous avez transmit.
Le site est sur le port 80.

### Remarque, non ready for production car la DB est local dans un container.
Il faudra pmodifier le fichier int.env pour cible la bonne base de donnée.
Il faudra supprimer le micro service DB du docker-compose.yaml.

## Orocommerce:

patcher le fichier .env par rapport a vos besoins.
lancer la commande:

```sh
docker-compose up -d
```
Le site est sur le port 81.

## TODO

* Installer une BDD en RDS.
* Utiliser un ALB.
* Gérer la sécurité réseaux.
