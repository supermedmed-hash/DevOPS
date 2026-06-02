# Étape 5 : Le Dockerfile

## Qu'est-ce que c'est ?
Un **Dockerfile** est une sorte de "recette de cuisine" ou de script automatisé. Il contient toutes les instructions pour créer une **Image Docker**. Une image est un paquet qui contient absolument tout ce dont l'application a besoin pour tourner : le code, le langage de programmation (Python), les dépendances (Flask, Redis) et les outils systèmes.

## Le choix technique dans ce projet
Voici les points clés de notre Dockerfile :
1. **L'image de base (`python:3.13-slim`)** : Nous partons d'une version de Linux pré-configurée avec Python 3.13. Le mot `slim` signifie que c'est une version très légère. L'intérêt est de réduire la taille de notre image finale, ce qui la rend plus rapide à télécharger et plus sécurisée.
2. **L'installation de `curl`** : `curl` est un outil système que nous installons pour pouvoir vérifier si le serveur web fonctionne correctement plus tard (le fameux "healthcheck").
3. **Le port (`EXPOSE 80`)** : La consigne spécifiait que l'app doit tourner sur le port `80/tcp`. Nous exposons donc ce port.
4. **Le Healthcheck (`HEALTHCHECK`)** : Nous définissons directement dans l'image comment Docker doit vérifier si notre serveur web est en bonne santé. Il va utiliser la commande `curl -f http://localhost:80/` pour s'assurer que la page répond.
5. **La commande finale (`CMD`)** : Au lieu de démarrer l'application avec un script basique, nous utilisons le serveur web intégré de Flask (`flask run`) en le configurant pour écouter sur toutes les interfaces réseau du conteneur (`--host=0.0.0.0`) et sur le port `80`.

## L'intérêt technique de Docker
Grâce au Dockerfile, l'application devient 100% portable. Plus besoin d'installer Python ou les dépendances localement sur votre machine (comme on a pu le voir dans les étapes précédentes). N'importe qui sur n'importe quel ordinateur pourra faire tourner l'application avec la garantie qu'elle fonctionnera de la même manière partout.
