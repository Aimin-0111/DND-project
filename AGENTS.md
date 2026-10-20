# AGENTS.md — Référence agent · Brasswake Reach

> **Version : 2026-10-19 (alignée sur le spec approuvé).** Référence opérationnelle pour tout agent qui modifie ce dépôt.
> Priorité : demande humaine → [`SPEC.md`](SPEC.md) et `SPEC-*.md` (contrats, limites) → [`tasks/`](tasks/plan.md) (plan et tâches M1) → ce fichier → `docs/PLAN.md` → `CLAUDE.md`.
> Lire aussi le [README](README.md) (avancement) et [examples/README.md](examples/README.md) (carte des exemples).

## 0. TL;DR

- **Le spec et le plan M1 sont approuvés, le jeu n'existe pas encore sur `main`.** Il n'y a ni `game/`, ni scène Godot, ni build jouable. Prochaine étape : la tâche 1 de [tasks/todo.md](tasks/todo.md).
- **Sur la branche `Beta-0.2`, `game/` existe** (tranche M1 d'Alban + corrections). Tests : `"$GODOT" --headless --path game --script res://tests/run_tests.gd` → `PASS: 14 test file(s)`. Ce qui diffère encore du spec : [docs/BETA-0.2.md](docs/BETA-0.2.md).
- **Cible proposée :** Godot 4 (GDScript) + proxy Cloudflare Workers (M2) ; itch.io après M1. Godot sera confirmé ou rejeté par le prototype M1 ; repli : TypeScript + Phaser 4.
- **Pendant M1, pas d'envoi sur itch.io :** les builds web se jouent en local (`localhost`).
- **Le dépôt est public.** Aucun secret, jamais.
- **`examples/` est statique.** Les scripts GDScript ont été parse-checkés, mais pas exécutés dans une vraie scène. Ils sont déplacés dans `game/src/` tâche par tâche.
- **Toute sortie IA est non fiable.** Elle passe par les vérifications du module `dm` ; ne jamais les contourner.
- **Vérifier avant d'affirmer.** Ne jamais prétendre avoir lancé un test sans avoir exécuté la commande et lu sa sortie.

## 1. Ordre de lecture

| Ordre | Fichier | Pourquoi |
|---|---|---|
| 1 | `README.md` | État réel, TODO, prochaines actions, journal |
| 2 | `SPEC.md` | Carte des modules, structure, style de code, limites (Toujours / Demander d'abord / Jamais), critères de M1 |
| 3 | `SPEC-<module>.md` | Le contrat du module touché par la tâche |
| 4 | `tasks/plan.md`, `tasks/todo.md` | Ordre des tâches, critères d'acceptation, vérifications |
| 5 | ce fichier | Règles, contrats en bref, conventions |
| 6 | `docs/PLAN.md` | Vision, jalons, choix, rôles, réponses de l'équipe |
| 7 | `examples/README.md` | Ce que contient chaque exemple et quelles options sont comparées |
| 8 | `examples/content/...` | Seulement si la tâche touche l'art, l'écriture ou les données |
| 9 | `CLAUDE.md` | Notes pour les agents Claude : état, décisions, ancienne version |

## 2. Règles dures

`MUST` = obligatoire · `NEVER` = interdit · `SHOULD` = recommandé.

| ID | Règle |
|---|---|
| **R1** | `NEVER` de clé API dans le client, le dépôt, un build ou un fichier commité : **le dépôt est public**. La clé vit dans le Worker Cloudflare, ou dans le fichier de réglages du joueur (jamais dans une sauvegarde ni un log). |
| **R2** | `MUST` garder le mode copier-coller fonctionnel, même quand un mode API existe. C'est le mode gratuit et le filet de sécurité. |
| **R3** | `MUST` ajouter une migration à chaque changement de forme de l'état. Une ancienne sauvegarde doit toujours se charger. |
| **R4** | `NEVER` faire confiance à la sortie IA. Tout passe par les vérifications du module `dm` (`DmReplyParser` dans `examples/`, `game/src/dm/reply_checker.gd` à partir de la tâche 10) : format, identifiants autorisés, commandes connues, bornes numériques. |
| **R5** | `MUST` garder l'art et l'écriture dans des fichiers simples (PNG, Aseprite, Markdown, CSV). `NEVER` coder du contenu en dur dans un script. |
| **R6** | `NEVER` placer le dépôt Git dans OneDrive. Le code va sur GitHub ; l'art et l'écriture passent par OneDrive. |
| **R7** | `MUST` garder le cœur du jeu déterministe et testable : dés seedés, mêmes entrées → mêmes sorties, aucune dépendance à l'UI. |
| **R8** | `MUST` cocher la tâche dans `tasks/todo.md` et mettre à jour le README (phase + journal) quand une tâche est terminée. `NEVER` cocher sans preuve vérifiable. |
| **R9** | `MUST` déclarer les limites : « non testé », « Godot absent », « seulement parse-checké ». `NEVER` inventer un résultat. |
| **R10** | `MUST` demander avant tout ce que `SPEC.md` range dans « Demander d'abord » : dépendance (y compris un outil de test), forme de l'état, format de réponse de l'IA, formats des fichiers de l'équipe, installation de logiciel, création de compte, commit ou push. |
| **R11** | `MUST` sauvegarder en JSON avec un champ `version`. `NEVER` charger un `.tres` importé : un fichier ressource peut contenir du code. |
| **R12** | `MUST` garder l'ordre du prompt du plus stable au plus variable (voir 6.4) pour le cache. Changer `dm-rules.md` invalide le cache et exige un retest. |
| **R13** | `MUST` lancer les tests et le content check avant chaque commit. Le content check fait partie du runner de tests à partir de la tâche 5. `balance_sim.py --check` ne vérifie que les CSV d'exemple (ancien format de colonnes). |
| **R14** | `SHOULD` privilégier de petits changements ciblés. `NEVER` reformater massivement un fichier sans demande. |
| **R15** | `MUST` modifier le spec **avant** le code quand un contrat change, avec l'accord du lead. |

## 3. Carte du dépôt

| Chemin | Contenu | Statut |
|---|---|---|
| `README.md` | Vision, avancement, TODO, journal | Vivant |
| `AGENTS.md` | Ce fichier | Vivant |
| `CLAUDE.md` | Notes pour les agents Claude : état, décisions, ancienne version | Vivant, aligné sur le spec |
| `SPEC.md`, `SPEC-*.md` | Spec : carte des modules et un spec par module M1 | Approuvé, vivant |
| `tasks/plan.md`, `tasks/todo.md` | Plan M1 et ses 26 tâches | Approuvé, vivant |
| `docs/PLAN.md` | Plan, décisions, jalons M0–M5, réponses de l'équipe | Vivant |
| `docs/QUESTIONS-EQUIPE.md` | 23 questions à l'équipe (français) | Réponses partielles (19 oct.) |
| `examples/interface/mockups.html` | Maquettes statiques, 3 layouts, un tour IA | Référence visuelle |
| `examples/godot/` | Exemples GDScript : `core/`, `ai/`, `narration/`, `world/`, `content/` | À déplacer dans `game/src/` (tâches 3–23) |
| `examples/content/` | Modèles d'écriture, guide artiste (8 directions), CSV | Modèles |
| `examples/proxy/worker.ts` | Worker Cloudflare d'exemple | Non déployé, non testé |
| `examples/tools/balance_sim.py` | Vérification CSV + simulation de combats | Fonctionnel sur les CSV d'exemple |
| `examples/ai-tests/` | Scénarios pièges, réponses Haiku, résultats | Corrections décidées : tâche 8 ; fixtures : tâche 10 |
| `game/` | Projet Godot (`src/` code, `content/` fichiers de l'équipe, `tests/`) | **Absent** (tâche 1) |
| `proxy/` | Déploiement du Worker | **Absent** (M2) |
| `tools/` | Outils Python de production | **Absent** (M4) |

## 4. État vérifié au 2026-10-19

À revérifier avec `command -v` si l'environnement a changé.

| Fait | Preuve / conséquence |
|---|---|
| Aucun code de jeu, aucune scène Godot | `game/` absent ; `examples/` est statique |
| Le remote GitHub existe (`origin`), dépôt public | `git remote -v` |
| `balance_sim.py --check` passe | `OK: data files look good` |
| Machine du lead : Python 3.13.7, Godot 4.7.2 (pas dans le `PATH`, voir la variable `GODOT` en 5), pas de Node.js | `python --version` |
| Machine d'Alban : Python 3.14.7, Node.js 26.8.1, pnpm et Godot absents | Ne pas prétendre y avoir exécuté du GDScript |
| Aucune suite de tests, aucun CI | Le runner arrive à la tâche 1. Ne pas inventer `npm test`, `make test` ou équivalent |
| Questionnaire : réponses partielles | Restent 1, 8, 10, 13, 15–23 (voir 11) |

## 5. Commandes

| But | Commande | Attendu |
|---|---|---|
| Vérifier les données d'exemple | `python3 examples/tools/balance_sim.py --check` | `OK: data files look good`, sinon liste des problèmes |
| Simuler des combats | `python3 examples/tools/balance_sim.py --fights 5000` | Tableau de dangerosité par monstre |
| Ouvrir les maquettes (macOS) | `open examples/interface/mockups.html` | Navigateur ; Windows : `start ...` |
| Voir l'état Git | `git status --short` | Aucun fichier inattendu |
| Voir l'historique | `git log --oneline` | Commits du projet |

Une fois `game/` créé (tâche 1), sur la machine du lead (Git Bash ; commandes *provisoires* tant que le moteur n'est pas confirmé) :

```bash
GODOT="/c/2026-2027/DND project/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path game --script res://tests/run_all.gd                    # tous les tests, code 1 si échec
"$GODOT" --headless --path game --export-release "Web" ../builds/web/index.html     # build web
python -m http.server 8000 --directory builds/web                                   # jouer sur http://localhost:8000
```

Pour rejouer le test IA, voir [examples/ai-tests/RESULTS.md](examples/ai-tests/RESULTS.md). Au checkpoint 2, S1 et S8 se rejouent dans le vrai jeu.

## 6. Contrats

Résumé. **Les contrats complets sont dans les specs** : en cas d'écart, le spec fait foi.

### 6.1 Réponse du MJ IA ([SPEC-dm.md](SPEC-dm.md))

Format exact : narration, puis une ligne `<<STATE>>`, puis **un seul** objet JSON.

```text
La passerelle gémit sous vos pas...
<<STATE>>
{"commands": [{"type": "move_to", "target": "mill_bridge"}],
 "state": {"gold_delta": 5, "time_advance_minutes": 10}}
```

- **Commandes autorisées :** `move_to`, `spawn`, `despawn`, `emote`, `weather`, `request_roll`. Maximum 5.
- **Bornes :** `hp_delta` −30…+30, `gold_delta` −200…+200, `time_advance_minutes` 0…1440, `add_items` 3 au plus ; `dc` entier de 5 à 30 ; `emote.who` = `hero` ou un PNJ autorisé. Hors bornes : ramené dans les bornes et noté, ou ignoré.
- **Identifiants :** uniquement ceux de la liste `ALLOWED IDS` (lieux, créatures, objets, quêtes, PNJ, compétences).
- **État :** `hp_delta`, `gold_delta`, `time_advance_minutes`, `add_items`, `quest_updates`.
- **Effets :** `burn`, `freeze`, `shock`, `poison`, `whisper`, `holy`. Au plus 4 tags de l'IA par entrée (30 caractères au plus dans un tag), et 6 mots animés au total avec la liste de mots. Un tag mal fermé ou imbriqué s'affiche tel quel.
- Le parseur rejette ou ignore tout ce qui est inconnu ou hors bornes. Ne jamais assouplir ces contrôles pour « faire passer » une réponse.
- La narration est aussi non fiable : le BBCode non autorisé doit être échappé, pas exécuté.
- **Dérive récit/état :** si la narration déplace le héros, une commande `move_to` doit suivre. C'est le défaut S8 du test Haiku, corrigé dans `dm-rules.md` à la tâche 8.

### 6.2 État et sauvegardes ([SPEC-core.md](SPEC-core.md))

- Un seul `Dictionary` sérialisable, avec `version`. L'**état v1** ajoute `weather`, `creatures` (6 au plus) et `last_roll`.
- On ne change l'état que par `core` : `apply_changes`, puis `apply_commands` (qui vide d'abord `last_roll`). Les jets de M1 se font tout de suite ; l'IA raconte le résultat au tour suivant.
- Sauvegardes (M2) : JSON dans `user://saves/` (IndexedDB dans le build web). M1 n'a pas de sauvegarde.
- Une fonction `_vN_to_vN+1()` par changement de forme ; test de chargement obligatoire.
- Le journal d'actions et Rewind sont prévus (M2), pas encore implémentés.
- Les dés sont seedés ; l'état du RNG fait partie de l'état.

### 6.3 Contenu éditable ([SPEC-content.md](SPEC-content.md))

CSV en UTF-8, séparateur `,` ou `;` (Excel en français). Colonnes du spec :

| Fichier | Colonnes |
|---|---|
| `monsters.csv` | `id`, `name_en`, `name_fr`, `level`, `hp`, `ac`, `attack_bonus`, `damage`, `xp`, `habitat`, `sprite` |
| `items.csv` | `id`, `name_en`, `name_fr`, `type`, `price`, `damage`, `ac_bonus`, `heal`, `weight`, `icon`, `description_en`, `description_fr` |
| `quests.csv` | `quest`, `stage`, `title_en`, `title_fr` |
| `keywords.csv` | `effect`, `lang`, `words` |
| `ui_text.csv` | `key`, `en`, `fr` |

- Les CSV de `examples/content/data/` gardent l'ancien format (`name`) ; la tâche 6 les convertit dans `game/content/data/`.
- Identifiants : `[a-z0-9_]+`, minuscules, sans espaces ni accents.
- Noms de fichiers d'art : préfixes `tiles-`, `hero-`, `creature-`, `npc-`, `item-`, `fx-` ; animations en 8 directions, avec des lignes facultatives et un repli (voir [GUIDE-ARTISTE.md](examples/content/art/GUIDE-ARTISTE.md)).
- Modèles d'écriture : [pnj-modele.md](examples/content/writing/pnj-modele.md), [lieu-modele.md](examples/content/writing/lieu-modele.md).
- Le code lit ces fichiers ; il ne les remplace pas par des constantes. `game/content/` appartient à l'équipe : prévenir avant d'y modifier un fichier.

### 6.4 Prompt et modes IA ([SPEC-dm.md](SPEC-dm.md))

Ordre stable → variable, en 7 parties :
1. règles du MJ + une ligne de langue ;
2. codex ;
3. histoire jusqu'ici ;
4. vue de l'état ;
5. identifiants autorisés ;
6. dernier jet ;
7. action du joueur.

- M1 : copier-coller et clé personnelle. Le proxy arrive en M2.
- Le mode copier-coller est le défaut gratuit ; il doit rester intact.
- Le proxy ne reçoit que des données de jeu, jamais les règles ni un choix de modèle : le Worker décide.
- La clé personnelle est stockée localement (`user://settings.cfg`), jamais livrée avec le jeu.
- « Histoire jusqu'ici » en M1 : l'intro + les 3 dernières narrations (600 caractères chacune au plus). En M2, un résumé glissant rafraîchi sur un petit modèle.
- Jamais envoyés : `seed`, `rng_state`, `log`, les réglages, la clé.
- Toute modification de `dm-rules.md` doit être suivie d'un test des scénarios pièges.

### 6.5 Scène et interface ([SPEC-main-screen.md](SPEC-main-screen.md), [SPEC-world.md](SPEC-world.md))

- Structure de référence : [scene_tree.md](examples/godot/scene_tree.md).
- Deux blocs : `World` (60 %) et `StoryPanel` (40 %). M1 : layout A, côte à côte. Layout B (empilé) en M2 ou plus tard, selon la question 1.
- Autoloads : `Game`, `Content`, `DM`, sans règles dedans.
- La boucle de tour suit l'ordre en 11 étapes de `SPEC-main-screen.md`. Pendant un tour, l'action et les déplacements sont bloqués.
- Monde M1 : la zone du chemin du moulin, en vue de dessus. Le héros va là où on clique, en 8 directions, avec repli si l'art manque.
- Le monde et le panneau doivent rester séparés ; l'UI ne contient pas de règles.

## 7. Conventions de code

### GDScript (provisoire, voir [SPEC.md](SPEC.md#code-style-provisional-gdscript))

- Godot 4.7, indentation par **tabulations**, typage explicite (`var x: int`, `-> void`). Convertir les nombres JSON avec `int()`.
- Noms : `snake_case` pour les fichiers, fonctions et variables ; `PascalCase` pour `class_name` ; `UPPER_CASE` pour les constantes ; signaux au passé (`finished_typing`).
- Les règles et les données vont dans des scripts `RefCounted` ou des fonctions `static`, jamais dans des nœuds. Les nœuds affichent, animent et émettent des signaux.
- « Appeler vers le bas, signaler vers le haut » : un parent appelle ses enfants ; un enfant émet un signal.
- Les adapters IA sont des coroutines (`await`) ; le presse-papiers ne s'ouvre qu'après un clic.
- Commentaire `##` sur chaque classe et fonction publique ; commenter le **pourquoi**, pas la syntaxe évidente.
- Code, commentaires et specs en anglais ; documents pour l'équipe en français.
- Parse-checker avant de prétendre qu'un script est valide.
- Pièges Godot : les CSV sont importés comme traductions par défaut → « Import As: Keep File » (sauf `ui_text.csv`) ; ajouter `*.csv, *.md` aux filtres d'export.

### Python

- Bibliothèque standard uniquement, Python 3.13+ (3.14 testé), `pathlib`.
- Lancer `--check` avant `--fights` et avant de considérer un contenu d'exemple comme valide.
- Ne pas ajouter de dépendance sans demande.

### TypeScript (Worker)

- Clé dans les secrets d'environnement Cloudflare, jamais dans le code.
- CORS, limite de taille, limite de débit, liste blanche de modèles.
- Ne jamais accepter un modèle ou des règles choisis par le client.
- Le Worker n'a pas été testé : le dire si on le modifie.

### Documentation

- Français pour les documents d'équipe ; l'anglais existant (specs, plan M1, `CLAUDE.md`) reste en anglais.
- Une information = un endroit. Contrats et limites dans `SPEC*.md`, tâches M1 dans `tasks/`, décisions dans `PLAN.md`, avancement dans `README.md`, règles d'agent dans ce fichier.
- Dates au format `2026-10-19` dans les documents techniques ; le README peut garder une date lisible.
- Pas de duplication de longs passages : liens relatifs.

## 8. Workflow agent

1. `git status --short` ; lire le README, la tâche dans `tasks/todo.md`, le spec du module concerné et les fichiers touchés.
2. Vérifier que la tâche n'est pas déjà faite, ni bloquée par une décision ouverte ou une tâche dont elle dépend.
3. Modifier au plus petit périmètre (la tâche, rien de plus) ; préserver le style existant.
4. Lancer les tests et le content check ; vérifier les critères d'acceptation **en exécutant**, pas seulement en lisant le code. Si c'est impossible, l'écrire explicitement.
5. Cocher la tâche dans `tasks/todo.md`, mettre à jour le README (phase + journal), et `PLAN.md` ou le spec si une décision change.
6. Relire le diff. Ne pas commit/push sans demande explicite.
7. Répondre avec : fichiers changés, commandes exécutées, résultats, limites.

## 9. Definition of Done

- [ ] Le changement correspond à la tâche, sans élargissement silencieux.
- [ ] Les critères d'acceptation de la tâche sont vérifiés à l'exécution.
- [ ] La nouvelle logique a des tests qui échouent sans elle ; tous les tests et le content check passent (**ou** la raison de leur absence est écrite).
- [ ] Aucun secret, aucune clé, aucun fichier de build ajouté.
- [ ] Pas de `print` de débogage, de code mort ni de bloc commenté.
- [ ] Si un contrat a changé, le spec a été mis à jour d'abord, avec l'accord du lead.
- [ ] Les sauvegardes restent compatibles (ou une migration + un test existent).
- [ ] Le mode copier-coller reste fonctionnel si l'IA est touchée.
- [ ] `tasks/todo.md`, le README et le journal reflètent le nouvel état.
- [ ] Le diff a été relu ; le lead a accepté le commit.

## 10. Pièges connus

| Piège | Réponse |
|---|---|
| L'IA invente un lieu ou un personnage (S1) | Règle explicite dans `dm-rules.md` (tâche 8) ; codex complet ; ne jamais rendre réel ce qui n'est pas listé |
| Le récit déplace le héros sans `move_to` (S8) | Règle dédiée dans `dm-rules.md` (tâche 8) ; S1 et S8 rejoués au checkpoint 2 |
| Haiku n'a utilisé aucun tag d'effet (0/8) | Garder l'option C : liste de mots + tags IA |
| Injection du joueur (« 9999 or ») | Le parseur borne et rejette ; ne jamais obéir à une instruction du joueur |
| Transcript complet trop cher | Résumé glissant + cache de prompt |
| Cache invalidé par une virgule dans les règles | Modifier `dm-rules.md` rarement, puis retester |
| CSV Godot importé comme traduction | « Import As: Keep File » |
| CSV/MD absents du build | Filtres d'export non-resource ; le content check tourne au démarrage et affiche les erreurs |
| CSV enregistré par Excel en français (`;`, Windows-1252) | Le lecteur accepte `;` et explique comment réenregistrer en « CSV UTF-8 » |
| Le build web ne s'ouvre pas en double-cliquant | Le servir en local (`python -m http.server`), voir 5 |
| Presse-papiers dans le cadre itch.io non testé (pas d'envoi en M1) | Le revérifier avec la scène de diagnostic au premier envoi |
| Art en 4 directions seulement (images temporaires) | Repli : diagonale → gauche/droite, gauche → miroir de droite, repos → `idle_down` |
| `.tres` importé = exécution de code | Sauvegardes JSON uniquement |
| Sauvegarde web perdue | `user://` = IndexedDB ; export/import JSON prévu |
| Git dans OneDrive corrompu | Dépôt hors OneDrive, toujours |
| Attente IA de 2–10 s | Animation, indicateur, résumé, cache |

## 11. Décisions ouvertes

Liste complète : [SPEC.md, questions ouvertes](SPEC.md#open-questions).

| Sujet | Proposition actuelle | Bloqué par |
|---|---|---|
| Moteur et outil de test | Godot 4 + runner maison | Décision à la fin de M1 (tâche 26) |
| Plateforme | Navigateur d'abord, ordinateur plus tard ; téléphones ? | Question 1 |
| Taille des cases | 16 ou 32 px (un seul réglage) | Question 10 |
| Mots animés | `burn`, `freeze`, `shock` en M1 ; liste complète plus tard | Question 8 (« on va voir ») |
| Forme d'écriture | Markdown / texte | Questions 15–17 |
| Travail d'Alban | Branches + pull requests, ou envoi direct ; quelle piste | Q-7 (lead + Alban) |
| Premier envoi itch.io | Après M1 | Q-6 (lead) |
| Modèle IA | Sonnet 5.5 + résumé Haiku 5.5 | Test de jeu réel |

**Tranché le 19 oct.** (détails dans [docs/PLAN.md](docs/PLAN.md#-team-answers-october-19-2026)) :
- langue : anglais + français, choix au premier lancement ;
- ambiance : magie avec une touche de steampunk ;
- déplacements : au choix du lead, donc clic pour avancer ;
- monde : lieux importants à la main, le reste généré puis stocké ;
- combat : tour par tour avec dés et animations ;
- rôle du MJ : il raconte, le jeu garde les règles ;
- style : pixel art, vue de dessus, 8 directions, images temporaires d'abord.

Nouvelles réponses : les consigner dans [docs/QUESTIONS-EQUIPE.md](docs/QUESTIONS-EQUIPE.md), puis les répercuter dans [docs/PLAN.md](docs/PLAN.md), le spec et le README.

## 12. Fichiers à manipuler avec précaution

| Fichier | Risque |
|---|---|
| `SPEC.md`, `SPEC-*.md` | Contrats partagés : demander avant de changer l'état, la réponse IA ou les formats de fichiers |
| `dm-rules.md` (`examples/content/writing/`, puis `game/content/writing/` dès la tâche 8) | Partie cachée du prompt : change le comportement et le coût |
| `dm_reply_parser.gd` → `game/src/dm/reply_checker.gd` | Dernière barrière avant l'état du jeu |
| `game_state.gd` (`examples/godot/core/`, puis `game/src/core/`) | Toute forme d'état doit être migrée |
| `examples/godot/core/save_system.gd` | Une erreur casse les parties existantes |
| `examples/proxy/worker.ts` | Secret, abus, coût |
| `game/content/` | Fichiers de l'équipe : la prochaine copie depuis OneDrive écraserait une modification ; corriger à la source |
| `README.md` | Source de vérité de l'avancement global |
| `tasks/todo.md` | Détail des tâches M1 : ne cocher qu'avec une preuve |
| `.gitignore` | Une omission peut commiter un secret |

## 13. Maintenance de ce fichier

- Mettre à jour la **version en tête** à chaque changement structurel.
- Garder ce fichier court : les détails vont dans les specs, `docs/` ou `examples/`.
- Supprimer une règle devenue fausse plutôt que l'empiler.
- Si ce fichier et un `SPEC*.md` divergent, **le spec fait foi** : corriger ce fichier. Si `CLAUDE.md` diverge, le signaler pour le mettre à jour.
