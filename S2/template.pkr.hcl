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
