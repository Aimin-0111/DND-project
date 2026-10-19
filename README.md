# Brasswake Reach

**Un RPG solo en pixel art, avec un Maître du Jeu IA.** Le récit occupe environ **40 %** de l'écran (texte avec des mots animés), le monde explorable **60 %**. Le jeu possède les règles, les dés et l'état ; l'IA narre et propose des actions limitées.

> **État au 19 octobre 2026 : aucune version jouable.**
> Le [spec](SPEC.md) et le [plan M1](tasks/plan.md) sont approuvés. Le projet Godot sera créé à la tâche 1 de [tasks/todo.md](tasks/todo.md).

---

## Sommaire

- [L'idée en trois points](#lidée-en-trois-points)
- [Ce qui existe / ce qui manque](#ce-qui-existe--ce-qui-manque)
- [Progression par jalon](#progression-par-jalon)
- [Prochaines actions](#prochaines-actions)
- [TODO détaillé](#todo-détaillé)
- [Démarrage rapide](#démarrage-rapide)
- [Structure du dépôt](#structure-du-dépôt)
- [Règles d'équipe](#règles-déquipe)
- [Journal](#journal)
- [Liens](#liens)

---

## L'idée en trois points

1. **Un jeu, pas un chatbot.** Le jeu tient l'état (PV, or, inventaire, quêtes, temps) et lance tous les dés. L'IA ne fait que raconter et envoyer des commandes d'une liste courte, vérifiées par le code.
2. **Deux moitiés d'écran.** À gauche, le monde en pixel art ; à droite, le récit avec effet machine à écrire et mots animés (`burn`, `freeze`, `shock`…).
3. **Art et écriture hors du code.** L'artiste dépose des PNG/Aseprite, le scénariste des Markdown/CSV, et le jeu les charge. Personne n'a besoin de toucher au code pour écrire ou dessiner.

**Direction :**
- Godot 4 (GDScript) proposé, confirmé ou remplacé par TypeScript + Phaser 4 après le prototype M1.
- Un petit runner de tests maison jusqu'à cette décision.
- Pendant M1, les builds web se jouent en local sur l'ordinateur du lead : pas d'envoi sur itch.io pour l'instant. itch.io viendra après M1.
- Un proxy Cloudflare Workers pour la clé API (M2).
- Le code est sur un **dépôt GitHub public** (le lead et Alban). L'art et l'écriture passent par le OneDrive de l'école.

---

## Ce qui existe / ce qui manque

| ✅ Existe | ⬜ Manque |
|---|---|
| Le [spec](SPEC.md) (carte des modules, règles, critères de M1) et 7 specs de modules ; le [plan M1](tasks/plan.md) avec [26 tâches](tasks/todo.md) | Leur réalisation, à partir de la tâche 1 |
| [Plan du projet](docs/PLAN.md) et [questionnaire d'équipe](docs/QUESTIONS-EQUIPE.md) (23 questions), premières réponses consignées le 19 oct. | Les réponses 1, 8, 10, 13, 15 à 23 |
| [Maquettes HTML](examples/interface/mockups.html) : 3 mises en page, effets, panneaux, un tour de jeu | Un projet Godot, une scène, un personnage jouable |
| Des exemples GDScript : dés, état, sauvegardes, parseur IA, prompts, déplacements, effets de texte | Leur intégration dans `game/src/` (prévue tâche par tâche) |
| Un [Worker Cloudflare](examples/proxy/worker.ts) d'exemple pour cacher la clé API | Un Worker déployé et testé (M2) |
| Un [outil Python](examples/tools/balance_sim.py) de vérification des CSV et de simulation de combats | Une version au format des specs (`tools/`, M4) |
| Un [test d'hallucination](examples/ai-tests/RESULTS.md) : 8 scénarios pièges, 6/8 propres | Les deux corrections : décidées, ajoutées à la tâche 8 |
| Des guides et modèles pour [l'artiste](examples/content/art/GUIDE-ARTISTE.md) (8 directions) et [le scénariste](examples/content/writing/pnj-modele.md) | Du contenu réel (zone, PNJ, quêtes, lore) |

> Les fichiers de `examples/` sont des **exemples statiques**, pas le jeu. Les scripts GDScript ont été parse-checkés sur la machine du lead (Godot 4.7.2) selon [examples/README.md](examples/README.md), mais aucun n'a été exécuté dans une vraie scène.

---

## Progression par jalon

Légende : ✅ fait · 🟡 partiel · ⬜ pas commencé.

| Jalon | État | Ce qui est acquis | Ce qui bloque la suite |
|---|---|---|---|
| **Cadrage** | 🟡 | Vision 40/60, plan, questionnaire (premières réponses), étude de coût IA, spec et plan M1 approuvés | Réponses restantes (taille des cases, écriture, organisation) |
| **M0 — Mise en place** | 🟡 | Dépôt GitHub public, docs, spec, plan M1, exemples, guides | Projet Godot (tâche 1), dossiers OneDrive |
| **M1 — Prototype (décision)** | ⬜ | Plan prêt : 26 tâches en 6 phases | Toute la chaîne : zone, héros, texte, IA, build |
| **M2 — Systèmes cœur** | ⬜ | Des exemples de code non intégrés | Sauvegardes, proxy, onglets, premier envoi itch.io |
| **M3 — Monde** | ⬜ | Rien | Zones, PNJ, combat, temps, météo |
| **M4 — Contenu** | ⬜ | Modèles et CSV d'exemple | Art et écriture réels, équilibrage |
| **M5 — Sortie** | ⬜ | Rien | Son, réglages, tutoriel, page publique |

**Avancement des cases : 19 / 67 (28 %)** — comptage simple des cases du TODO, pas une estimation du temps de travail.

---

## Prochaines actions

1. **Tâche 1 — Créer le projet Godot `game/` et le runner de tests** ([tasks/todo.md](tasks/todo.md)).
2. **Tâche 2 — Tester le build web en local** : presse-papiers, appel à l'API, un mot animé, taille et fluidité. Le lead installe d'abord les modèles d'export web de Godot.
3. **Convenir du travail d'Alban** (question Q-7 du [spec](SPEC.md#open-questions)) : branches et pull requests ou envoi direct sur `main`, et quelle piste prendre (le monde, tâches 19–21, ou le contenu, tâches 5–8).
4. **Obtenir les réponses restantes au [questionnaire](docs/QUESTIONS-EQUIPE.md)** : surtout la taille des cases (10) et la forme d'écriture (15–17).

---

## TODO détaillé

> **Source de vérité de l'avancement global.** Une case ne se coche qu'avec une preuve : fichier, commande exécutée, lien ou commit. Mettre à jour la date et le [journal](#journal) en même temps.
> **Pour M1**, le détail (26 tâches, avec critères d'acceptation et vérifications) est dans [tasks/todo.md](tasks/todo.md). On coche la tâche là-bas, et la phase ici quand son checkpoint est atteint.

### 1. Cadrage et décisions

- [x] Fixer la vision : 40 % récit / 60 % scène animée ([docs/PLAN.md](docs/PLAN.md))
- [x] Proposer les choix principaux : moteur, hébergement, proxy, stockage ([docs/PLAN.md](docs/PLAN.md))
- [x] Rédiger le questionnaire d'équipe (23 questions) ([docs/QUESTIONS-EQUIPE.md](docs/QUESTIONS-EQUIPE.md))
- [x] Terminer l'étude de coût IA ([CLAUDE.md](CLAUDE.md))
- [x] Récupérer les premières réponses au questionnaire (19 oct., [docs/PLAN.md](docs/PLAN.md#-team-answers-october-19-2026))
- [x] Trancher : langue, ambiance, déplacements, taille du monde, combat, rôle du MJ, style graphique
- [x] Écrire et faire approuver le spec : [SPEC.md](SPEC.md) + 7 specs de modules
- [x] Écrire et faire approuver le plan M1 : [tasks/plan.md](tasks/plan.md), [tasks/todo.md](tasks/todo.md)
- [ ] Récupérer les réponses restantes : 1, 8, 10, 13, 15 à 23
- [ ] Trancher : plateforme (téléphones), effets animés, taille des cases
- [ ] Convenir du travail d'Alban dans le dépôt (Q-7)
- [ ] Confirmer Godot 4 (ou basculer sur TypeScript + Phaser 4) et choisir l'outil de test après le prototype M1
- [ ] Choisir le modèle IA après un test de jeu réel

### 2. M0 — Mise en place

- [x] Créer le dépôt Git et le remote GitHub (`origin`)
- [x] Ajouter un `.gitignore` (cache Godot, builds, secrets, Node)
- [x] Écrire le plan, le questionnaire et les exemples statiques
- [x] Écrire les guides de l'artiste et du scénariste
- [ ] Créer le projet Godot `game/` avec le squelette de dossiers du spec (tâche 1) ; `proxy/` et `tools/` viendront en M2 et M4
- [ ] Partager les dossiers OneDrive `art/`, `writing/`, `data/`
- [ ] Installer les modèles d'export web de Godot (tâche 2) et l'extension VS Code `godot-tools` (GitHub Desktop facultatif ; `butler` viendra plus tard)

### 3. M1 — Prototype de décision

Détail : [tasks/todo.md](tasks/todo.md). Une case = une phase, cochée à son checkpoint.

- [ ] Phase 0 : projet Godot, runner de tests, test du build web en local (tâches 1–2)
- [ ] Phase 1 : état, dés, règles ; lecture et vérification des fichiers de l'équipe ; données et textes M1 (tâches 3–8)
- [ ] Phase 2 : premier tour jouable en texte, mode copier-coller, dans le build web (tâches 9–14)
- [ ] Phase 3 : machine à écrire, **3 mots animés**, clé personnelle, anglais + français (tâches 15–18)
- [ ] Phase 4 : la zone du chemin du moulin, le héros qui marche en 8 directions ; l'IA déplace le héros et fait apparaître un loup (tâches 19–23)
- [ ] Phase 5 : chaîne de build, mesures (fluidité, taille, démarrage), puis décision **on garde Godot** ou **on passe à Phaser** (tâches 24–26)

### 4. M2 — Systèmes cœur

- [ ] Sauvegardes versionnées et migrations (l'état v1 et les dés seedés sont faits en M1)
- [ ] Sauvegarde automatique après chaque tour, reprise après rechargement
- [ ] Ajouter le journal d'actions et le bouton Rewind
- [ ] Ajouter le mode proxy aux deux modes de M1, derrière la même interface (copier-coller, clé personnelle, proxy)
- [ ] Déployer le Worker Cloudflare, y placer la clé en secret et limiter le débit
- [ ] Remplacer « l'intro + les 3 dernières narrations » par le résumé d'histoire glissant
- [ ] Construire les panneaux Fiche, Sac, Quêtes et Codex
- [ ] Importer et exporter les sauvegardes
- [ ] Disposition empilée pour écrans étroits ou téléphones (selon la question 1)
- [ ] Créer la page itch.io privée et y mettre un premier build (date à fixer, Q-6)

### 5. M3 — Monde

- [ ] Relier plusieurs zones par des voyages
- [ ] Lieux importants faits à la main ; le reste généré une fois et stocké dans la sauvegarde (réponse 5)
- [ ] Faire vivre les PNJ et les créatures
- [ ] Finaliser la liste blanche des commandes IA et le réalisateur de scène (météo, émotions)
- [ ] Implémenter le combat au tour par tour, avec dés et animations (réponse 6)
- [ ] Ajouter le cycle jour/nuit et la météo

### 6. M4 — Contenu

- [ ] Valider la chaîne d'art : PNG/Aseprite → import Godot → animation
- [ ] Produire une tranche verticale : une zone, des PNJ, une chaîne de quêtes, du lore
- [ ] Porter `balance_sim.py` au format des specs (`tools/`) et le lancer avant chaque ajout de contenu
- [ ] Installer un rythme de livraison pour l'artiste et le scénariste

### 7. M5 — Sortie

- [ ] Ajouter musiques et effets sonores
- [ ] Ajouter les réglages et l'accessibilité (« réduire les animations » existe dès M1)
- [ ] Écrire le tutoriel
- [ ] Relire toutes les traductions (le jeu est bilingue dès M1)
- [ ] Publier la page itch.io publique et le build desktop
- [ ] Organiser une boucle de playtests avec retours

### 8. Qualité de l'IA et tests

- [x] Écrire 8 scénarios pièges ([scenarios.md](examples/ai-tests/scenarios.md))
- [x] Tester Haiku et documenter les résultats ([RESULTS.md](examples/ai-tests/RESULTS.md))
- [ ] Ajouter les deux règles proposées (ne pas inventer un lieu/personnage absent ; envoyer `move_to` quand le récit déplace le héros) : tâche 8
- [ ] Relancer S1 et S8 : 3 fois chacun dans le vrai jeu au checkpoint 2, puis 5 fois avec le modèle choisi avant M2
- [ ] Comparer Haiku et Sonnet 5.5 sur les mêmes scénarios
- [ ] Tester le vrai appel API : clé personnelle en M1 (tâche 17), proxy en M2
- [ ] Mesurer le coût réel par tour et le gain du cache de prompt
- [ ] Automatiser les tests du parseur : les 8 réponses Haiku deviennent des fixtures (tâche 10)

### 9. Documentation et pilotage

- [x] Écrire `CLAUDE.md` (notes pour les agents Claude)
- [x] Écrire [examples/README.md](examples/README.md)
- [x] Écrire ce README avec le TODO
- [x] Écrire [AGENTS.md](AGENTS.md), la référence opérationnelle des agents
- [x] Reporter les premières réponses de l'équipe dans le plan et le spec (19 oct.)
- [ ] Reporter les réponses restantes quand elles arrivent
- [ ] Tenir le journal ci-dessous à chaque session

---

## Démarrage rapide

Aucune installation n'est nécessaire pour lire les maquettes. Le jeu, lui, n'existe pas encore.

```bash
# Vérifier les fichiers de données d'exemple (colonnes, identifiants, dés)
python3 examples/tools/balance_sim.py --check

# Simuler 5 000 combats et voir la dangerosité des monstres
python3 examples/tools/balance_sim.py --fights 5000

# Ouvrir les maquettes (macOS)
open examples/interface/mockups.html
```

Sous Windows, remplacer `open` par `start` et `python3` par `python`. Les maquettes s'ouvrent aussi par double-clic.

Une fois le projet Godot créé (tâche 1), les commandes du jeu sont dans [SPEC.md](SPEC.md#commands-provisional-godot) (Git Bash) :

```bash
# Tous les tests (runner maison)
"$GODOT" --headless --path game --script res://tests/run_all.gd

# Exporter le build web, puis le jouer sur http://localhost:8000
"$GODOT" --headless --path game --export-release "Web" ../builds/web/index.html
python -m http.server 8000 --directory builds/web
```

**Ce qui est vérifié au 19 octobre 2026 :** la commande `--check` passe (`OK: data files look good`). Godot 4.7.2 est installé sur la machine du lead, pas sur celle d'Alban : le GDScript n'y a pas été réexécuté. Node.js est disponible chez Alban, mais le Worker n'a pas été testé.

---

## Structure du dépôt

```text
.
├─ README.md              ← ce fichier : vision + avancement
├─ AGENTS.md              ← référence compacte pour les agents
├─ CLAUDE.md              ← notes pour les agents Claude (état, décisions, consignes)
├─ SPEC.md                ← le spec : carte des modules, règles, critères de M1
├─ SPEC-*.md              ← un spec par module (core, content, narration, dm, world, main-screen, release)
├─ tasks/
│  ├─ plan.md             ← plan M1 : décisions, risques, liste de coupes
│  └─ todo.md             ← les 26 tâches de M1
├─ docs/
│  ├─ PLAN.md             ← plan, jalons, choix, réponses de l'équipe
│  └─ QUESTIONS-EQUIPE.md ← 23 questions à l'équipe (français)
└─ examples/
   ├─ README.md           ← guide des exemples statiques
   ├─ interface/          ← maquettes HTML
   ├─ godot/              ← exemples GDScript (dés, IA, monde, narration)
   ├─ content/            ← modèles d'art, d'écriture et CSV
   ├─ proxy/              ← Worker Cloudflare d'exemple
   ├─ tools/              ← outil Python d'équilibrage
   └─ ai-tests/           ← scénarios pièges et résultats
```

Dossiers prévus par le spec mais **absents** aujourd'hui : `game/` (projet Godot, tâche 1), `proxy/` (déploiement, M2), `tools/` (outils de production, M4). L'ancien prototype web reste hors du dépôt (voir [CLAUDE.md](CLAUDE.md)).

---

## Règles d'équipe

1. **Jamais le projet Git dans OneDrive.** La synchronisation peut corrompre le dépôt. Le code vit sur GitHub ; l'art et l'écriture passent par OneDrive.
2. **L'IA ne contrôle jamais le jeu directement.** Elle ne peut envoyer que des commandes d'une liste courte, validées par le code. Sa sortie est non fiable.
3. **Ne pas casser les sauvegardes.** Toute modification de la forme de l'état exige une migration et un test de chargement d'ancienne sauvegarde.
4. **Garder le mode copier-coller.** C'est le mode gratuit et le filet de sécurité si le proxy ou l'API tombent.
5. **Art et écriture dans des fichiers simples.** PNG, Aseprite, Markdown, CSV : jamais de contenu codé en dur dans un script.
6. **Aucune clé API dans le client ni dans le dépôt.** Le dépôt est **public**. La clé reste dans le Worker Cloudflare ou dans le fichier de réglages du joueur.
7. **Le spec d'abord.** Un changement de contrat (forme de l'état, format de réponse de l'IA, formats des fichiers de l'équipe) se fait d'abord dans `SPEC*.md`, avec l'accord du lead.

---

## Journal

- **17 octobre 2026** — Plan du projet, questionnaire d'équipe, exemples statiques, guides artiste/scénariste.
- **18 octobre 2026** — Test d'hallucination sur Haiku : 8 scénarios, 6/8 propres, 1 fait inventé, 1 dérive récit/état.
- **19 octobre 2026** — Ajout du README avec TODO et de `AGENTS.md`. Vérification Python des données : OK. Aucun code de jeu ajouté.
- **19 octobre 2026** — Spec (`SPEC.md` + 7 specs de modules) et plan M1 (26 tâches) approuvés. Premières réponses de l'équipe consignées dans `docs/PLAN.md` ; Alban rejoint l'équipe comme second programmeur. Décisions du lead :
  - pas d'envoi sur itch.io pendant M1 ;
  - runner de tests maison ;
  - la scène de test web est gardée comme scène de diagnostic ;
  - les corrections du MJ vont dans la tâche 8 ;
  - pas de dossier `reference/`.

  `CLAUDE.md`, `docs/PLAN.md`, ce README et `AGENTS.md` sont alignés sur le spec.

---

## Liens

| Document | À quoi il sert |
|---|---|
| [SPEC.md](SPEC.md) | Carte des modules, règles communes, limites, critères de M1 |
| [tasks/plan.md](tasks/plan.md) | Plan M1 : décisions, dépendances, risques, liste de coupes |
| [tasks/todo.md](tasks/todo.md) | Les 26 tâches de M1, avec critères d'acceptation |
| [docs/PLAN.md](docs/PLAN.md) | Vision, décisions, jalons, rôles, réponses de l'équipe |
| [docs/QUESTIONS-EQUIPE.md](docs/QUESTIONS-EQUIPE.md) | Les 23 questions à trancher en équipe |
| [examples/README.md](examples/README.md) | Carte des exemples et options comparées |
| [examples/interface/mockups.html](examples/interface/mockups.html) | Maquettes visuelles (à ouvrir dans un navigateur) |
| [examples/godot/scene_tree.md](examples/godot/scene_tree.md) | Structure de scène et flux d'un tour |
| [examples/ai-tests/RESULTS.md](examples/ai-tests/RESULTS.md) | Résultats du test d'hallucination |
| [examples/content/writing/dm-rules.md](examples/content/writing/dm-rules.md) | Règles envoyées au MJ IA (version d'exemple) |
| [examples/content/art/GUIDE-ARTISTE.md](examples/content/art/GUIDE-ARTISTE.md) | Formats et noms de fichiers pour l'artiste |
| [AGENTS.md](AGENTS.md) | Règles et conventions pour les agents codeurs |
| [CLAUDE.md](CLAUDE.md) | Notes pour les agents Claude : état, décisions, consignes |
