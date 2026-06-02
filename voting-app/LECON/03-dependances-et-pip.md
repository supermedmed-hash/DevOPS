# Étape 3 : Gestionnaire de Paquets (Pip) et Dépendances

## Qu'est-ce que cest ?
**Pip** (Pip Installs Packages) est l'outil standard (le gestionnaire de paquets) pour installer des bibliothèques externes en Python.
Une **dépendance** est un code (une bibliothèque) écrit par d'autres personnes que l'on utilise dans notre projet pour ne pas avoir à "réinventer la roue". On dit que notre projet *dépend* de ce code pour fonctionner.

## Les dépendances de ce projet
Dans notre application de vote, deux dépendances majeures sont mentionnées dans le README :
1. **Flask** : C'est un micro-framework web pour Python. Il permet de créer très facilement un serveur web, de définir les routes (les différentes URL de l'application) et de renvoyer du code HTML (les pages web que l'utilisateur verra).
2. **Redis (le paquet Python)** : C'est une bibliothèque qui permet au code Python de se connecter et de communiquer avec une base de données Redis.

## L'intérêt technique
Utiliser `Flask` permet de gagner un temps précieux plutôt que de coder un serveur HTTP complexe de zéro. Utiliser le paquet `redis` permet d'exécuter des requêtes vers la base de données de manière très simple et optimisée.

## Comment ça fonctionne avec un `requirements.txt` ?
Pour faciliter le déploiement et le partage, la bonne pratique (plutôt que de taper `pip install flask redis` manuellement) est de lister toutes nos dépendances dans un fichier texte souvent nommé **`requirements.txt`**. 

Ensuite, on utilise une seule commande :
`pip install -r requirements.txt`

Pip va lire ce fichier ligne par ligne et télécharger tous les paquets nécessaires depuis internet (le dépôt officiel PyPI). C'est exactement cette méthode "propre" que nous utilisons dans notre `Dockerfile` !
