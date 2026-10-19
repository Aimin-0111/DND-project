# Brasswake Reach

**Un RPG solo en pixel art, avec un Maître du Jeu IA.** Le récit occupe environ **40 %** de l'écran (texte avec des mots animés), le monde explorable **60 %**. Le jeu possède les règles, les dés et l'état ; l'IA narre et propose des actions limitées.

> **État au 19 octobre 2026 : aucune version jouable.**
> Le cadrage, le questionnaire d'équipe, les maquettes et des exemples de code existent. Le projet Godot reste à créer.

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

**Direction proposée :** Godot 4 (GDScript), hébergement itch.io, proxy Cloudflare Workers pour la clé API, dépôt privé GitHub pour le code, OneDrive de l'école pour l'art et l'écriture. Ces choix restent à confirmer, notamment Godot après le prototype M1.

---

## Ce qui existe / ce qui manque

| ✅ Existe | ⬜ Manque |
|---|---|
| [Plan du projet](docs/PLAN.md) et [questionnaire d'équipe](docs/QUESTIONS-EQUIPE.md) (23 questions) | Les réponses du questionnaire |
| [Maquettes HTML](examples/interface/mockups.html) : 3 mises en page, effets, panneaux, un tour de jeu | Un projet Godot, une scène, un personnage jouable |
| Des exemples GDScript : dés, état, sauvegardes, parseur IA, prompts, déplacements, effets de texte | L'intégration de ces exemples dans un vrai projet |
| Un [Worker Cloudflare](examples/proxy/worker.ts) d'exemple pour cacher la clé API | Un Worker déployé et testé |
| Un [outil Python](examples/tools/balance_sim.py) de vérification des CSV et de simulation de combats | Son branchement au flux de travail |
| Un [test d'hallucination](examples/ai-tests/RESULTS.md) : 8 scénarios pièges, 6/8 propres | Les corrections proposées, non appliquées |
| Des guides et modèles pour [l'artiste](examples/content/art/GUIDE-ARTISTE.md) et [le scénariste](examples/content/writing/pnj-modele.md) | Du contenu réel (zone, PNJ, quêtes, lore) |

> Les fichiers de `examples/` sont des **exemples statiques**, pas le jeu. Les scripts GDScript ont été parse-checkés sur la machine du lead (Godot 4.7.2) selon [examples/README.md](examples/README.md), mais aucun n'a été exécuté dans une vraie scène.

---

## Progression par jalon

Légende : ✅ fait · 🟡 partiel · ⬜ pas commencé.

| Jalon | État | Ce qui est acquis | Ce qui bloque la suite |
|---|---|---|---|
| **Cadrage** | 🟡 | Vision 40/60, plan, questionnaire, étude de coût IA | Réponses de l'équipe, choix définitifs |
| **M0 — Mise en place** | 🟡 | Dépôt Git/GitHub, docs, exemples, guides | Projet Godot, dossiers OneDrive, page itch.io |
| **M1 — Prototype (décision)** | ⬜ | Rien de jouable | Toute la chaîne : zone, héros, texte, IA, build |
| **M2 — Systèmes cœur** | ⬜ | Des exemples de code non intégrés | Intégration, tests, sauvegardes, proxy |
| **M3 — Monde** | ⬜ | Rien | Zones, PNJ, combat, temps, météo |
| **M4 — Contenu** | ⬜ | Modèles et CSV d'exemple | Art et écriture réels, équilibrage |
| **M5 — Sortie** | ⬜ | Rien | Son, réglages, tutoriel, page publique |

**Avancement des cases : 14 / 66 (21 %)** — comptage simple des cases du TODO, pas une estimation du temps de travail.

---

## Prochaines actions

1. **Obtenir les réponses au [questionnaire](docs/QUESTIONS-EQUIPE.md)** — il débloque la langue, la plateforme, le style, les combats et le rôle du MJ IA. Sans elles, l'artiste et le scénariste ne peuvent pas vraiment démarrer.
2. **Créer le squelette M0** — projet Godot `game/`, dossiers OneDrive `art/`, `writing/`, `data/`, page itch.io privée. C'est le prochain vrai jalon.
3. **Appliquer les deux corrections du test IA** — ajouter les règles anti-hallucination et anti-dérive dans [dm-rules.md](examples/content/writing/dm-rules.md), puis relancer S1 et S8 plusieurs fois.

---

## TODO détaillé

> **Source de vérité de l'avancement.** Une case ne se coche qu'avec une preuve : fichier, commande exécutée, lien ou commit. Mettre à jour la date et le [journal](#journal) en même temps.

### 1. Cadrage et décisions

- [x] Fixer la vision : 40 % récit / 60 % scène animée ([docs/PLAN.md](docs/PLAN.md))
- [x] Proposer les choix principaux : moteur, hébergement, proxy, stockage ([docs/PLAN.md](docs/PLAN.md))
- [x] Rédiger le questionnaire d'équipe (23 questions) ([docs/QUESTIONS-EQUIPE.md](docs/QUESTIONS-EQUIPE.md))
- [x] Terminer l'étude de coût IA ([CLAUDE.md](CLAUDE.md))
- [ ] Récupérer les réponses au questionnaire
- [ ] Trancher : plateforme, langue, ambiance, déplacements, taille du monde, combat, rôle du MJ, effets animés
- [ ] Confirmer Godot 4 (ou basculer sur TypeScript + Phaser 4) après le prototype M1
- [ ] Choisir le modèle IA après un test de jeu réel

### 2. M0 — Mise en place

- [x] Créer le dépôt Git et le remote GitHub (`origin`)
- [x] Ajouter un `.gitignore` (cache Godot, builds, secrets, Node)
- [x] Écrire le plan, le questionnaire et les exemples statiques
- [x] Écrire les guides de l'artiste et du scénariste
- [ ] Créer le projet Godot `game/` (il n'existe pas encore)
- [ ] Partager les dossiers OneDrive `art/`, `writing/`, `data/`
- [ ] Créer une page itch.io privée pour les builds de test
- [ ] Installer GitHub Desktop et l'extension VS Code `godot-tools` (`butler` viendra plus tard)
- [ ] Créer le squelette de dossiers prévu par le plan (`game/`, `proxy/`, `tools/`, `reference/`)
- [ ] Récupérer l'ancien prototype web dans `reference/` (s'il est encore disponible)

### 3. M1 — Prototype de décision

- [ ] Construire une petite zone : forêt, chemin, rivière, pont, vieux moulin
- [ ] Faire marcher le héros (cliquer pour aller, caméra qui suit)
- [ ] Réaliser la répartition 40/60, avec bascule empilée sur écran étroit
- [ ] Ajouter l'effet machine à écrire et **3 mots animés**
- [ ] Brancher un tour IA complet en mode copier-coller
- [ ] Appliquer au moins une commande IA vérifiée (`move_to`, `spawn` ou `weather`)
- [ ] Sauvegarder et recharger une partie simple
- [ ] Exporter le prototype sur la page itch.io privée
- [ ] Mesurer les performances (fluidité, temps d'attente IA)
- [ ] Décider : **on garde Godot** ou **on passe à Phaser**

### 4. M2 — Systèmes cœur

- [ ] Intégrer les dés seedés et leurs tests
- [ ] Intégrer l'état du jeu et les migrations de sauvegarde
- [ ] Ajouter le journal d'actions et le bouton Rewind
- [ ] Garder les 3 modes IA derrière une seule interface (copier-coller, proxy, clé personnelle)
- [ ] Déployer le Worker Cloudflare, y placer la clé en secret et limiter le débit
- [ ] Tester le parseur contre les cas adverses : JSON cassé, identifiants inconnus, injection, valeurs hors limites
- [ ] Intégrer le constructeur de prompt et le résumé d'histoire glissant
- [ ] Construire les panneaux Fiche, Sac, Quêtes et Codex
- [ ] Importer et exporter les sauvegardes

### 5. M3 — Monde

- [ ] Relier plusieurs zones par des voyages
- [ ] Faire vivre les PNJ et les créatures
- [ ] Finaliser la liste blanche des commandes IA et le réalisateur de scène
- [ ] Implémenter le combat au tour par tour
- [ ] Ajouter le cycle jour/nuit et la météo

### 6. M4 — Contenu

- [ ] Valider la chaîne d'art : PNG/Aseprite → import Godot → animation
- [ ] Produire une tranche verticale : une zone, des PNJ, une chaîne de quêtes, du lore
- [ ] Brancher `balance_sim.py --check` avant chaque ajout de contenu
- [ ] Installer un rythme de livraison pour l'artiste et le scénariste

### 7. M5 — Sortie

- [ ] Ajouter musiques et effets sonores
- [ ] Ajouter les réglages et l'accessibilité (dont « réduire les animations »)
- [ ] Écrire le tutoriel
- [ ] Traduire si le jeu doit être bilingue
- [ ] Publier la page itch.io publique et le build desktop
- [ ] Organiser une boucle de playtests avec retours

### 8. Qualité de l'IA et tests

- [x] Écrire 8 scénarios pièges ([scenarios.md](examples/ai-tests/scenarios.md))
- [x] Tester Haiku et documenter les résultats ([RESULTS.md](examples/ai-tests/RESULTS.md))
- [ ] Ajouter les deux règles proposées : ne pas inventer un lieu/personnage absent, et envoyer `move_to` quand le récit déplace le héros
- [ ] Relancer S1 et S8 **5 à 10 fois** pour vérifier que les corrections tiennent
- [ ] Comparer Haiku et Sonnet 5.5 sur les mêmes scénarios
- [ ] Tester le vrai appel API (proxy et clé personnelle), pas seulement les agents de Claude Code
- [ ] Mesurer le coût réel par tour et le gain du cache de prompt
- [ ] Automatiser les tests du parseur (le test actuel reste manuel)

### 9. Documentation et pilotage

- [x] Écrire `CLAUDE.md` (contexte historique)
- [x] Écrire [examples/README.md](examples/README.md)
- [x] Écrire ce README avec le TODO
- [x] Écrire [AGENTS.md](AGENTS.md), la référence opérationnelle des agents
- [ ] Mettre à jour le plan quand les réponses de l'équipe arrivent
- [ ] Tenir le journal ci-dessous à chaque session

---

## Démarrage rapide

Aucune installation n'est nécessaire pour lire les maquettes. Le jeu, lui, n'existe pas encore.

```bash
# Vérifier les fichiers de données (colonnes, identifiants, dés)
python3 examples/tools/balance_sim.py --check

# Simuler 5 000 combats et voir la dangerosité des monstres
python3 examples/tools/balance_sim.py --fights 5000

# Ouvrir les maquettes (macOS)
open examples/interface/mockups.html
```

Sous Windows, remplacer `open` par `start`. Les maquettes s'ouvrent aussi par double-clic.

**Ce qui est vérifié au 19 octobre 2026 :** la commande `--check` passe (`OK: data files look good`). Godot n'est pas installé sur la machine courante, donc le GDScript n'a pas été réexécuté ici. Node.js est disponible, mais le Worker n'a pas été testé.

---

## Structure du dépôt

```text
.
├─ README.md              ← ce fichier : vision + avancement
├─ AGENTS.md              ← référence compacte pour les agents
├─ CLAUDE.md              ← brief historique (contexte, ancienne archi web)
├─ docs/
│  ├─ PLAN.md             ← plan, jalons, choix proposés
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

Dossiers prévus par le plan mais **absents** aujourd'hui : `game/` (projet Godot), `proxy/` (déploiement), `tools/` (outils de production), `reference/` (ancien prototype).

---

## Règles d'équipe

1. **Jamais le projet Git dans OneDrive.** La synchronisation peut corrompre le dépôt. Le code vit sur GitHub ; l'art et l'écriture passent par OneDrive.
2. **L'IA ne contrôle jamais le jeu directement.** Elle ne peut envoyer que des commandes d'une liste courte, validées par le code. Sa sortie est non fiable.
3. **Ne pas casser les sauvegardes.** Toute modification de la forme de l'état exige une migration et un test de chargement d'ancienne sauvegarde.
4. **Garder le mode copier-coller.** C'est le mode gratuit et le filet de sécurité si le proxy ou l'API tombent.
5. **Art et écriture dans des fichiers simples.** PNG, Aseprite, Markdown, CSV : jamais de contenu codé en dur dans un script.
6. **Aucune clé API dans le client.** Elle reste dans le Worker Cloudflare ou dans le stockage local du joueur.

---

## Journal

- **17 octobre 2026** — Plan du projet, questionnaire d'équipe, exemples statiques, guides artiste/scénariste.
- **18 octobre 2026** — Test d'hallucination sur Haiku : 8 scénarios, 6/8 propres, 1 fait inventé, 1 dérive récit/état.
- **19 octobre 2026** — Ajout du README avec TODO et de `AGENTS.md`. Vérification Python des données : OK. Aucun code de jeu ajouté.

---

## Liens

| Document | À quoi il sert |
|---|---|
| [docs/PLAN.md](docs/PLAN.md) | Vision, décisions, jalons, rôles, dossiers |
| [docs/QUESTIONS-EQUIPE.md](docs/QUESTIONS-EQUIPE.md) | Les 23 questions à trancher en équipe |
| [examples/README.md](examples/README.md) | Carte des exemples et options comparées |
| [examples/interface/mockups.html](examples/interface/mockups.html) | Maquettes visuelles (à ouvrir dans un navigateur) |
| [examples/godot/scene_tree.md](examples/godot/scene_tree.md) | Structure de scène et flux d'un tour |
| [examples/ai-tests/RESULTS.md](examples/ai-tests/RESULTS.md) | Résultats du test d'hallucination |
| [examples/content/writing/dm-rules.md](examples/content/writing/dm-rules.md) | Règles envoyées au MJ IA |
| [examples/content/art/GUIDE-ARTISTE.md](examples/content/art/GUIDE-ARTISTE.md) | Formats et noms de fichiers pour l'artiste |
| [AGENTS.md](AGENTS.md) | Règles et conventions pour les agents codeurs |
| [CLAUDE.md](CLAUDE.md) | Contexte historique et ancienne architecture web |
