# Leçon 4 : CI/CD avec GitHub Actions, Docker et Docker Scout

Dans cette leçon, nous allons décortiquer la pipeline CI/CD que nous avons mise en place pour automatiser le build, le test, le scan de sécurité et le déploiement de notre **Voting App** sur Docker Hub.

---

## 1. C'est quoi une pipeline CI/CD ?

**CI** = Continuous Integration (Intégration Continue)  
**CD** = Continuous Delivery (Livraison Continue)

L'idée est simple : **à chaque fois que vous poussez du code sur `main`**, un ensemble d'étapes automatiques se déclenche pour vérifier que votre code est correct, le construire, le tester, et le livrer, **sans intervention humaine**.

```
  Push sur main
       │
       ▼
  ┌─────────┐     ┌──────────────┐     ┌───────────────┐     ┌──────────────┐
  │  🔍 Lint │────▶│ 🏗️ Build &   │────▶│ 🛡️ Security   │────▶│ 🚀 Push to   │
  │Dockerfile│     │    Test      │     │    Scan       │     │  Docker Hub  │
  └─────────┘     └──────────────┘     └───────────────┘     └──────────────┘
       ❌ ?              ❌ ?                 ❌ ?
    On arrête          On arrête           On arrête
    tout !             tout !              tout !
```

Si **une seule étape échoue**, les suivantes ne s'exécutent pas. On ne pousse jamais une image cassée ou vulnérable sur Docker Hub.

---

## 2. Où ça se passe ?

GitHub Actions exécute votre pipeline sur des **machines virtuelles éphémères** (appelées "runners") hébergées par GitHub. Chaque job démarre sur une machine Ubuntu fraîche, exécute les commandes, puis la machine est détruite.

Le fichier de configuration se trouve dans :
```
.github/workflows/docker.yml
```
GitHub détecte automatiquement ce fichier et l'exécute à chaque push.

---

## 3. Structure du fichier `docker.yml`

### A. Le déclencheur (`on`)

```yaml
on:
  push:
    branches:
      - main
```
Le workflow ne se lance **que** lors d'un `push` sur la branche `main`. Un push sur une autre branche (ex: `dev`) ne déclenche rien.

### B. Les variables d'environnement globales (`env`)

```yaml
env:
  IMAGE_NAME: voting-app
```
On définit le nom de l'image **une seule fois** ici, puis on le réutilise partout avec `${{ env.IMAGE_NAME }}`. Si on veut renommer l'image, on ne modifie qu'une seule ligne. C'est une **bonne pratique** (principe DRY : Don't Repeat Yourself).

---

## 4. Les 4 Jobs de la pipeline

### Job 1 : 🔍 Lint du Dockerfile

```yaml
lint:
  name: 🔍 Lint Dockerfile
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: hadolint/hadolint-action@v3.1.0
      with:
        dockerfile: voting-app/Dockerfile
```

**Qu'est-ce que le Linting ?**  
C'est une analyse **statique** de votre Dockerfile. L'outil **Hadolint** vérifie que vous suivez les bonnes pratiques Docker :
- Est-ce que vous épinglez les versions de vos packages ?
- Est-ce que vous nettoyez le cache apt après installation ?
- Est-ce que vous utilisez `COPY` au lieu de `ADD` ?

C'est comme un correcteur d'orthographe, mais pour votre Dockerfile.

---

### Job 2 : 🏗️ Build & Test

Ce job ne démarre **que si le lint est passé** (`needs: lint`).

#### Étape 1 : Build de l'image Docker
```yaml
- name: Build Docker image
  run: docker build -t ${{ secrets.DOCKER_USERNAME }}/${{ env.IMAGE_NAME }}:latest ./voting-app
```
On construit l'image exactement comme on le ferait en local avec `docker build`.

#### Étape 2 : Lancement de l'application
```yaml
- name: Start application stack
  working-directory: voting-app
  run: docker compose up -d
```
On lance Redis + l'application avec `docker compose`, comme en local. Le `-d` (detached) lance les conteneurs en arrière-plan.

#### Étape 3 : Attente du Healthcheck
```yaml
- name: Wait for Healthcheck
  run: |
    for i in $(seq 1 12); do
      STATUS=$(docker inspect --format='{{.State.Health.Status}}' voting-app-web 2>/dev/null || echo "starting")
      echo "⏳ Tentative $i/12 - Status: $STATUS"
      if [ "$STATUS" = "healthy" ]; then
        echo "✅ Application is healthy!"
        break
      fi
      if [ "$i" = "12" ]; then
        echo "❌ Timeout: l'application n'est jamais devenue healthy"
        docker logs voting-app-web
        exit 1
      fi
      sleep 5
    done
```

**Pourquoi ne pas juste faire `sleep 15` ?**  
Parce qu'on ne sait pas combien de temps l'application met à démarrer. Ici, on interroge Docker toutes les 5 secondes pour savoir si le conteneur est "healthy" (grâce au `HEALTHCHECK` défini dans le Dockerfile). C'est :
- **Plus fiable** : on attend le vrai état de l'application, pas un temps arbitraire.
- **Plus rapide** : dès que c'est prêt, on enchaîne sans attendre pour rien.
- **Avec un timeout** : au bout de 60 secondes (12 × 5s), on considère que ça a échoué et on affiche les logs du conteneur pour débugger.

#### Étape 4 : Les Tests

On exécute **3 tests d'intégration** :

| Test | Ce qu'il vérifie |
|------|-----------------|
| **Homepage HTTP 200** | L'application répond bien (pas d'erreur 500) |
| **Contenu de la page** | Les boutons "Cats" et "Dogs" sont bien affichés |
| **POST de vote** | L'action de voter fonctionne correctement |

```yaml
# Test 1 : La page d'accueil répond en HTTP 200
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/)

# Test 2 : Le contenu HTML contient les bons éléments
BODY=$(curl -s http://localhost:8080/)
echo "$BODY" | grep -q "Cats"

# Test 3 : Un vote POST fonctionne
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -d "vote=Cats" http://localhost:8080/)
```

#### Étape 5 : Nettoyage garanti
```yaml
- name: Teardown application stack
  if: always()
  run: docker compose down -v
```

Le `if: always()` est important ! Même si un test échoue, on s'assure de **toujours** éteindre les conteneurs et supprimer les volumes (`-v`). Sans ça, les conteneurs pourraient rester actifs et gaspiller les ressources du runner.

---

### Job 3 : 🛡️ Security Scan

Ce job ne démarre **que si les tests sont passés** (`needs: build-and-test`).

```yaml
- name: Docker Scout - CVE Scan
  uses: docker/scout-action@v1
  with:
    command: cves
    image: local://thzmind/voting-app:latest
    only-severities: critical,high
```

**Docker Scout** analyse l'image construite et compare chaque paquet installé avec les bases de données de vulnérabilités connues (CVE). On filtre uniquement les failles **critiques** et **hautes** pour ne pas être submergé de faux positifs.

Le préfixe `local://` indique à Scout d'analyser l'image **locale** (celle qu'on vient de construire), et non d'essayer de la télécharger depuis Docker Hub.

---

### Job 4 : 🚀 Push to Docker Hub

Ce job ne démarre **que si les tests ET le scan sont passés** (`needs: [build-and-test, security-scan]`).

```yaml
- name: Build and Push Docker image
  uses: docker/build-push-action@v5
  with:
    context: ./voting-app
    push: true
    tags: |
      thzmind/voting-app:latest
      thzmind/voting-app:abc123def456
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

Plusieurs points importants ici :

| Fonctionnalité | Explication |
|----------------|-------------|
| **Double tag** | On pousse l'image avec deux tags : `latest` (toujours la dernière version) et le **SHA du commit** Git (pour pouvoir revenir à une version précise si besoin). |
| **Cache GHA** | `cache-from` et `cache-to` utilisent le système de cache de GitHub Actions. Les couches Docker déjà construites sont réutilisées, ce qui **accélère énormément** les builds suivants. |
| **`push: true`** | L'image est automatiquement poussée sur Docker Hub après le build. |

---

## 5. Les Secrets GitHub

Les identifiants Docker Hub ne sont **jamais** écrits en clair dans le code. Ils sont stockés dans le "coffre-fort" de GitHub :

**Settings > Secrets and variables > Actions** :
- `DOCKER_USERNAME` : votre pseudo Docker Hub
- `DOCKER_PASSWORD` : votre Personal Access Token Docker Hub

Dans le workflow, on y accède avec la syntaxe `${{ secrets.DOCKER_USERNAME }}`. GitHub remplace automatiquement cette variable par la vraie valeur au moment de l'exécution, et elle n'apparaît **jamais** dans les logs.

---

## 6. Le mot-clé `needs` : l'orchestration des Jobs

```yaml
lint:           # Pas de needs → s'exécute en premier
build-and-test:
  needs: lint   # Attend que lint soit ✅
security-scan:
  needs: build-and-test  # Attend que build-and-test soit ✅
push:
  needs: [build-and-test, security-scan]  # Attend que les DEUX soient ✅
```

Cela crée une **chaîne de dépendances** :
```
lint → build-and-test → security-scan → push
```

Si `lint` échoue, rien d'autre ne s'exécute. Si `build-and-test` échoue, on ne scan pas et on ne pousse pas. **On ne livre jamais du code cassé.**

---

## En résumé

| Concept | Ce qu'il faut retenir |
|---------|----------------------|
| **GitHub Actions** | Outil CI/CD intégré à GitHub, configuré via des fichiers YAML dans `.github/workflows/` |
| **Jobs** | Étapes indépendantes qui tournent sur des machines séparées |
| **`needs`** | Permet de définir l'ordre d'exécution des jobs |
| **`if: always()`** | Force l'exécution d'une étape même si les précédentes ont échoué (utile pour le nettoyage) |
| **Secrets** | Variables sensibles stockées dans GitHub, jamais visibles dans le code ni les logs |
| **Hadolint** | Linter pour Dockerfile, vérifie les bonnes pratiques |
| **Docker Scout** | Scanner de vulnérabilités qui détecte les CVE dans vos images |
| **Cache GHA** | Réutilise les couches Docker déjà construites pour accélérer les builds |
| **Multi-tag** | Tagger avec `latest` + SHA du commit pour la traçabilité |
