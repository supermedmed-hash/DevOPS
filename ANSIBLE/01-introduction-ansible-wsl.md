# Leçon 1 : Introduction à Ansible, WSL et Déploiement Automatisé

Dans cette leçon, nous allons explorer comment utiliser **Ansible**, un outil d'automatisation puissant, directement depuis **WSL** (Windows Subsystem for Linux) pour configurer un serveur Web Nginx.

Puisque nous n'avons pas de vraie Machine Virtuelle (VM) distante sous la main, nous utilisons une astuce très formatrice : **nous utilisons WSL à la fois comme "machine de contrôle" (qui exécute Ansible) et comme "machine cible" (qui reçoit l'installation)**.

---

## 1. Qu'est-ce qu'Ansible ?

Ansible est un outil DevOps de "gestion de configuration" (Configuration Management). Il permet de décrire l'état souhaité de vos serveurs dans des fichiers texte (les *Playbooks*), et Ansible se charge de s'y connecter pour installer les paquets, modifier les fichiers, et démarrer les services nécessaires.

**Avantages clés :**
- **Sans agent (Agentless)** : Il n'y a pas besoin d'installer un logiciel "client" spécifique sur les machines cibles. Ansible utilise simplement une connexion **SSH** standard.
- **Idempotent** : Vous pouvez exécuter un Playbook Ansible 100 fois, si le serveur est déjà dans l'état demandé, Ansible ne fera rien. Cela évite de casser ce qui fonctionne déjà.

## 2. Configuration SSH (La clé du sans agent)

Pour qu'Ansible puisse se connecter à une machine, il faut qu'il puisse ouvrir une session SSH, idéalement sans mot de passe.
Nous avons configuré cela dans WSL en générant une paire de clés SSH :
1. Clé privée (`id_rsa`) : gardée secrète par l'utilisateur Ansible (`leandro`).
2. Clé publique (`id_rsa.pub`) : placée dans le fichier `authorized_keys` de la machine cible.

Comme notre cible est *notre propre WSL*, nous avons copié notre propre clé publique dans notre propre fichier `authorized_keys` ! Ainsi, Ansible peut faire `ssh leandro@172.30.131.231` et être accepté instantanément.

## 3. Les concepts clés d'Ansible (La structure du projet)

Dans notre dossier `ANSIBLE`, nous avons créé plusieurs fichiers qui constituent la base d'un projet Ansible.

### A. L'Inventaire (`inventory.ini`)

L'inventaire est véritablement le "carnet d'adresses" d'Ansible. Sans lui, Ansible ne sait pas à qui parler ni sur quelles machines agir. Il liste les machines cibles et permet de les organiser par groupes logiques.

Voici le contenu de notre fichier :
```ini
[webservers]
172.30.131.231 ansible_user=leandro
```

**Analyse ligne par ligne :**
- `[webservers]` : C'est la déclaration d'un **groupe**. Cela permet d'appliquer une configuration à plusieurs machines en même temps. Dans un environnement de production, vous pourriez avoir 10 adresses IP listées sous cette balise.
- `172.30.131.231` : C'est l'adresse IP de notre machine cible (ici, l'IP interne de notre WSL).
- `ansible_user=leandro` : C'est une **variable d'hôte**. Elle indique explicitement à Ansible : *"Quand tu te connectes en SSH à cette adresse IP, utilise le compte 'leandro'."*

### B. Le Playbook (`playbook.yml`)

Si l'inventaire est le carnet d'adresses, le Playbook est la **recette de cuisine** (ou le chef d'orchestre). Il décrit l'état final que vous souhaitez obtenir sur vos serveurs. Il est écrit en YAML, un format très lisible qui se base strictement sur l'indentation (les espaces).

Voici le contenu de notre playbook :
```yaml
---
- name: Deploy Nginx with custom page
  hosts: webservers
  become: yes
  roles:
    - nginx
```

**Analyse ligne par ligne :**
- `---` : Indique traditionnellement le début d'un document YAML.
- `- name: Deploy Nginx with custom page` : C'est le titre de cette séquence d'actions (un **Play**). Il s'affichera dans le terminal lors de l'exécution pour vous indiquer ce qu'Ansible est en train de faire. C'est purement pour la lisibilité humaine.
- `hosts: webservers` : C'est la ligne qui fait le lien avec l'inventaire ! On ordonne à Ansible : *"Exécute la suite sur toutes les machines qui appartiennent au groupe [webservers]"*.
- `become: yes` : C'est l'élévation de privilèges (l'équivalent de faire `sudo` sous Linux). L'installation de logiciels requiert des droits d'administrateur. Cette ligne autorise Ansible à passer `root` une fois connecté.
- `roles:` et `- nginx` : Plutôt que de rédiger une longue liste de tâches (installer un paquet, copier un fichier, etc.) directement dans ce fichier, on fait appel à un **Rôle** (nommé `nginx`). Un rôle est comme un "sous-programme" qui contient toutes les instructions complexes, ce qui permet de garder le playbook principal très court et facile à lire.

### C. Les Rôles (`roles/`)
Un rôle est un "paquet" réutilisable de configuration. Il est structuré de manière très stricte.
Notre rôle `nginx` contient :

1. **`tasks/main.yml`** : La liste des actions à effectuer.
   - Utilise le module `apt` pour installer Nginx.
   - Utilise le module `copy` pour envoyer notre fichier `index.html` vers `/var/www/html/`.
   - Utilise le module `service` pour s'assurer que Nginx est allumé.

2. **`files/index.html`** : Les fichiers bruts que nous voulons transférer sur la machine cible. C'est ici que se trouve notre page avec "It works!".

## 4. Exécution

Pour lancer le déploiement, on utilise la commande :
```bash
ansible-playbook -i inventory.ini playbook.yml
```

1. Ansible lit `inventory.ini` pour trouver la cible (172.30.131.231).
2. Il lit `playbook.yml` et voit qu'il doit appliquer le rôle `nginx` sur cette cible avec les droits d'admin (`become: yes`).
3. Il se connecte en SSH (sans mot de passe grâce à notre configuration).
4. Il exécute séquentiellement les tâches de `tasks/main.yml`.
5. Si tout se passe bien, il affiche `changed` ou `ok` pour chaque tâche, et à la fin un résumé `PLAY RECAP`.

Vous pouvez ensuite ouvrir l'adresse IP (ou `http://localhost` depuis Windows) pour voir votre page Nginx !

## 5. Historique Technique (Ce qui a été fait sous le capot)

Pour mettre en place cet environnement et que tout fonctionne "magiquement", voici les commandes et actions exactes qui ont été exécutées en arrière-plan dans votre WSL :

**Étape 1 : Installation des prérequis**
Nous avons mis à jour la liste des paquets Ubuntu et installé Ansible ainsi que le serveur SSH.
```bash
sudo apt-get update
sudo apt-get install -y ansible openssh-server
```

**Étape 2 : Démarrage du service SSH**
Pour simuler une VM cible en écoute, nous avons démarré le service SSH local.
```bash
sudo service ssh start
```

**Étape 3 : Création de la paire de clés SSH**
Nous avons généré une clé SSH pour votre utilisateur `leandro` sans définir de mot de passe dessus (indispensable pour l'automatisation sans intervention humaine).
```bash
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
```

**Étape 4 : Autorisation de la clé (simulation de `ssh-copy-id`)**
La clé publique que nous venons de créer a été ajoutée à la liste des clés autorisées du même utilisateur. Cela permet de se connecter à l'IP de WSL sans taper de mot de passe.
```bash
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**Étape 5 : Configuration de `sudo` pour l'utilisateur**
Pour qu'Ansible puisse utiliser l'option `become: yes` (qui sert à devenir administrateur/root) sans rester bloqué à demander un mot de passe dans le terminal, nous avons autorisé `leandro` à utiliser sudo sans mot de passe :
```bash
echo 'leandro ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/leandro
```

**Étape 6 : Création de l'arborescence Ansible**
Tous les fichiers (`inventory.ini`, `playbook.yml`, et les dossiers `roles/nginx/...`) ont été créés depuis Windows dans votre dossier `DevOPS`. Comme WSL partage les fichiers avec Windows, Ansible (qui s'exécute sur Ubuntu) a pu lire et exécuter ces fichiers directement (ils sont accessibles sous `/mnt/c/Users/leand/Desktop/...` pour WSL).

**Étape 7 : Lancement du Playbook**
Enfin, la commande d'exécution a été lancée depuis l'intérieur de WSL :
```bash
ansible-playbook -i inventory.ini playbook.yml
```
