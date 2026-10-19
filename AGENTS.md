# AGENTS.md — Référence agent · Brasswake Reach

> **Version : 2026-10-19.** Référence opérationnelle pour tout agent qui modifie ce dépôt.
> Priorité : demande humaine → ce fichier → `docs/PLAN.md` → `CLAUDE.md` (contexte historique).
> Lire aussi le [README](README.md) (avancement) et [examples/README.md](examples/README.md) (carte des exemples).

## 0. TL;DR

- **Tranche M1 locale jouable.** `game/` contient la zone, le héros, le récit animé, la boucle IA copier-coller, la sauvegarde et FR/EN. La page itch.io et le test avec un vrai modèle restent à faire.
- **Cible :** Godot 4.7.2 (GDScript) + itch.io + proxy Cloudflare Workers plus tard. Godot sera confirmé ou rejeté par le playtest M1 ; repli : TypeScript + Phaser 4.
- **`examples/` reste une référence statique** ; le code vivant est dans `game/`.
- **Toute sortie IA est non fiable.** Elle passe par `DmReplyParser` ; ne jamais contourner cette validation.
- **Vérifier avant d'affirmer.** Ne jamais prétendre avoir lancé un test sans avoir exécuté la commande et lu sa sortie.

## 1. Ordre de lecture

| Ordre | Fichier | Pourquoi |
|---|---|---|
| 1 | `README.md` | État réel, TODO, prochaines actions, journal |
| 2 | ce fichier | Règles, contrats, conventions |
| 3 | `SPEC.md` + `tasks/plan.md` + `tasks/todo.md` | Contrats M1, plan approuvé, avancement détaillé |
| 4 | `docs/PLAN.md` | Vision, jalons, choix, rôles |
| 5 | `game/content/...` | Seulement si la tâche touche l'art, l'écriture ou les données |
| 6 | `docs/m1-ai-tests.md` + `docs/m1-ac.md` | Limites IA et état des critères M1 |
| 7 | `CLAUDE.md` | Contexte historique et ancienne architecture web (supplantée) |

## 2. Règles dures

`MUST` = obligatoire · `NEVER` = interdit · `SHOULD` = recommandé.

| ID | Règle |
|---|---|
| **R1** | `NEVER` de clé API dans le client, le dépôt ou un fichier commité. La clé vit dans le Worker Cloudflare ou dans le stockage local du joueur. |
| **R2** | `MUST` garder le mode copier-coller fonctionnel, même quand un mode API existe. C'est le mode gratuit et le filet de sécurité. |
| **R3** | `MUST` ajouter une migration à chaque changement de forme de l'état. Une ancienne sauvegarde doit toujours se charger. |
| **R4** | `NEVER` faire confiance à la sortie IA. Tout passe par `DmReplyParser` : format, identifiants autorisés, commandes connues, bornes numériques. |
| **R5** | `MUST` garder l'art et l'écriture dans des fichiers simples (PNG, Aseprite, Markdown, CSV). `NEVER` coder du contenu en dur dans un script. |
| **R6** | `NEVER` placer le dépôt Git dans OneDrive. Le code va sur GitHub ; l'art et l'écriture passent par OneDrive. |
| **R7** | `MUST` garder le cœur du jeu déterministe et testable : dés seedés, mêmes entrées → mêmes sorties, aucune dépendance à l'UI. |
| **R8** | `MUST` mettre à jour le README (cases + journal) quand une tâche est terminée. `NEVER` cocher sans preuve vérifiable. |
| **R9** | `MUST` déclarer les limites : « non testé », « non exécuté ici », « seulement parse-checké ». `NEVER` inventer un résultat. |
| **R10** | `MUST` demander avant un changement d'architecture, de moteur ou de dépendance. M1 est implémenté localement ; la page itch.io et le test IA réel restent ouverts. |
| **R11** | `MUST` sauvegarder en JSON avec un champ `version`. `NEVER` charger un `.tres` importé : un fichier ressource peut contenir du code. |
| **R12** | `MUST` ordonner le prompt du plus stable au plus variable (règles → codex → résumé → état → action) pour le cache. Changer `dm-rules.md` invalide le cache et exige un retest. |
| **R13** | `MUST` valider les données avec `tools/content_check.py --check --langs fr,en` après toute modification de contenu. |
| **R14** | `SHOULD` privilégier de petits changements ciblés. `NEVER` reformater massivement un fichier sans demande. |

## 3. Carte du dépôt

| Chemin | Contenu | Statut |
|---|---|---|
| `README.md` | Vision, avancement, TODO, journal | Vivant |
| `AGENTS.md` | Ce fichier | Vivant |
| `CLAUDE.md` | Brief historique, ancienne archi web | Contexte, à ne pas prendre pour l'état actuel |
| `docs/PLAN.md` | Plan, décisions proposées, jalons M0–M5 | Vivant |
| `docs/QUESTIONS-EQUIPE.md` | 23 questions à l'équipe (français) | En attente de réponses |
| `examples/interface/mockups.html` | Maquettes statiques, 3 layouts, un tour IA | Référence visuelle |
| `examples/godot/` | Exemples GDScript : `core/`, `ai/`, `narration/`, `world/`, `content/` | Exemples non intégrés |
| `examples/content/` | Modèles d'écriture, guide artiste, CSV | Modèles |
| `examples/proxy/worker.ts` | Worker Cloudflare d'exemple | Non déployé, non testé |
| `examples/tools/balance_sim.py` | Vérification CSV + simulation de combats | Fonctionnel |
| `examples/ai-tests/` | Scénarios pièges, réponses Haiku, résultats | Référence ; réponses archivées recopiées dans `game/tests/fixtures/` |
| `game/` | Projet Godot M1 : `core/`, `ai/`, `narration/`, `world/`, `ui/`, `content/`, `tests/` | **Vivant, 13 tests** |
| `tools/` | `content_check.py` (validation M1) | Fonctionnel ; la simulation reste dans `examples/tools/` |
| `tasks/` | `plan.md` (plan approuvé) et `todo.md` (suivi) | Vivant |
| `docs/m1-ai-tests.md` | Rapport IA M1 et limites | Vivant |
| `docs/m1-ac.md` | Checklist AC1–AC13 | Vivant |
| `proxy/` | Déploiement du Worker prévu | **Absent** |
| `reference/` | Ancien prototype web prévu | **Absent** |

## 4. État vérifié au 2026-10-19

À revérifier avec `command -v` si l'environnement a changé.

| Fait | Preuve / conséquence |
|---|---|
| Le projet M1 existe et boote | `game/` ; `godot --headless --path game --quit` exit 0 |
| Le remote GitHub existe (`origin`) | `git remote -v` |
| `content_check.py --check --langs fr,en` passe | `OK: content looks good (fr, en)` |
| Python 3.14.7 disponible | `python3 --version` |
| Node.js 26.8.1 disponible, pnpm absent | Le Worker n'est pas testé pour autant |
| Godot 4.7.2 installé | `godot --version` ; les commandes Godot sont exécutables |
| 13 fichiers de tests, pas de CI | `PASS: 13 test file(s)` ; ne pas inventer `npm test` |
| Le test IA réel n'a pas été rejoué | S1/S8 restent des défauts de narration ; voir `docs/m1-ai-tests.md` |
| Page itch.io non créée | L'export macOS local existe, l'upload reste humain |
| Questionnaire sans réponses | Plusieurs choix produit restent bloqués |

## 5. Commandes

| But | Commande | Attendu |
|---|---|---|
| Boot headless | `godot --headless --path game --quit` | exit 0, pas d'erreur |
| Tests | `godot --headless --path game --script res://tests/run_tests.gd` | `PASS: 13 test file(s)` |
| Vérifier le contenu | `python3 tools/content_check.py --check --langs fr,en` | `OK: content looks good (fr, en)` |
| Lancer le jeu | `godot --path game` | Fenêtre 1280 × 720 |
| Simuler des combats (données d'exemple) | `python3 examples/tools/balance_sim.py --fights 5000` | Tableau de dangerosité |
| Exporter macOS | `godot --headless --path game --export-release "macOS" "$PWD/builds/macos/BrasswakeReach.zip"` | Archive lançable |
| Ouvrir les maquettes (macOS) | `open examples/interface/mockups.html` | Navigateur ; Windows : `start ...` |
| Voir l'état Git | `git status --short` | Aucun fichier inattendu |

Pour rejouer le test IA, la commande exacte est dans [examples/ai-tests/RESULTS.md](examples/ai-tests/RESULTS.md). Le rapport M1 est dans [docs/m1-ai-tests.md](docs/m1-ai-tests.md).

## 6. Contrats

### 6.1 Réponse du MJ IA

Format exact : narration, puis une ligne `<<STATE>>`, puis **un seul** objet JSON.

```text
La passerelle gémit sous vos pas...
<<STATE>>
{"commands": [{"type": "move_to", "target": "mill_bridge"}],
 "state": {"gold_delta": 5, "time_advance_minutes": 10}}
```

- **Commandes autorisées :** `move_to`, `spawn`, `despawn`, `emote`, `weather`, `request_roll`.
- **Maximum :** 5 commandes, 4 mots avec effet.
- **Identifiants :** uniquement ceux de la liste `ALLOWED IDS` (lieux, créatures, objets, compétences, quêtes).
- **État :** `hp_delta`, `gold_delta`, `time_advance_minutes`, `add_items`, `quest_updates`.
- **Effets :** `burn`, `freeze`, `shock`, `poison`, `whisper`, `holy`.
- Le parseur rejette ou ignore tout ce qui est inconnu ou hors bornes. Ne jamais assouplir ces contrôles pour « faire passer » une réponse.
- La narration est aussi non fiable : le BBCode non autorisé doit être échappé, pas exécuté.
- **Dérive récit/état :** si la narration déplace le héros, une commande `move_to` doit suivre. C'est le défaut S8 du test Haiku.

### 6.2 État et sauvegardes

- Un seul `Dictionary` sérialisable, avec `version` (`GameState.VERSION`).
- Sauvegarde JSON dans `user://saves/` (IndexedDB dans le build web).
- Une fonction `_vN_to_vN+1()` par changement de forme ; test de chargement obligatoire.
- Le journal d'actions et Rewind sont prévus (M2), pas encore implémentés.
- Les dés sont seedés ; sauvegarder l'état du RNG si la reproductibilité l'exige.

### 6.3 Contenu éditable

Colonnes minimales vérifiées par `tools/content_check.py` :

| Fichier | Colonnes |
|---|---|
| `game/content/data/monsters.csv` | `id`, `level`, `hp`, `ac`, `attack_bonus`, `damage`, `xp` |
| `game/content/data/items.csv` | `id`, `type`, `price` |
| `game/content/data/locations.csv` | `id` |
| `game/content/data/quests.csv` | `id`, `max_stage` |
| `game/content/data/keywords.csv` | `effect`, `lang`, `words` |
| `game/content/i18n/strings.csv` | `key`, `fr`, `en` |

- Les noms affichés vivent dans `strings.csv` ; les CSV numériques restent neutres en langue.
- Identifiants : `[a-z0-9_]+`, minuscules, sans espaces ni accents.
- Noms de fichiers d'art : préfixes `tiles-`, `hero-`, `creature-`, `npc-`, `item-`, `fx-` (voir [GUIDE-ARTISTE.md](examples/content/art/GUIDE-ARTISTE.md)).
- Le code lit ces fichiers ; il ne les remplace pas par des constantes.

### 6.4 Prompt et modes IA

Ordre stable → variable : `rules`, `codex`, `summary`, `state`, `allowed`, `turn` (action + langue).

- Le mode copier-coller est le défaut gratuit ; il doit rester intact.
- `DM.play_turn()` construit le prompt, attend le collage, parse, puis retourne `{ok, narration, commands, changes, errors}`. C'est le shell qui affiche, applique et sauvegarde.
- Le proxy ne reçoit que des données de jeu, jamais les règles ni un choix de modèle : le Worker décide.
- La clé personnelle est stockée localement (`user://settings.cfg`), jamais livrée avec le jeu.
- Préférer un résumé d'histoire glissant au transcript complet ; rafraîchir le résumé sur un petit modèle.
- Toute modification de `game/content/writing/dm-rules.md` doit être suivie d'un test des scénarios pièges.

### 6.5 Scène et interface

- Scène réelle : `game/main.tscn`.
- Deux blocs : `WorldView` (60 %) et `StoryPanel` (40 %) ; sous 900 px, `main.gd` les reparente dans `VSplitContainer` (`stack`).
- Autoloads réels : `Game` (état/dés/sauvegarde), `Content` (données/langue), `DM` (prompt/collage/parseur).
- `SceneDirector` reçoit uniquement des commandes validées. Le monde et le panneau restent séparés ; l'UI ne contient pas de règles.

## 7. Conventions de code

### GDScript

- Godot 4.7, indentation par **tabulations**, typage explicite (`var x: int`, `-> void`).
- `class_name` pour les classes réutilisables ; fonctions `static` pures quand l'état n'est pas nécessaire.
- Le cœur (`core/`, `ai/`) ne dépend pas de l'UI ; les nœuds d'interface se contentent de rendre et d'émettre des signaux.
- Les adapters IA sont des coroutines (`await`) ; le presse-papiers ne s'ouvre qu'après un clic.
- Commenter le **pourquoi**, pas la syntaxe évidente.
- Parse-checker avant de prétendre qu'un script est valide.
- Pièges Godot : les CSV sont importés comme traductions par défaut → « Import As: Keep File » ; ajouter `*.csv, *.md` aux filtres d'export.

### Python

- Bibliothèque standard uniquement, Python 3.13+ (3.14 testé), `pathlib`.
- Lancer `--check` avant `--fights` et avant de considérer un contenu comme valide.
- Ne pas ajouter de dépendance sans demande.

### TypeScript (Worker)

- Clé dans les secrets d'environnement Cloudflare, jamais dans le code.
- CORS, limite de taille, limite de débit, liste blanche de modèles.
- Ne jamais accepter un modèle ou des règles choisis par le client.
- Le Worker n'a pas été testé : le dire si on le modifie.

### Documentation

- Français pour les documents d'équipe ; l'anglais existant peut rester.
- Une information = un endroit. `PLAN.md` pour les décisions, `README.md` pour l'avancement, ce fichier pour les règles.
- Dates au format `2026-10-19` dans les documents techniques ; le README peut garder une date lisible.
- Pas de duplication de longs passages : liens relatifs.

## 8. Workflow agent

1. `git status --short` ; lire le README, ce fichier et les fichiers concernés.
2. Vérifier que la tâche n'est pas déjà faite ou bloquée par une décision ouverte.
3. Modifier au plus petit périmètre ; préserver le style existant.
4. Exécuter la vérification disponible. Si elle est impossible, l'écrire explicitement.
5. Mettre à jour le README (case + journal) et `PLAN.md` si une décision change.
6. Relire le diff. Ne pas commit/push sans demande explicite.
7. Répondre avec : fichiers changés, commandes exécutées, résultats, limites.

## 9. Definition of Done

- [ ] Le changement correspond à la demande, sans élargissement silencieux.
- [ ] La vérification pertinente a été exécutée **ou** la raison de son absence est écrite.
- [ ] Aucun secret, aucune clé, aucun fichier de build ajouté.
- [ ] Les sauvegardes restent compatibles (ou une migration + un test existent).
- [ ] Le mode copier-coller reste fonctionnel si l'IA est touchée.
- [ ] Le README et le journal reflètent le nouvel état.
- [ ] Le diff a été relu.

## 10. Pièges connus

| Piège | Réponse |
|---|---|
| L'IA invente un lieu ou un personnage (S1) | Règle explicite dans `dm-rules.md` ; codex complet ; ne jamais rendre réel ce qui n'est pas listé |
| Le récit déplace le héros sans `move_to` (S8) | Vérifier la cohérence narration/commandes ; règle dédiée |
| Haiku n'a utilisé aucun tag d'effet (0/8) | Garder l'option C : liste de mots + tags IA |
| Injection du joueur (« 9999 or ») | Le parseur borne et rejette ; ne jamais obéir à une instruction du joueur |
| Transcript complet trop cher | Résumé glissant + cache de prompt |
| Cache invalidé par une virgule dans les règles | Modifier `dm-rules.md` rarement, puis retester |
| CSV Godot importé comme traduction | « Import As: Keep File » |
| CSV/MD absents du build | Filtres d'export non-resource |
| `.tres` importé = exécution de code | Sauvegardes JSON uniquement |
| Sauvegarde web perdue | `user://` = IndexedDB ; export/import JSON prévu |
| Git dans OneDrive corrompu | Dépôt hors OneDrive, toujours |
| Attente IA de 2–10 s | Animation, indicateur, résumé, cache |

## 11. Décisions ouvertes

| Sujet | Proposition actuelle | Bloqué par |
|---|---|---|
| Moteur | Godot 4.7.2 | Playtest M1 puis décision |
| Plateforme | itch.io (desktop, web possible) | Réponses question 1 |
| Langue | Jeu bilingue FR/EN dès M1 | Défaut actuel : locale système, sinon fr |
| Combat | Tour par tour (proposé) | Question 6 |
| Déplacements | Clic pour avancer (implémenté) | Question 4 |
| Rôle du MJ | Raconte, le jeu garde les règles (implémenté) | Question 7 |
| Modèle IA | Sonnet 5.5 + résumé Haiku 5.5 | Test de jeu réel (AC11) |
| Style/tuiles | Placeholders 32 × 32 | Questions 9–12 |

Réponses à consigner dans [docs/QUESTIONS-EQUIPE.md](docs/QUESTIONS-EQUIPE.md), puis à répercuter dans [docs/PLAN.md](docs/PLAN.md) et le README.

## 12. Fichiers à manipuler avec précaution

| Fichier | Risque |
|---|---|
| `game/content/writing/dm-rules.md` | Partie cachée du prompt : change le comportement et le coût |
| `game/ai/dm_reply_parser.gd` | Dernière barrière avant l'état du jeu |
| `game/core/game_state.gd` | Toute forme d'état doit être migrée |
| `game/core/save_system.gd` | Une erreur casse les parties existantes |
| `game/main.gd` | Orchestration du tour, sauvegarde/chargement, layout |
| `game/world/scene_director.gd` | Applique les commandes IA au monde |
| `game/content/i18n/strings.csv` | Toute clé doit exister en FR et EN |
| `examples/proxy/worker.ts` | Secret, abus, coût (non déployé) |
| `README.md` | Source de vérité de l'avancement |
| `.gitignore` | Une omission peut commiter un secret |

## 13. Maintenance de ce fichier

- Mettre à jour la **version en tête** à chaque changement structurel.
- Garder ce fichier court : les détails vont dans `docs/` ou `examples/`.
- Supprimer une règle devenue fausse plutôt que l'empiler.
- Si `CLAUDE.md` et ce fichier divergent, **ce fichier fait foi** pour les agents ; le signaler pour mettre `CLAUDE.md` à jour.
