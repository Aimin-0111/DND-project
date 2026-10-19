# AGENTS.md — Référence agent · Brasswake Reach

> **Version : 2026-10-19.** Référence opérationnelle pour tout agent qui modifie ce dépôt.
> Priorité : demande humaine → ce fichier → `docs/PLAN.md` → `CLAUDE.md` (contexte historique).
> Lire aussi le [README](README.md) (avancement) et [examples/README.md](examples/README.md) (carte des exemples).

## 0. TL;DR

- **Dépôt de conception, pas encore un jeu.** Il n'y a ni `game/`, ni scène Godot, ni build jouable.
- **Cible proposée :** Godot 4 (GDScript) + itch.io + proxy Cloudflare Workers. Godot sera confirmé ou rejeté par le prototype M1 ; repli : TypeScript + Phaser 4.
- **`examples/` est statique.** Les scripts GDScript ont été parse-checkés, mais pas exécutés dans une vraie scène.
- **Toute sortie IA est non fiable.** Elle passe par `DmReplyParser` ; ne jamais contourner cette validation.
- **Vérifier avant d'affirmer.** Ne jamais prétendre avoir lancé un test sans avoir exécuté la commande et lu sa sortie.

## 1. Ordre de lecture

| Ordre | Fichier | Pourquoi |
|---|---|---|
| 1 | `README.md` | État réel, TODO, prochaines actions, journal |
| 2 | ce fichier | Règles, contrats, conventions |
| 3 | `docs/PLAN.md` | Vision, jalons, choix, rôles |
| 4 | `examples/README.md` | Ce que contient chaque exemple et quelles options sont comparées |
| 5 | `examples/content/...` | Seulement si la tâche touche l'art, l'écriture ou les données |
| 6 | `CLAUDE.md` | Contexte historique et ancienne architecture web (supplantée) |

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
| **R9** | `MUST` déclarer les limites : « non testé », « Godot absent », « seulement parse-checké ». `NEVER` inventer un résultat. |
| **R10** | `MUST` demander avant un changement d'architecture, de moteur ou de dépendance. M0 (projet Godot, dossiers, itch.io) est planifié, pas encore fait. |
| **R11** | `MUST` sauvegarder en JSON avec un champ `version`. `NEVER` charger un `.tres` importé : un fichier ressource peut contenir du code. |
| **R12** | `MUST` ordonner le prompt du plus stable au plus variable (règles → codex → résumé → état → action) pour le cache. Changer `dm-rules.md` invalide le cache et exige un retest. |
| **R13** | `MUST` valider les CSV avec `balance_sim.py --check` après toute modification de données. |
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
| `examples/ai-tests/` | Scénarios pièges, réponses Haiku, résultats | Test fait, corrections à appliquer |
| `game/` | Projet Godot prévu | **Absent** |
| `proxy/` | Déploiement du Worker prévu | **Absent** |
| `tools/` | Outils Python de production prévus | **Absent** |
| `reference/` | Ancien prototype web prévu | **Absent** |

## 4. État vérifié au 2026-10-19

À revérifier avec `command -v` si l'environnement a changé.

| Fait | Preuve / conséquence |
|---|---|
| Aucun code de jeu, aucune scène Godot | `game/` absent ; `examples/` est statique |
| Le remote GitHub existe (`origin`) | `git remote -v` |
| `balance_sim.py --check` passe | `OK: data files look good` |
| Python 3.14.7 disponible | `python3 --version` |
| Node.js 26.8.1 disponible, pnpm absent | Le Worker n'est pas testé pour autant |
| Godot absent de cet environnement | Ne pas prétendre avoir exécuté du GDScript ici |
| Aucune suite de tests, aucun CI | Ne pas inventer `npm test`, `make test` ou équivalent |
| Questionnaire sans réponses | Plusieurs choix produit restent bloqués |

## 5. Commandes

| But | Commande | Attendu |
|---|---|---|
| Vérifier les données | `python3 examples/tools/balance_sim.py --check` | `OK: data files look good`, sinon liste des problèmes |
| Simuler des combats | `python3 examples/tools/balance_sim.py --fights 5000` | Tableau de dangerosité par monstre |
| Ouvrir les maquettes (macOS) | `open examples/interface/mockups.html` | Navigateur ; Windows : `start ...` |
| Voir l'état Git | `git status --short` | Aucun fichier inattendu |
| Voir l'historique | `git log --oneline` | Commits du projet |

Si Godot est installé et qu'un projet existe :

```bash
godot --headless --path game --quit
```

Pour rejouer le test IA, la commande exacte est dans [examples/ai-tests/RESULTS.md](examples/ai-tests/RESULTS.md). Ne l'utiliser que si le projet et Godot existent.

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

Colonnes minimales vérifiées par `balance_sim.py` :

| Fichier | Colonnes |
|---|---|
| `monsters.csv` | `id`, `name`, `level`, `hp`, `ac`, `attack_bonus`, `damage`, `xp` |
| `items.csv` | `id`, `name`, `type`, `price` |
| `keywords.csv` | `effect`, `lang`, `words` |

- Identifiants : `[a-z0-9_]+`, minuscules, sans espaces ni accents.
- Noms de fichiers d'art : préfixes `tiles-`, `hero-`, `creature-`, `npc-`, `item-`, `fx-` (voir [GUIDE-ARTISTE.md](examples/content/art/GUIDE-ARTISTE.md)).
- Modèles d'écriture : [pnj-modele.md](examples/content/writing/pnj-modele.md), [lieu-modele.md](examples/content/writing/lieu-modele.md).
- Le code lit ces fichiers ; il ne les remplace pas par des constantes.

### 6.4 Prompt et modes IA

Ordre stable → variable : `rules`, `codex`, `summary`, `state`, `action`.

- Le mode copier-coller est le défaut gratuit ; il doit rester intact.
- Le proxy ne reçoit que des données de jeu, jamais les règles ni un choix de modèle : le Worker décide.
- La clé personnelle est stockée localement (`user://settings.cfg`), jamais livrée avec le jeu.
- Préférer un résumé d'histoire glissant au transcript complet ; rafraîchir le résumé sur un petit modèle.
- Toute modification de `dm-rules.md` doit être suivie d'un test des scénarios pièges.

### 6.5 Scène et interface

- Structure de référence : [scene_tree.md](examples/godot/scene_tree.md).
- Deux blocs : `World` (60 %) et `StoryPanel` (40 %) ; layout A côte à côte, B empilé, C plein écran.
- Autoloads prévus : `Game`, `Content`, `DM`.
- Le monde et le panneau doivent rester séparés ; l'UI ne contient pas de règles.

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
| Moteur | Godot 4 | Prototype M1 |
| Plateforme | itch.io (desktop, web possible) | Réponses question 1 |
| Langue | À définir | Question 2 |
| Combat | Tour par tour (proposé) | Question 6 |
| Déplacements | Clic pour avancer (proposé pour démarrer) | Question 4 |
| Rôle du MJ | Raconte, le jeu garde les règles | Question 7 |
| Modèle IA | Sonnet 5.5 + résumé Haiku 5.5 | Test de jeu réel |
| Style/tuiles | Pixel art, 16 ou 32 px | Questions 9–12 |

Réponses à consigner dans [docs/QUESTIONS-EQUIPE.md](docs/QUESTIONS-EQUIPE.md), puis à répercuter dans [docs/PLAN.md](docs/PLAN.md) et le README.

## 12. Fichiers à manipuler avec précaution

| Fichier | Risque |
|---|---|
| `examples/content/writing/dm-rules.md` | Partie cachée du prompt : change le comportement et le coût |
| `examples/godot/ai/dm_reply_parser.gd` | Dernière barrière avant l'état du jeu |
| `examples/godot/core/game_state.gd` | Toute forme d'état doit être migrée |
| `examples/godot/core/save_system.gd` | Une erreur casse les parties existantes |
| `examples/proxy/worker.ts` | Secret, abus, coût |
| `README.md` | Source de vérité de l'avancement |
| `.gitignore` | Une omission peut commiter un secret |

## 13. Maintenance de ce fichier

- Mettre à jour la **version en tête** à chaque changement structurel.
- Garder ce fichier court : les détails vont dans `docs/` ou `examples/`.
- Supprimer une règle devenue fausse plutôt que l'empiler.
- Si `CLAUDE.md` et ce fichier divergent, **ce fichier fait foi** pour les agents ; le signaler pour mettre `CLAUDE.md` à jour.
