# dbt-demo

Projet dbt (voir `dbt_demo_project/`) transformant des données Snowflake selon une architecture bronze / silver / gold. Déployé via CI/CD Snowflake-native (voir `.github/workflows/`).

## Installer dbt (reprendre le projet)

Le projet est déjà initialisé avec `uv` (`pyproject.toml` + `uv.lock` commités). Un développeur qui récupère le repo n'a pas besoin de recréer le projet, juste d'installer `uv` et de resynchroniser l'environnement à partir des fichiers existants.

```bash
# Installe uv (gestionnaire de paquets/environnements Python) si ce n'est pas déjà fait
curl -LsSf https://astral.sh/uv/install.sh | sh

# Se place à la racine du repo (là où se trouvent pyproject.toml et uv.lock)
cd dbt_demo

# Crée un environnement virtuel (.venv) et installe exactement les versions verrouillées dans uv.lock (dbt-core, dbt-snowflake, etc.) — n'installe rien de plus récent que ce qui a été figé
uv sync

# Vérifie que dbt est bien installé dans l'environnement, sans avoir à activer le venv manuellement (uv run exécute la commande dans le .venv)
uv run dbt --version
```

Il reste ensuite à configurer la connexion Snowflake, qui n'est **pas** commitée dans le repo (fichier sensible) :

```bash
# Crée le dossier de config dbt (~/.dbt) s'il n'existe pas encore
mkdir -p ~/.dbt

# Ouvre/crée le fichier profiles.yml pour y renseigner manuellement les identifiants Snowflake
nano ~/.dbt/profiles.yml
```

Dans ce `profiles.yml`, le profil doit s'appeler `dbt_demo_project` (nom défini dans `dbt_demo_project/dbt_project.yml`) et déclarer les targets `dev` et/ou `prod` avec les infos de connexion Snowflake (account, user, rôle, warehouse, méthode d'auth). Demander ces identifiants à l'équipe/l'admin Snowflake — ils ne sont pas dans le repo.

Une fois `profiles.yml` en place, se placer dans `dbt_demo_project/` et lancer :

```bash
# Vérifie que dbt arrive à se connecter à Snowflake avec le profil configuré
cd dbt_demo_project
uv run dbt debug
```

## Installer Claude Code (WSL)

```bash
# Télécharge le script d'installation officiel de Claude Code et l'exécute directement (installe le binaire natif, sans Node.js/npm)
curl -fsSL https://claude.ai/install.sh | bash

# Ajoute le dossier ~/.local/bin (où le binaire "claude" a été installé) au PATH, ajoute cette ligne au ~/.bashrc pour que ce soit permanent, puis recharge le ~/.bashrc dans le terminal actuel
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

# Vérifie que la commande "claude" est bien accessible et affiche la version installée
claude --version
```

Puis, dans le dossier du repo :

```bash
# Lance Claude Code dans le dossier courant ; au démarrage il détecte et charge automatiquement le fichier CLAUDE.md du repo
claude
```

Le fichier `CLAUDE.md` (à la racine) est commité dans le repo : il documente l'architecture du projet et est chargé automatiquement par Claude Code au démarrage. Il n'est donc pas nécessaire de relancer `/init` — sauf si l'architecture du projet évolue et que la doc doit être mise à jour.
