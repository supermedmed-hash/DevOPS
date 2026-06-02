# Étape 6 : Docker Compose et le Healthcheck

## Qu'est-ce que c'est ?
**Docker Compose** est un outil qui permet de définir et de lancer des applications multi-conteneurs. Au lieu de lancer notre conteneur Redis et notre conteneur Python à la main en tapant des commandes à rallonge, on décrit tout dans un simple fichier texte (`docker-compose.yml`).

## Le choix technique dans ce projet
Notre `docker-compose.yml` orchestre deux services (conteneurs) :
1. **`redis`** : C'est notre base de données. 
   - *Intérêt* : Nous avons ajouté la commande `--requirepass` pour sécuriser l'accès à la base de données avec un mot de passe (consigne `REDIS_PWD`).
2. **`voting-app`** : C'est notre application Python.
   - *Mapping de port* : Nous avons fait pointer le port `8080` de votre ordinateur vers le port `80` du conteneur (`"8080:80"`). Cela permet de répondre à la consigne d'accéder au site sur `http://localhost:8080` tout en laissant l'application tourner sur le port `80` en interne.
   - *Variables d'environnement* : Nous transmettons `REDIS=redis` et le mot de passe. Docker inclut un serveur DNS interne : le mot "redis" sera automatiquement traduit en adresse IP du conteneur Redis !

## Le Healthcheck (Vérification de santé)
*Note : Comme l'a très justement fait remarquer votre professeur, bien qu'il soit possible de déclarer le healthcheck dans ce fichier `docker-compose.yml`, la meilleure pratique est de le mettre directement dans le `Dockerfile` !*

- **Pourquoi dans le Dockerfile plutôt qu'ici ?**
  Placer le Healthcheck dans le Dockerfile attache cette vérification **directement à l'image**. Ainsi, si quelqu'un d'autre télécharge votre image ou si vous la déployez sur un autre système (comme Kubernetes ou Docker Swarm), le test de santé "voyage" avec l'application. Cela évite de devoir réécrire (et risquer d'oublier) ces lignes de configuration à chaque nouveau déploiement. C'est plus propre, plus encapsulé, et plus "DevOps" !

- **Pourquoi est-ce indispensable ?** Dans la vraie vie (en production), un conteneur peut "tourner" mais l'application à l'intérieur peut être plantée (bug, boucle infinie...).
- **Comment ça fonctionne ?** Toutes les 30 secondes, Docker va exécuter la commande `curl -f http://localhost:80/` directement à l'intérieur du conteneur. S'il reçoit une réponse HTML, le conteneur est marqué "healthy" (en bonne santé). S'il échoue, l'orchestrateur saura qu'il faut redémarrer le conteneur automatiquement.
