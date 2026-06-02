# Azure Voting App
> **Attention:** Ce projet sera utilisé tout au long du module, gardez toujours votre travail, même s'il ne fonctionne pas, ça vous permettra de comparer avec les corrections et de comprendre ce qu'il vous manque !

## Introduction
L'application Azure vote app est une application très simple qui permet de voter entre deux choix définit dans le fichier `config_file.cfg`
Le choix est stocké dans une base de données de type Cache (Redis).

## Prérequis
Pour faire fonctionner le code en local vous avez besoin de:
- Python (3.13 minimum)
- Redis

Certaines dépendances doivent être installé avec Pip, le gestionnaire de packages de Python:
- flask
- redis

> **Recommendations**: Je vous conseille d'utiliser les virtualenv de Python pour garder votre machine clean.

## Lancer le projet

Depuis votre terminal une fois les dépendances configuré, lancer la commande `python main.py` pensez a ajouter la variable d'environnement `REDIS` qui pointe vers le serveur Redis et `REDIS_PWD` si vous avez un mot de passe sur votre Cache Redis 