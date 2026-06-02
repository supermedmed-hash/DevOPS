# Étape 2 : L'Environnement Virtuel (Virtualenv)

## Qu'est-ce que c'est ?
Un environnement virtuel Python (`venv`) est un dossier isolé dans lequel on va installer les dépendances (bibliothèques) spécifiques à un projet, sans polluer l'installation globale de Python sur la machine.

## Le choix technique dans ce projet
Le `README.md` recommande fortement l'utilisation d'un environnement virtuel ("garder votre machine clean"). L'intérêt est multiple :
- **Isolation** : Chaque projet a ses propres versions de bibliothèques. Cela évite les conflits si le projet A a besoin de la version 1.0 d'une bibliothèque, et le projet B de la version 2.0.
- **Propreté** : On évite d'installer des centaines de paquets sur le système global de votre ordinateur.
- **Portabilité** : Il est plus facile de savoir exactement de quelles dépendances le projet a besoin et de les partager avec d'autres développeurs.

## Comment ça fonctionne ?
1. On crée l'environnement avec la commande : `python -m venv venv` (le deuxième `venv` est le nom que l'on donne au dossier).
2. On l'active : `.\venv\Scripts\activate` (sur un système Windows en PowerShell).
3. Une fois activé, toute installation de paquet (via `pip`) se fera uniquement dans ce dossier isolé.
