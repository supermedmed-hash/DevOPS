FROM python:3.13-slim

WORKDIR /app

# Installation de curl pour le healthcheck et des dépendances python
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copie du fichier des dépendances
COPY requirements.txt /app/

# Installation des dépendances Python via requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code source dans le conteneur
COPY azure-vote/ /app/

# On expose le port 80 pour que Docker sache sur quel port l'app écoute en interne
EXPOSE 80

# Variable d'environnement pour dire à Flask où se trouve le point d'entrée
ENV FLASK_APP=main.py

# Définition du Healthcheck directement dans l'image
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=10s \
  CMD curl -f http://localhost:80/ || exit 1

# Commande de lancement
CMD ["flask", "run", "--host=0.0.0.0", "--port=80"]
