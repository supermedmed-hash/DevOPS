# Leçon 3 : Écrire un template Packer pour Docker avec Ansible

Packer est un outil open-source HashiCorp permettant de créer des images de machines identiques pour de multiples plateformes à partir d'une configuration source unique. Dans cette leçon, nous allons voir en détail comment utiliser Packer pour créer une image Docker en utilisant Ansible pour le provisionnement.

## 1. Structure d'un fichier `.pkr.hcl`

Depuis sa version 1.7, Packer utilise par défaut le langage HCL (HashiCorp Configuration Language), le même langage utilisé par Terraform. Un fichier de configuration Packer classique (`.pkr.hcl`) se divise généralement en trois blocs principaux :

### A. Le bloc `packer` (Plugins)
Ce bloc définit les plugins (builders, provisioners) nécessaires pour exécuter le template. Packer téléchargera ces plugins automatiquement lors de l'exécution de la commande `packer init`.

```hcl
packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}
```

### B. Le bloc `source` (L'environnement de base)
Le bloc source définit **comment** et **à partir de quoi** l'image sera construite. C'est ici que l'on configure le "builder". Dans notre cas, il s'agit du builder `docker`.

```hcl
source "docker" "ubuntu_voting_app" {
  # L'image de base à partir de laquelle on démarre
  image  = "ubuntu:24.04"
  # On commit le conteneur final en image Docker
  commit = true
  
  # Configuration spécifique au builder Docker (remplace les instructions Dockerfile)
  changes = [
    "ENV FLASK_APP=main.py",
    "EXPOSE 80",
    "WORKDIR /app",
    "CMD [\"flask\", \"run\", \"--host=0.0.0.0\", \"--port=80\"]"
  ]
}
```

### C. Le bloc `build` (Le provisionnement)
Le bloc `build` assemble les sources et définit les étapes de provisionnement (comment installer les dépendances, copier le code, etc.). C'est ici que l'on appelle Ansible.

```hcl
build {
  # On référence la source définie précédemment
  sources = [
    "source.docker.ubuntu_voting_app"
  ]

  # Provisioner Ansible pour configurer l'image
  provisioner "ansible" {
    playbook_file = "./playbook.yaml"
    user          = "root"
    extra_arguments = [
      "--scp-extra-args", "'-O'"
    ]
  }

  post-processor "docker-tag" {
    repository = "voting-app-packer"
    tags       = ["latest"]
  }
}
```

## 2. Le Provisioner Ansible avec Docker

L'utilisation d'Ansible avec le builder Docker de Packer nécessite une attention particulière. Par défaut, Packer va créer un conteneur temporaire, et Ansible va essayer de s'y connecter via SSH. Cependant, les conteneurs Docker n'ont généralement pas de serveur SSH actif par défaut.

Pour pallier ce problème, le plugin Ansible de Packer utilise une connexion spéciale (`docker` connection plugin pour Ansible). Mais pour que cela fonctionne, Ansible (installé sur votre machine hôte ou WSL) a besoin de pouvoir exécuter des commandes à l'intérieur du conteneur. Cela requiert souvent que **Python** soit installé sur l'image de base (ainsi que les paquets liés au SSH/SFTP dans certains cas).

C'est pourquoi, dans un playbook Ansible utilisé par Packer pour Docker, il est obligatoire d'avoir un premier "play" (ou d'utiliser un provisioner `shell` avant Ansible) pour installer Python, de la manière suivante :

```yaml
# Extrait du playbook.yaml
- name: Provision Python
  hosts: all
  gather_facts: false
  tasks:
    - name: Boostrap python
      ansible.builtin.raw: test -e /usr/bin/python3 || (apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3 openssh-client openssh-sftp-server && ln -sf /usr/lib/openssh/sftp-server /usr/lib/sftp-server && mkdir -p /root/.ansible/tmp)
```
*Le module `raw` permet d'exécuter une commande bash pure sans avoir besoin de Python au préalable sur la cible.*

## 3. Les commandes clés de Packer

Une fois votre fichier `.pkr.hcl` rédigé, voici le workflow standard pour construire l'image :

1.  **Initialisation :**
    `packer init template.pkr.hcl`
    *Cette commande télécharge les plugins déclarés dans le bloc `required_plugins`.*

2.  **Formatage (optionnel mais recommandé) :**
    `packer fmt template.pkr.hcl`
    *Rend le code HCL propre et standardisé.*

3.  **Validation :**
    `packer validate template.pkr.hcl`
    *Vérifie la syntaxe de votre template avant de lancer un long processus de build.*

4.  **Construction :**
    `packer build template.pkr.hcl`
    *Lance la création de l'image. Packer va démarrer un conteneur Ubuntu, exécuter le playbook Ansible à l'intérieur, puis "commit" le résultat sous forme d'une nouvelle image Docker avec les tags demandés.*

## En résumé

*   **HCL** est le langage moderne pour Packer.
*   **`source`** définit l'image de base et le type de builder (ici Docker), ainsi que les paramètres du futur conteneur (`changes`).
*   **`build`** lie la source à vos outils de configuration (ici `ansible`).
*   Avec Ansible + Docker, assurez-vous que **Python** est bien installé au tout début du processus pour que les modules Ansible fonctionnent correctement.
