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

source "docker" "voting_app" {
  image  = "ubuntu:22.04"
  commit = true
  
  changes = [
    "EXPOSE 80",
    "CMD [\"python3\", \"/app/main.py\"]"
  ]
}

build {
  sources = [
    "source.docker.voting_app"
  ]

  provisioner "ansible" {
    playbook_file = "./S2/playbook.yaml"
    user          = "root"
    # Packer utilise une connexion docker spécifique pour l'inventaire
    # et a besoin que Python soit installé, ce qui est géré par le 1er play.
    extra_arguments = [
      "--extra-vars", "ansible_python_interpreter=/usr/bin/python3",
      "--scp-extra-args", "'-O'"
    ]
  }
}
