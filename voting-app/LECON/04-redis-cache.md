# Étape 4 : La base de données Cache (Redis)

## Qu'est-ce que c'est ?
**Redis** est un système de gestion de base de données en mémoire (In-Memory). Contrairement à des bases de données classiques comme MySQL ou PostgreSQL qui écrivent leurs données sur le disque dur, Redis stocke tout dans la mémoire vive (RAM).

## Le choix technique dans ce projet
Le `README.md` indique que le choix des utilisateurs (les votes) est stocké dans Redis. 
L'intérêt technique majeur est la **performance**. Lire et écrire dans la RAM est infiniment plus rapide que de le faire sur un disque dur. C'est idéal pour un système de vote, un compteur, ou un système de cache où il peut y avoir de très nombreuses petites requêtes extrêmement rapides.

## Comment ça fonctionne ?
Redis fonctionne sur un système clé/valeur très simple. Par exemple : la clé `chien` vaut `45` (votes), la clé `chat` vaut `32` (votes).
L'application Python (grâce au paquet `redis` que l'on a installé via Pip) va se connecter au serveur Redis pour y envoyer les nouveaux votes des utilisateurs ou récupérer les scores actuels afin de les afficher sur la page web.

Pour que Python sache où se trouve le serveur Redis, l'application utilise des **variables d'environnement** (`REDIS` pour l'adresse du serveur et `REDIS_PWD` pour le mot de passe).
 