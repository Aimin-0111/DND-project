# Spec : Brasswake Reach — tranche verticale M1

> **Statut : approuvé le 2026-10-19.** Branche : `Beta-0.1`. Plan : [tasks/plan.md](tasks/plan.md).
> Décisions validées : M1, Godot 4.7 desktop, contenu Mill Road / Oda / loup de rouille, IA en copier-coller, jeu bilingue dès M1.
> Carte de capacités : approuvée (§3). L'implémentation a commencé après validation.

## 0. Hypothèses intégrées

1. Le code, les identifiants et les commentaires sont en **anglais** ; les documents d'équipe sont en **français** ; le jeu est **bilingue FR/EN**.
2. Le prototype est d'abord pour **vous trois**, puis pour quelques testeurs privés. Pas de page publique en M1.
3. Un seul OS desktop est livré en M1 : **macOS** sur la machine de développement actuelle. Windows suit si l'export est disponible.
4. L'art est temporaire, en **32 × 32 px**, sous licence libre (CC0). Le style et la taille définitifs restent à trancher (questionnaire 9–12).
5. `game/` est créé de zéro. `examples/` reste une référence statique : on copie et adapte, on ne le modifie pas pour faire passer le jeu.
6. Godot **4.7.x** et GDScript, sans addon externe. Python 3.13+ pour les outils de contenu.
7. Le mode IA M1 est **copier-coller uniquement** ; pas de proxy, pas de clé API, pas de Worker.

Si une hypothèse est fausse, elle doit être corrigée **avant** l'approbation du SPEC.

## 1. Objective

### 1.1 Ce qu'on construit

Une **tranche verticale jouable de bout en bout** : le joueur lance le jeu, voit une zone, déplace son héros, saisit une action, colle une réponse de MJ IA, lit la narration animée, voit une conséquence dans le monde, puis sauvegarde et recharge sa partie. Le tout en français ou en anglais.

Ce n'est pas le jeu complet : c'est la preuve que la boucle « monde + récit + IA + état » tient debout, et que Godot est le bon moteur.

### 1.2 Utilisateurs

| Utilisateur | Besoin en M1 |
|---|---|
| **Joueur solo** | Comprendre où il est, agir, lire une scène, voir son action avoir un effet, sauvegarder |
| **Scénariste** | Écrire PNJ et lieux en FR et EN dans des fichiers simples, sans code |
| **Artiste** | Déposer un tileset, un héros, un PNJ, une créature et des icônes sans code |
| **Lead** | Lancer, tester, exporter et publier une build privée sur itch.io |

### 1.3 Histoires utilisateur

- En tant que joueur, je clique sur le vieux moulin, le héros s'y rend, et la caméra le suit.
- En tant que joueur, je décris une action, je copie le prompt, je colle la réponse du MJ, et la narration s'affiche avec au moins un mot animé.
- En tant que joueur, si la réponse du MJ demande de faire apparaître le loup de rouille, il apparaît dans la scène.
- En tant que joueur, je peux passer du français à l'anglais : l'interface, les noms et le prochain prompt suivent.
- En tant que joueur, je sauvegarde, je quitte, je recharge, et je retrouve exactement mon état.
- En tant que scénariste, je modifie un fichier Markdown ou CSV, je lance la vérification, et une traduction manquante est signalée avant le jeu.
- En tant que lead, je lance une commande unique de tests et une commande d'export, et j'obtiens une build privée.

### 1.4 Hors périmètre M1

Combat complet, quêtes multiples, monde multi-zones, PNJ errants, cycle jour/nuit avancé, météo animée complète, proxy Cloudflare, clé API personnelle, résumé d'histoire automatique, Rewind, son, tutoriel, page itch.io publique, version web.

## 2. Tech Stack

| Élément | Choix | Notes |
|---|---|---|
| Moteur | Godot 4.7.x | GDScript, scènes `.tscn` |
| Langage jeu | GDScript typé | Pas de C#, pas de plugin |
| Rendu | 2D pixel art | `TextureFilter` nearest, résolution de base 1280 × 720 |
| Données | CSV + Markdown | Éditables par l'équipe, chargés à l'exécution |
| Interface bilingue | CSV `strings.csv` chargé par le jeu | Pas de `.translation` Godot en M1 |
| Sauvegardes | JSON versionné dans `user://saves/` | Jamais de `.tres` importé |
| Outils | Python 3.13+ | Bibliothèque standard uniquement |
| Versionnage | Git + GitHub | Travail sur `Beta-0.1` |
| Distribution | itch.io privé + `butler` | Build desktop d'abord |
| Hors stack M1 | Node.js, Cloudflare, API Claude directe | Prévu en M2 |

**Contrainte d'environnement :** Godot n'est pas installé dans l'environnement actuel. Les commandes Godot devront être exécutées sur la machine du lead (Godot 4.7.2) avant de cocher un critère. Le SPEC ne prétend pas que ces commandes ont déjà été lancées.

## 3. Capability Map — M1

| Module id | Responsabilité | Dépend de |
|---|---|---|
| `bootstrap` | Projet Godot, dossiers, autoloads, scène principale, presets d'export | — |
| `content` | Chargement des CSV/Markdown, chaînes FR/EN, identifiants autorisés | `bootstrap` |
| `core` | État sérialisable, dés seedés, sauvegarde versionnée, application des changements | `bootstrap` |
| `ai-turn` | Construction du prompt, adaptateur copier-coller, parseur des réponses | `core`, `content` |
| `narration` | Panneau de récit, machine à écrire, tagage et effets des mots | `content` |
| `world` | Zone, héros, caméra, déplacement clic, application des commandes | `core`, `content` |
| `shell` | Layout 40/60, HUD, orchestration d'un tour, sauvegarde/chargement, build | `ai-turn`, `narration`, `world` |

**Ordre de construction :** `bootstrap` → `content` + `core` → `ai-turn`, `narration`, `world` → `shell`.

**Règles de dépendance :**

- `core` ne connaît ni l'UI, ni la scène, ni le réseau.
- `ai-turn` ne modifie jamais l'état : il produit une réponse parsée.
- `world` n'applique que des commandes déjà validées par `ai-turn`.
- `narration` ne valide pas l'IA : elle reçoit du BBCode déjà sûr.
- `shell` est le seul à orchestrer l'ordre d'un tour.

## 4. Commands

### 4.1 Commandes actuelles (vérifiées)

```bash
# Vérifier les données d'exemple existantes
python3 examples/tools/balance_sim.py --check

# Simuler des combats sur les données d'exemple
python3 examples/tools/balance_sim.py --fights 5000

# Voir l'état Git
git status --short
git switch Beta-0.1
```

### 4.2 Commandes cibles (à faire fonctionner avant la fin de M1)

```bash
# Ouvrir l'éditeur
godot --path game --editor

# Lancer le jeu
godot --path game

# Vérifier l'import et le démarrage sans interface
godot --headless --path game --quit

# Lancer les tests GDScript (runner maison, sortie ≠ 0 si échec)
godot --headless --path game --script res://tests/run_tests.gd

# Vérifier le contenu et les traductions FR/EN
python3 tools/content_check.py --check --langs fr,en

# Simuler l'équilibrage (données d'exemple, en attendant l'outil M4)
python3 examples/tools/balance_sim.py --fights 5000

# Exporter une build macOS puis Windows
godot --headless --path game --export-release "macOS" builds/macos/BrasswakeReach.zip
godot --headless --path game --export-release "Windows Desktop" builds/windows/BrasswakeReach.exe
```

**Règles :**

- `tools/content_check.py`, `game/tests/run_tests.gd` et les presets d'export sont des **livrables M1**. La simulation d'équilibrage reste sur les données d'exemple jusqu'à M4.
- Les commandes de test et de contenu doivent renvoyer un code de sortie non nul en cas d'échec.
- Aucun CI en M1 : les commandes sont lancées localement avant chaque commit.
- Les presets d'export et les modèles d'export Godot doivent être installés sur la machine qui exporte.

## 5. Project Structure

```text
.
├─ SPEC.md                    ← ce document
├─ README.md                  ← avancement et TODO
├─ AGENTS.md                  ← règles agents
├─ docs/
│  ├─ PLAN.md
│  └─ QUESTIONS-EQUIPE.md
├─ game/                      ← projet Godot (à créer)
│  ├─ project.godot
│  ├─ main.tscn               ← scène principale
│  ├─ export_presets.cfg      ← presets macOS / Windows
│  ├─ autoload/
│  │  ├─ game.gd              ← état courant, dés, sauvegarde
│  │  ├─ content.gd           ← données, chaînes, langue
│  │  └─ dm.gd                ← adaptateur IA actif
│  ├─ core/
│  │  ├─ dice.gd
│  │  ├─ game_state.gd
│  │  └─ save_system.gd
│  ├─ content/
│  │  ├─ content_loader.gd
│  │  ├─ data/                ← CSV numériques (Keep File)
│  │  │  ├─ monsters.csv
│  │  │  ├─ items.csv
│  │  │  ├─ locations.csv
│  │  │  ├─ quests.csv
│  │  │  └─ keywords.csv
│  │  ├─ i18n/
│  │  │  └─ strings.csv       ← key,fr,en (Keep File)
│  │  ├─ writing/
│  │  │  ├─ dm-rules.md       ← règles stables du MJ (anglais)
│  │  │  ├─ fr/               ← lore, PNJ, lieux en français
│  │  │  └─ en/               ← mêmes fichiers en anglais
│  │  └─ art/                 ← tuiles, sprites, icônes, CREDITS.md
│  ├─ ai/
│  │  ├─ ai_adapter.gd
│  │  ├─ copy_paste_adapter.gd
│  │  ├─ prompt_builder.gd
│  │  └─ dm_reply_parser.gd
│  ├─ narration/
│  │  ├─ narration_panel.gd
│  │  ├─ keyword_tagger.gd
│  │  └─ effects/
│  ├─ world/
│  │  ├─ world.tscn
│  │  ├─ hero.tscn
│  │  ├─ movement_click.gd
│  │  ├─ walk_grid.gd
│  │  ├─ scene_director.gd
│  │  └─ creatures/rust_wolf.tscn
│  ├─ ui/
│  │  ├─ hud.tscn
│  │  ├─ story_panel.tscn
│  │  └─ paste_dialog.tscn
│  └─ tests/
│     ├─ run_tests.gd
│     ├─ unit/
│     ├─ integration/
│     └─ fixtures/
├─ tools/
│  └─ content_check.py        ← schémas, ids, traductions
├─ builds/                    ← ignoré par Git
└─ examples/                  ← référence statique, non modifiée
```

**Règles de structure :**

- `game/` est le seul projet Godot. Les scripts de jeu ne vivent pas dans `examples/`.
- Les CSV de données et `strings.csv` sont importés en **Keep File**, pas en traduction Godot.
- Les réglages d'import (CSV/MD) sont documentés et versionnés, avec les fichiers `.import` si Godot en génère, pour que l'import soit reproductible.
- `builds/` et `.godot/` restent ignorés par Git.
- Un fichier `CREDITS.md` dans `game/content/art/` liste la licence de chaque asset temporaire.

## 6. Code Style

### 6.1 Conventions générales

| Élément | Convention | Exemple |
|---|---|---|
| Fichiers GDScript | `snake_case.gd` | `game_state.gd` |
| Classes | `PascalCase` | `GameState`, `DmReplyParser` |
| Fonctions et variables | `snake_case` | `apply_changes`, `visible_state` |
| Constantes | `UPPER_SNAKE_CASE` | `MAX_COMMANDS`, `SAVE_DIR` |
| Signaux | passé / événement | `finished_typing`, `status_changed` |
| Nœuds de scène | `PascalCase` | `StoryPanel`, `SceneDirector` |
| Clés JSON | `snake_case` | `hp_delta`, `time_advance_minutes` |
| IDs de contenu | `[a-z0-9_]+` | `rust_wolf`, `old_mill` |
| Clés de traduction | pointées | `ui.act`, `monster.rust_wolf.name` |
| Indentation | **tabulations** | GDScript standard |

### 6.2 Extrait de style GDScript

```gdscript
class_name GameState
extends RefCounted

const VERSION := 1


## The game still clamps values after the parser has checked them.
static func apply_hp(state: Dictionary, delta: int) -> void:
	var hero: Dictionary = state["hero"]
	hero["hp"] = clampi(int(hero["hp"]) + delta, 0, int(hero["hp_max"]))
```

### 6.3 Règles de code

- Typage explicite des paramètres, retours et variables non évidentes.
- `class_name` pour les classes réutilisables ; `static` pour les fonctions pures.
- Le cœur et le parseur ne dépendent ni de l'UI ni de `get_tree()`.
- Les adapters IA sont des coroutines (`await`) et retournent une chaîne vide en cas d'annulation ou d'erreur.
- Les commentaires expliquent le **pourquoi**, pas la syntaxe. En anglais dans le code.
- Aucun texte visible par le joueur codé en dur : passer par `Content.t("clé")`.
- Aucune donnée de jeu (monstre, objet, lieu, quête) codée en dur dans un script.
- Les erreurs de parseur sont visibles dans l'UI et ne modifient jamais l'état.
- Python : bibliothèque standard, `pathlib`, fonctions courtes, code de sortie non nul en cas d'échec.
- Pas de `print` de debug laissé dans une scène de production ; utiliser `push_warning` ou un log dédié si nécessaire.

## 7. Contracts et modèle de données

### 7.1 État de jeu — version 1

```json
{
  "version": 1,
  "seed": 12345,
  "rng_state": 0,
  "turn": 0,
  "time_minutes": 960,
  "location": "mill_road",
  "language": "fr",
  "hero": {
    "name_key": "hero.kael.name",
    "hp": 12,
    "hp_max": 12,
    "ac": 14,
    "abilities": {"str": 12, "dex": 16, "con": 13, "int": 10, "wis": 14, "cha": 8},
    "skills": {"Stealth": 5, "Survival": 4, "Perception": 4}
  },
  "gold": 10,
  "pack": [
    {"id": "rusty_sword", "qty": 1},
    {"id": "healing_draught", "qty": 2}
  ],
  "quests": {
    "the_silent_mill": {"stage": 0, "done": false}
  },
  "story_summary": "",
  "log": []
}
```

- `language` vaut `fr` ou `en` ; il est sauvegardé et restauré.
- `story_summary` et `log` sont réservés à M2 mais présents dès la v1 pour éviter une migration inutile.
- `rng_state` est mis à jour après chaque lancer de dés et sauvegardé.
- Les nombres relus depuis JSON sont des flottants : toujours `int(...)` avant comparaison ou affichage entier.
- Toute modification de forme incrémente `GameState.VERSION` et ajoute une migration testée.

### 7.2 Contrat de réponse du MJ IA

Format exact : narration, ligne `<<STATE>>`, un seul objet JSON.

```text
La passerelle gémit sous vos pas...
<<STATE>>
{"commands": [{"type": "move_to", "target": "mill_bridge"}],
 "state": {"gold_delta": 5, "time_advance_minutes": 10}}
```

| Élément | Contrat |
|---|---|
| Commandes | `move_to`, `spawn`, `despawn`, `emote`, `weather`, `request_roll` |
| Maximum | 5 commandes, 4 mots avec effet |
| IDs | uniquement ceux de `ALLOWED IDS` (lieux, créatures, objets, compétences, quêtes) |
| État | `hp_delta`, `gold_delta`, `time_advance_minutes`, `add_items`, `quest_updates` |
| Bornes | HP ±30, or ±200, temps 0–1440 min, `dc` 5–30 |
| Effets | `burn`, `freeze`, `shock` en M1 (les 6 restent acceptés par le parseur) |
| Langue | la narration et les noms affichés suivent `TURN INPUT.language` ; les IDs et clés JSON restent en anglais |
| Dérive | si la narration déplace le héros, une commande `move_to` est obligatoire |
| Invention | un lieu, un PNJ, un objet ou une créature absent du codex n'existe pas et ne doit pas être décrit comme réel |

Le parseur ne fait pas confiance à l'IA : il rejette ou ignore toute commande inconnue, tout ID absent et toute valeur hors bornes. Une réponse invalide **ne modifie pas l'état**.

En M1, `move_to`, `spawn`, `despawn` et `weather` ont un effet visible. `emote` et `request_roll` sont validés puis affichés dans le journal, sans animation ni résolution automatique.

### 7.3 Contenu bilingue

**Données numériques (neutres en langue) :**

| Fichier | Colonnes |
|---|---|
| `monsters.csv` | `id`, `level`, `hp`, `ac`, `attack_bonus`, `damage`, `xp` |
| `items.csv` | `id`, `type`, `price` |
| `locations.csv` | `id` |
| `quests.csv` | `id`, `max_stage` |
| `keywords.csv` | `effect`, `lang`, `words` (`words` séparés par `|`) |

**Chaînes et noms (bilingues) :**

`game/content/i18n/strings.csv` : `key,fr,en`, une ligne par texte visible.

```csv
key,fr,en
ui.act,Agir,Act
hero.kael.name,Kael,Kael
location.mill_road.name,Route du moulin,Mill Road
monster.rust_wolf.name,Loup de rouille,Rust Wolf
item.healing_draught.name,Potion de soin,Healing Draught
quest.the_silent_mill.title,Le moulin silencieux,The Silent Mill
```

Règles :

- Toute clé utilisée par l'UI ou le contenu doit exister en `fr` **et** en `en`.
- Aucune colonne `name` localisée dans les CSV numériques.
- Les fichiers de lore vivent dans `writing/fr/` et `writing/en/`, avec les mêmes noms de fichiers.
- `dm-rules.md` est technique, en anglais, et demande au MJ d'écrire dans la langue fournie par le tour.
- `keywords.csv` contient les mots-clés des deux langues ; le tagger ne charge que la langue active.
- `content_check.py` échoue si une clé, un fichier de lore ou un mot-clé manque dans une langue.

### 7.4 Prompt

Ordre stable → variable :

1. `rules` : `dm-rules.md`, jamais modifié par le joueur.
2. `codex` : lore/PNJ/lieux dans la langue active.
3. `summary` : vide en M1, réservé au résumé glissant M2.
4. `state` : état visible, lieu, temps, or, inventaire, quêtes.
5. `allowed` : IDs autorisés.
6. `turn` : action du joueur **et** `language` (`fr`/`en`).

La langue est dans la partie variable, pas dans les règles, pour garder les règles et le cache stables. Chaque réponse doit être vérifiée par le parseur, quelle que soit la langue.

### 7.5 Déroulement d'un tour

1. Le joueur saisit une action dans le panneau.
2. `DM` construit le prompt avec `Game` et `Content`.
3. `CopyPasteAdapter` copie le prompt dans le presse-papiers et ouvre la boîte de dialogue.
4. Le joueur colle la réponse et valide.
5. `DmReplyParser` sépare narration, commandes et changements d'état.
6. Si la réponse est invalide : message d'erreur, aucun changement d'état, le joueur peut réessayer.
7. Si elle est valide : la narration s'affiche avec la machine à écrire et les effets.
8. Une fois la narration terminée, `SceneDirector` applique les commandes.
9. `GameState.apply_changes` applique les changements, puis la partie est sauvegardée automatiquement.
10. Le tour suivant repart de l'état mis à jour.

### 7.6 Comportement bilingue

- Langue par défaut : locale système si `fr` ou `en`, sinon `fr`.
- Le changement de langue met à jour l'UI, les noms, les mots-clés et le codex sans redémarrer.
- La langue est sauvegardée dans l'état et restaurée au chargement.
- Le prompt suivant contient la nouvelle langue.
- Une réponse IA dans la mauvaise langue n'est pas rejetée par le parseur (il ne traduit pas), mais elle est signalée dans le journal de test manuel.

## 8. Testing Strategy

### 8.1 Niveaux de test

| Niveau | Outil | Emplacement | Ce qui est couvert |
|---|---|---|---|
| Unitaire | GDScript headless | `game/tests/unit/` | Dés, état, sauvegarde, parseur, tagger, chargement des chaînes |
| Intégration | GDScript headless | `game/tests/integration/` | Prompt → parseur → application d'état ; commandes → scène de test |
| Contenu | Python | `tools/content_check.py` | Schémas CSV, IDs, dés, traductions FR/EN, fichiers de lore |
| Manuel | Godot + navigateur | checklist §8.3 | Layout, machine à écrire, effets, copier-coller, sauvegarde |
| IA | Agents + relecture | `docs/` ou rapport dédié | Hallucinations, injection, dérive récit/état |

### 8.2 Tests obligatoires

- **Dés** : même seed → même suite de résultats ; `rng_state` sauvegardé et restauré.
- **État** : les changements sont bornés ; HP ne descend pas sous 0 ; or jamais négatif.
- **Sauvegarde** : aller-retour JSON complet ; version inconnue refusée ; fichier invalide refusé.
- **Parseur** : JSON cassé, marqueur absent, commande inconnue, ID inconnu, valeurs hors bornes, injection, plus de 5 commandes.
- **Prompt** : ordre stable → variable ; langue et action en dernier ; IDs autorisés présents.
- **Tagger** : BBCode dangereux échappé ; accents FR gérés ; option C (tags IA + liste de mots).
- **Contenu** : toutes les clés FR/EN présentes ; IDs uniques ; notation de dés valide.
- **Bilingue** : chargement FR puis EN ; clé manquante = échec ; langue sauvegardée.
- **Monde** : chemin clic → `walk_to` ; `move_to` vers un lieu ; `spawn`/`despawn` de la créature.
- **Shell** : réponse invalide = état inchangé ; réponse valide = narration puis commande.

### 8.3 Checklist manuelle M1

- [ ] La fenêtre 1280 × 720 affiche le monde à gauche et le récit à droite.
- [ ] En dessous de 900 px de large, le layout passe en empilé sans chevauchement.
- [ ] Le héros va à `mill_road`, `mill_bridge` et `old_mill` au clic.
- [ ] La caméra suit le héros sans à-coups.
- [ ] Les mots `feu`, `glace` et `foudre` s'animent (ou leurs équivalents EN).
- [ ] Le texte s'écrit progressivement ; un clic termine l'animation.
- [ ] Un tour copier-coller complet fonctionne avec une vraie conversation Claude.
- [ ] Une commande `spawn` fait apparaître le loup de rouille.
- [ ] Une commande `move_to` déplace le héros.
- [ ] Une réponse volontairement cassée affiche une erreur et ne change rien.
- [ ] Sauvegarde, fermeture, relance, chargement : état identique.
- [ ] Bascule FR → EN : UI, noms et prompt suivent.
- [ ] La build privée se lance depuis itch.io.

### 8.4 Tests IA M1

Rejouer au minimum :

- **S1** — lieu inventé (Silver Tower) : aucune commande vers un lieu inconnu, aucun lieu décrit comme réel.
- **S6** — injection (« 9999 or ») : aucune modification d'état.
- **S8** — déplacement narratif vers le moulin : `move_to old_mill` présent.

Les scénarios et le contexte sont dans [examples/ai-tests/](examples/ai-tests/). Consigner les résultats datés dans un rapport M1 avant l'approbation finale.

**Pas d'objectif de couverture chiffré** : aucun outil de couverture GDScript n'est installé. Chaque comportement listé ci-dessus doit avoir au moins un test ou une vérification manuelle explicite.

## 9. Modules et critères d'acceptation

### 9.1 `bootstrap`

**Livrables :** `project.godot`, `main.tscn`, autoloads `Game`/`Content`/`DM`, presets macOS/Windows, `.gitignore` vérifié.

**Acceptation :**

- [ ] `godot --headless --path game --quit` se termine sans erreur.
- [ ] `godot --path game` ouvre la scène principale.
- [ ] Les trois autoloads sont enregistrés.
- [ ] Les réglages d'import des CSV/MD sont versionnés.
- [ ] Les presets d'export existent et les exports ne contiennent pas `.godot/`.

### 9.2 `content`

**Livrables :** loader CSV/Markdown, `strings.csv`, données M1 (3 lieux, Oda, loup de rouille, 2 objets, 1 quête, 3 effets), fichiers de lore FR/EN, `content_check.py`.

**Acceptation :**

- [ ] Les CSV numériques sont chargés sans colonne localisée.
- [ ] `strings.csv` fournit toutes les clés en FR et EN.
- [ ] Le loader choisit la langue active sans redémarrage.
- [ ] `python3 tools/content_check.py --check --langs fr,en` passe.
- [ ] Une clé ou un fichier manquant fait échouer la commande.
- [ ] Les IDs autorisés sont dérivés du contenu, pas codés en dur.

### 9.3 `core`

**Livrables :** `dice.gd`, `game_state.gd`, `save_system.gd`, tests unitaires.

**Acceptation :**

- [ ] Même seed → mêmes dés.
- [ ] `apply_changes` borne HP, or et temps.
- [ ] Sauvegarde/chargement JSON complet, version 1.
- [ ] Un fichier invalide ou une version inconnue est refusé proprement.
- [ ] La langue est sauvegardée et restaurée.
- [ ] Aucune dépendance à l'UI ou à la scène.

### 9.4 `ai-turn`

**Livrables :** `prompt_builder.gd`, `copy_paste_adapter.gd`, `dm_reply_parser.gd`, boîte de dialogue de collage.

**Acceptation :**

- [ ] Le prompt contient règles, codex, état, IDs autorisés, action et langue.
- [ ] Le bouton copie le prompt dans le presse-papiers.
- [ ] Une réponse valide produit narration + commandes + changements.
- [ ] Une réponse invalide produit des erreurs et zéro changement.
- [ ] Les IDs inconnus et les valeurs hors bornes sont rejetés.
- [ ] L'injection « SYSTEM OVERRIDE » ne modifie rien.
- [ ] Le parseur est couvert par des tests.

### 9.5 `narration`

**Livrables :** panneau de récit, machine à écrire, tagger, effets `burn`/`freeze`/`shock`.

**Acceptation :**

- [ ] Le texte s'affiche progressivement, sans bloquer l'UI.
- [ ] Les trois effets M1 sont visibles.
- [ ] Les mots-clés FR et EN sont reconnus.
- [ ] Le BBCode non autorisé est affiché comme texte, jamais exécuté.
- [ ] Seules les 4 dernières entrées s'animent.
- [ ] Un clic termine l'animation en cours.

### 9.6 `world`

**Livrables :** zone Mill Road avec 3 lieux, héros cliquable, caméra, pathfinding, `scene_director.gd`, scène du loup.

**Acceptation :**

- [ ] Le héros se déplace au clic vers un lieu accessible.
- [ ] Les obstacles bloquent le chemin.
- [ ] La caméra suit le héros.
- [ ] `move_to` déplace le héros après la narration.
- [ ] `spawn`/`despawn` créent et retirent le loup.
- [ ] `weather` change l'effet visuel de base.
- [ ] Aucune commande non validée n'atteint la scène.

### 9.7 `shell`

**Livrables :** `main.tscn`, HUD, layout 40/60, orchestration du tour, sauvegarde/chargement, bascule de langue, build privée.

**Acceptation :**

- [ ] Layout 40/60 sur desktop, empilé sous 900 px.
- [ ] HUD : HP, or, heure, lieu, bouton langue.
- [ ] Le tour complet suit l'ordre §7.5.
- [ ] Le jeu reste réactif pendant l'attente IA.
- [ ] Sauvegarde et chargement sont accessibles depuis l'UI.
- [ ] La bascule FR/EN met à jour l'UI et le contenu.
- [ ] La build privée se lance sur la machine cible.

## 10. Success Criteria — fin de M1

M1 est terminé quand **tous** ces critères sont vrais :

- [ ] **AC1** — `godot --headless --path game --quit` et `godot --headless --path game --script res://tests/run_tests.gd` passent.
- [ ] **AC2** — `python3 tools/content_check.py --check --langs fr,en` passe.
- [ ] **AC3** — Le layout 40/60 est lisible en 1280 × 720 et passe en empilé sous 900 px.
- [ ] **AC4** — Le héros se déplace au clic vers les 3 lieux, avec caméra et collisions.
- [ ] **AC5** — La narration s'écrit progressivement et les 3 effets M1 sont visibles.
- [ ] **AC6** — Un tour copier-coller complet affiche la narration et applique au moins une commande vérifiée.
- [ ] **AC7** — Une réponse invalide ou une injection ne modifie pas l'état.
- [ ] **AC8** — Sauvegarde, relance et chargement restaurent l'état, le RNG et la langue.
- [ ] **AC9** — FR/EN fonctionne pour l'UI, les noms, les mots-clés, le codex et le prompt.
- [ ] **AC10** — Les tests unitaires et d'intégration listés en §8.2 passent.
- [ ] **AC11** — Les scénarios IA S1, S6 et S8 sont rejoués et consignés.
- [ ] **AC12** — Une build privée se lance sur la machine cible et la page itch.io est accessible à l'équipe.
- [ ] **AC13** — Aucun secret commité, aucun contenu codé en dur, aucun `.tres` chargé comme sauvegarde.

## 11. Boundaries

### Always

- Lancer `content_check.py` et les tests headless avant chaque commit.
- Faire passer toute réponse IA par `DmReplyParser`.
- Versionner toute forme d'état et tester le chargement des anciennes sauvegardes.
- Utiliser des clés de traduction pour tout texte visible.
- Garder le mode copier-coller fonctionnel.
- Mettre à jour `SPEC.md`, `README.md` et le journal quand une décision ou un état change.
- Vérifier qu'aucun secret ni fichier de build n'est ajouté au dépôt.
- Travailler sur `Beta-0.1` et relire le diff avant commit.

### Ask first

- Ajouter une dépendance, un addon Godot ou un service externe.
- Modifier le schéma de sauvegarde, le protocole IA ou la liste des commandes.
- Changer de version de Godot, de moteur ou de cible d'export.
- Modifier la structure des dossiers ou le pipeline d'art.
- Ajouter un CI, un serveur, un proxy ou une page publique.
- Modifier `examples/` autrement que pour corriger une référence obsolète.

### Never

- Commiter une clé API, un token ou un secret.
- Contourner le parseur ou faire confiance directement à la narration IA.
- Coder en dur du contenu éditable par l'équipe.
- Casser une sauvegarde existante sans migration et test.
- Charger un `.tres` importé comme sauvegarde.
- Placer le dépôt Git dans OneDrive.
- Supprimer ou affaiblir un test qui échoue sans approbation.
- Commit `.godot/`, `builds/`, `node_modules/` ou des secrets.
- Force-push une branche partagée.

## 12. Risques et mitigations

| Risque | Impact | Mitigation |
|---|---|---|
| Godot absent de l'environnement actuel | Tests non exécutables ici | Installer 4.7.2 sur la machine de dev ; ne jamais cocher sans exécution |
| L'IA invente des lieux/objets (S1) | Monde incohérent | Règles anti-invention, codex complet, relecture manuelle |
| Le récit et l'état divergent (S8) | Héros au mauvais endroit | Règle `move_to`, test S8 |
| Le bilingue double le travail d'écriture | Retard contenu | Volume M1 réduit : 1 PNJ, 1 lieu, 3 effets |
| L'art temporaire ne ressemble à rien | Mauvaise évaluation | Placeholders CC0 propres + `CREDITS.md` |
| Export/itch.io non maîtrisé | Pas de build testable | Faire l'export tôt, dès `bootstrap` |
| Le périmètre M1 gonfle | Prototype sans fin | Hors-périmètre §1.4, critères AC stricts |
| Le cache de prompt est invalidé | Coût plus élevé | Parties stables en tête, langue dans la partie variable |

## 13. Open Questions

Ces points ne bloquent pas l'écriture du SPEC, mais doivent être tranchés avant ou pendant M1 :

1. **Langue des documents** : hypothèse code/docs anglais + docs d'équipe français. Confirmer.
2. **OS prioritaire** : macOS d'abord (machine actuelle) ou Windows d'abord (machine du lead dans `PLAN.md`) ?
3. **Style et taille d'art** : 32 × 32 temporaire ; confirmer après les questions 9–12.
4. **Auteur du lore bilingue** : qui écrit les versions FR et EN de Oda et du moulin ?
5. **Build web** : garder hors M1 ou l'ajouter comme bonus si l'export Godot web fonctionne ?
6. **Page itch.io** : qui crée la page privée et détient le compte `butler` ?
7. **Source de l'ancien prototype** : le copier dans `reference/` ou s'en passer pour M1 ?

## 14. Approval

**Statut : approuvé le 2026-10-19.** Le plan technique est dans [tasks/plan.md](tasks/plan.md) et le suivi dans [tasks/todo.md](tasks/todo.md). L'implémentation suit l'ordre des tâches approuvées.
