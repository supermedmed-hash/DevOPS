# Leçon 2 : Introduction à Packer et Déploiement d'Images Docker via Ansible

Dans cette leçon, nous allons apprendre à utiliser **Packer** (de HashiCorp) pour créer une image Docker de notre **Voting App**, en réutilisant notre configuration **Ansible**.

---

## 1. Pourquoi utiliser Packer avec Ansible ?

Généralement, pour créer une image Docker, on utilise un `Dockerfile` classique avec des instructions `RUN apt-get install...`. 
Cependant, dans beaucoup d'entreprises, l'infrastructure-as-code (IaC) et les configurations système sont déjà écrites avec **Ansible**.

**Packer** permet de faire le pont entre ces deux mondes :
1. Packer démarre un conteneur temporaire à partir d'une image de base (ex: `ubuntu:24.04`).
2. Packer exécute vos playbooks **Ansible** sur ce conteneur pour y installer vos dépendances et votre code.
3. Packer sauvegarde (sauvegarde par *commit*) le conteneur modifié sous forme d'une nouvelle image Docker prête à l'emploi.

---

## 2. La structure du projet dans `S2`

Pour réaliser cet exercice, voici comment nous avons structuré le dossier `S2` :

```text
S2/
├── 02-introduction-packer-ansible.md  # Cette leçon !
├── playbook.yaml                      # Le playbook Ansible corrigé
├── template.pkr.hcl                   # Le fichier de configuration Packer (HCL)
├── azure-vote/                        # Copie du code source de l'application Flask
└── roles/
    └── deps/
        └── tasks/
            └── main.yml               # Rôle Ansible pour installer les dépendances (Flask, Redis, Requests)
```

---

## 3. Explications des fichiers de configuration

### A. Le Playbook Ansible corrigé (`playbook.yaml`)
Le playbook contient deux séquences principales :
1. **Provision Python** : 
   * Docker utilise des images Ubuntu extrêmement légères et sans Python installé. Ansible ayant besoin de Python pour s'exécuter, cette étape installe Python 3, mais aussi les utilitaires SSH/SFTP nécessaires au transfert des fichiers par Ansible.
   * Nous y avons ajouté `DEBIAN_FRONTEND=noninteractive` pour éviter que l'installateur ne se bloque en demandant un fuseau horaire (tzdata).
2. **Install deps and copy source code** :
   * Appelle le rôle `deps` pour installer Flask, Redis et Requests.
   * Copie le code source de l'application de votre machine hôte (`./azure-vote`) vers le dossier `/app` du conteneur.

### B. Le Rôle Deps (`roles/deps/tasks/main.yml`)
Ce rôle automatise l'installation de Python Pip (le gestionnaire de paquets) et installe les paquets demandés :
```yaml
---
- name: Ensure apt cache is updated and pip is installed
  ansible.builtin.apt:
    name:
      - python3-pip
      - python3-venv
    state: present
    update_cache: yes
  environment:
    DEBIAN_FRONTEND: noninteractive

- name: Remove conflicting system package python3-blinker
  ansible.builtin.apt:
    name: python3-blinker
    state: absent
  environment:
    DEBIAN_FRONTEND: noninteractive

- name: Install Python dependencies
  ansible.builtin.pip:
    name: "{{ pip_packages }}"
    state: present
    extra_args: --break-system-packages
```
*Note : Sur les versions récentes d'Ubuntu, `pip` refuse d'installer des paquets globalement pour ne pas corrompre le système. L'argument `--break-system-packages` permet de forcer l'installation globale dans le cadre de notre conteneur.*

### C. Le Template Packer (`template.pkr.hcl`)
C'est le fichier écrit en **HCL** (HashiCorp Configuration Language) qui pilote le build :
```hcl
packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
    ansible = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

source "docker" "ubuntu" {
  image  = "ubuntu:24.04"
  commit = true
  # Ces directives configurent les métadonnées de l'image finale (équivalent aux instructions Dockerfile)
  changes = [
    "ENV FLASK_APP=main.py",
    "EXPOSE 80",
    "WORKDIR /app",
    "CMD [\"flask\", \"run\", \"--host=0.0.0.0\", \"--port=80\"]"
  ]
}

build {
  name = "voting-app"
  sources = [
    "source.docker.ubuntu"
  ]

  # Provisionnement via le playbook Ansible
  provisioner "ansible" {
    playbook_file = "./playbook.yaml"
    user          = "root"
    extra_arguments = [
      "--scp-extra-args", "'-O'" # Force l'utilisation du protocole SCP classique pour la compatibilité
    ]
  }

  # Tag de l'image finale
  post-processor "docker-tag" {
    repository = "voting-app-packer"
    tags       = ["latest"]
  }
}
```

---

## 4. Comment exécuter le Build ?

Tout se passe depuis votre WSL (où nous avons installé Packer et Ansible) :

1. **Initialiser Packer** (télécharge les plugins Docker et Ansible) :
   ```bash
   packer init template.pkr.hcl
   ```

2. **Lancer la construction de l'image** :
   ```bash
   packer build template.pkr.hcl
   ```

Une fois terminé, vous pouvez lister vos images sur Windows ou WSL avec `docker images` : l'image `voting-app-packer:latest` apparaîtra et sera prête à démarrer !
