# Plan d'implémentation : Brasswake Reach — tranche M1

> Approuvé le 2026-10-19. Branche : `Beta-0.1`. Spec source : [SPEC.md](../SPEC.md).
> Suivi des tâches : [tasks/todo.md](todo.md).

## 1. Résultat attendu

À la fin de M1, une build desktop privée permet de lancer une zone, déplacer le héros au clic, saisir une action, coller une réponse de MJ IA, lire une narration animée, voir une commande s'appliquer, sauvegarder/recharger, et basculer FR/EN.

Le plan part du [SPEC.md](../SPEC.md) comme spec approuvée. Aucun `tasks/plan.md` ni `tasks/todo.md` n'existait avant ce plan.

## 2. Décisions par défaut

| Sujet | Défaut retenu | Conséquence si changement |
|---|---|---|
| Langue | Code/IDs/commentaires en anglais ; docs d'équipe en français ; jeu bilingue FR/EN | Retouche les tâches contenu et UI |
| OS cible | macOS d'abord, Windows ensuite | Change le preset d'export et T2/T19 |
| Art | Placeholders 32 × 32 px, couleurs plates, licence notée | Change T5/T8 |
| Lore bilingue | Le lead rédige les placeholders depuis les exemples ; le scénariste valide | Peut décaler T4/T18 |
| Build web | Hors M1 | Aucun impact sur ce plan |
| itch.io | Le lead crée la page privée et utilise `butler` | T2/T19 dépendent d'une action humaine |
| Ancien prototype | Non copié ; `examples/` suffit pour M1 | Aucun impact |

**Précondition bloquante :** Godot 4.7.2 et les modèles d'export doivent être installés sur la machine d'implémentation. Godot est absent de l'environnement actuel : les commandes Godot ne pourront pas être exécutées tant qu'il n'est pas installé. Aucune tâche Godot ne sera cochée sans exécution réelle.

## 3. Architecture cible

- **Autoloads** : `Game` (état, dés, sauvegarde), `Content` (CSV/MD, chaînes, langue, IDs autorisés), `DM` (prompt, adaptateur, parseur).
- **Cœur pur** : `core/dice.gd`, `core/game_state.gd`, `core/save_system.gd`, sans UI ni scène.
- **Contenu** : CSV numériques neutres + `strings.csv` bilingue + lore FR/EN + `dm-rules.md`. Pas de traduction Godot.
- **IA** : un seul adaptateur actif en M1 (`CopyPasteAdapter`) derrière `AIAdapter`. Toute réponse passe par `DmReplyParser`.
- **Monde** : `TileMapLayer` sol/obstacles, données custom `walkable`, `AStarGrid2D`, héros clic, caméra, `SceneDirector`.
- **Shell** : `HSplitContainer` 40/60 ; sous 900 px, reparenter les deux panneaux dans un `VSplitContainer`. Le monde reste dans un `SubViewport`.
- **Sauvegardes** : JSON versionné dans `user://saves/`, jamais de `.tres` importé.
- **Tests** : runner GDScript maison (`SceneTree`) + `tools/content_check.py` ; aucun addon.

## 4. Graphe de dépendances

```text
T1 Bootstrap
├─ T2 Export smoke
├─ T3 Content checker + données/strings
│  ├─ T4 Lore FR/EN + dm-rules
│  └─ T5 Art placeholder
│     └─ T6 Loader + localisation
├─ T7 Core état/dés/sauvegarde
│  └─ T9 Shell layout
├─ T6 + T5 → T8 Monde + héros
├─ T9 + T10 → T11 Narration
├─ T6 + T7 → T12 Prompt + parseur
├─ T9 + T12 → T13 Copier-coller + orchestration
├─ T8 + T11 + T13 → T14 SceneDirector + commandes
├─ T7 + T9 + T14 → T15 Sauvegarde/chargement UI
├─ T6 + T9 + T12 + T14 → T16 Bilingue
├─ T9 + T14 + T16 → T17 Responsive/erreurs
├─ T14…T17 → T18 Tests complets + scénarios IA
└─ T2 + T18 → T19 Export final + AC + docs
```

## 5. Contrats et interfaces

### Classes et signatures attendues

- `Dice.new(seed)`, `roll(sides, count, bonus)`, `roll_notation("1d20+5")`, `check(modifier, dc, advantage)` ; expose/restaure `rng.state`.
- `GameState.new_game(seed) -> Dictionary` ; `apply_changes(state, changes)` ; `snapshot(state)`.
- `SaveSystem.save_game(state, slot)`, `load_game(slot)`, `import_save_text(text)`, `migrate(data)`.
- `ContentLoader.load_csv(path)`, `by_id(rows)`, `load_codex(path)`.
- `Content.t(key)`, `Content.set_language("fr"|"en")`, `Content.allowed_ids()`.
- `PromptBuilder.build(state, action, rules, codex, allowed, language) -> Dictionary` ; `to_single_text(prompt) -> String`.
- `DmReplyParser.parse(reply, allowed) -> {narration, commands, state, errors}`.
- `AIAdapter.generate_turn(prompt) -> String` ; `CopyPasteAdapter` copie le prompt et attend le collage.
- `DM.play_turn(action)`, signaux `turn_ready(narration, commands)`, `turn_failed(errors)`, `status_changed(message)`.
- `SceneDirector.run(commands)` ; ne reçoit que des commandes validées.

### Données

- État v1 : `version`, `seed`, `rng_state`, `turn`, `time_minutes`, `location`, `language`, `hero`, `gold`, `pack`, `quests`, `story_summary`, `log`.
- `strings.csv` : `key,fr,en` ; clés UI et contenu.
- Données : `monsters.csv` (`id,level,hp,ac,attack_bonus,damage,xp`), `items.csv` (`id,type,price`), `locations.csv` (`id`), `quests.csv` (`id,max_stage`), `keywords.csv` (`effect,lang,words`).
- IDs autorisés : lieux/créatures/objets/quêtes depuis `Content` ; compétences depuis `state.hero.skills`.
- Réponse IA : narration, `<<STATE>>`, un JSON ; 5 commandes max ; IDs/bornes vérifiés ; langue dans la partie variable du prompt.

### Flux d'un tour

`Act` → `DM.play_turn` → prompt + copie → dialogue de collage → parseur → narration → `SceneDirector` après la frappe → `GameState.apply_changes` → autosave. Toute erreur affiche un statut et laisse l'état intact.

## 6. Tâches

### Phase 1 — Une build qui démarre et s'exporte

#### T1 — Bootstrap du projet Godot

**But :** créer `game/`, la scène principale, les autoloads vides et le runner de tests.

**Acceptation :**
- `project.godot` s'ouvre dans Godot 4.7.x.
- La scène principale se charge et les autoloads `Game`, `Content`, `DM` existent.
- Le runner headless exécute un smoke test et sort avec le code 0.
- `.godot/` et `builds/` restent ignorés.

**Vérification :**
- `godot --headless --path game --quit`
- `godot --headless --path game --script res://tests/run_tests.gd`

**Dépend de :** aucune (Godot installé au préalable).
**Fichiers :** `game/project.godot`, `game/main.tscn`, `game/autoload/{game,content,dm}.gd`, `game/tests/run_tests.gd`, `game/tests/unit/test_smoke.gd`.
**Taille :** M.

#### T2 — Export smoke et page itch.io privée

**But :** prouver tôt que la chaîne d'export et de distribution fonctionne.

**Acceptation :**
- Un preset macOS exporte une archive qui se lance.
- L'archive ne contient ni `.godot/`, ni sources de documentation, ni secrets.
- La page itch.io privée est accessible à l'équipe.
- Le preset Windows est préparé si les modèles sont installés.

**Vérification :**
- `godot --headless --path game --export-release "macOS" builds/macos/BrasswakeReach.zip`
- Lancement manuel de l'archive.
- Téléversement privé par le lead.

**Dépend de :** T1.
**Fichiers :** `game/export_presets.cfg`, éventuellement `tools/export.sh`.
**Taille :** S.
**Note :** action humaine pour la page et `butler` ; ne pas cocher sans build réellement testée.

### Phase 2 — Contenu et état vérifiables sans UI

#### T3 — Content checker + données M1 + chaînes bilingues

**But :** définir le schéma de contenu et le vérifier avant que le jeu le charge.

**Acceptation :**
- Le checker valide colonnes, IDs `[a-z0-9_]+`, dés, doublons, paires de mots-clés FR/EN.
- Les données M1 existent : `rust_wolf`, `rusty_sword`, `healing_draught`, `mill_road`, `mill_bridge`, `old_mill`, `the_silent_mill`.
- `strings.csv` couvre l'UI et les noms en FR et EN.
- Un lore squelette FR/EN suffit pour que `--check` soit vert à ce stade.
- Une clé manquante provoque un code de sortie non nul.

**Vérification :**
- `python3 tools/content_check.py --check --langs fr,en`
- Test négatif avec une clé temporairement supprimée (sans commit).

**Dépend de :** T1.
**Fichiers :** `tools/content_check.py`, `game/content/data/*.csv`, `game/content/i18n/strings.csv`, deux fichiers de lore squelettes `writing/{fr,en}/old-mill.md`.
**Taille :** M (petits fichiers nombreux).

#### T4 — Lore M1 bilingue + règles du MJ

**But :** écrire le contenu minimal réel, éditable par le scénariste.

**Acceptation :**
- Oda et le vieux moulin ont une fiche FR et EN avec les mêmes IDs.
- `dm-rules.md` interdit d'inventer un lieu/PNJ absent et impose `move_to` quand la narration déplace le héros.
- La langue de narration est lue depuis le tour, pas codée en dur.
- `content_check.py` reste vert.

**Vérification :**
- `python3 tools/content_check.py --check --langs fr,en`
- Relecture des deux langues.

**Dépend de :** T3.
**Fichiers :** `game/content/writing/dm-rules.md`, `writing/fr/{oda,old-mill}.md`, `writing/en/{oda,old-mill}.md`.
**Taille :** S.

#### T5 — Art placeholder 32 × 32 + crédits

**But :** avoir des assets visibles sans attendre l'artiste.

**Acceptation :**
- Tiles sol/chemin/eau/arbre, héros 4 directions, loup de rouille, Oda et deux icônes d'objets.
- Import Godot avec filtre nearest.
- `CREDITS.md` liste la source et la licence de chaque fichier.
- Les placeholders sont remplaçables sans changement de code.

**Vérification :**
- Ouverture du projet et inspection visuelle.
- `content_check.py` vérifie la présence des fichiers référencés.

**Dépend de :** T1, T3.
**Fichiers :** `game/content/art/*.png`, `game/content/art/CREDITS.md`.
**Taille :** M.

#### T6 — Content loader + service de localisation

**But :** charger les fichiers de l'équipe et exposer les textes/IDs au jeu.

**Acceptation :**
- Les CSV numériques, `strings.csv` et le lore sont chargés à l'exécution.
- `Content.t(key)` retourne la langue active ; une clé absente retourne la clé et journalise.
- `Content.set_language()` recharge chaînes, mots-clés et codex sans redémarrage.
- `allowed_ids()` ne contient que des IDs présents dans le contenu.
- Tests unitaires du loader et de la localisation.

**Vérification :**
- `godot --headless --path game --script res://tests/run_tests.gd`
- `python3 tools/content_check.py --check --langs fr,en`

**Dépend de :** T3, T4, T5.
**Fichiers :** `game/content/content_loader.gd`, `game/autoload/content.gd`, `game/tests/unit/test_content_loader.gd`, `game/tests/unit/test_localization.gd`, `game/content/README.md`.
**Taille :** M.

#### T7 — Core état, dés seedés, sauvegarde

**But :** poser la vérité du jeu, testable sans UI.

**Acceptation :**
- Même seed → mêmes dés ; `rng_state` sauvegardé/restauré.
- État v1 conforme au SPEC ; `apply_changes` borne HP, or et temps.
- Sauvegarde/chargement JSON complet ; version future ou JSON invalide refusés.
- La langue est sauvegardée/restaurée.
- Tests unitaires des trois modules.

**Vérification :**
- `godot --headless --path game --script res://tests/run_tests.gd`

**Dépend de :** T1.
**Fichiers :** `game/core/{dice,game_state,save_system}.gd`, `game/tests/unit/test_{dice,game_state,save_system}.gd`.
**Taille :** M.

#### Checkpoint CP2 — Contenu + cœur

- [ ] `content_check.py --check --langs fr,en` passe.
- [ ] Le runner headless passe.
- [ ] Le loader expose les IDs et les deux langues.
- [ ] Revue humaine avant l'UI.

### Phase 3 — Monde et shell visibles

#### T8 — Zone, héros cliquable, caméra

**But :** rendre le monde jouable au clic.

**Acceptation :**
- Zone Mill Road avec `mill_road`, `mill_bridge`, `old_mill` comme `Marker2D` du groupe `locations`.
- Le héros se déplace au clic via `WalkGrid`, contourne les obstacles, la caméra suit.
- Les IDs de lieux viennent de `Content`, pas d'une liste en dur.
- Test headless de `WalkGrid` (chemin valide, obstacle, cible inatteignable).

**Vérification :**
- Test runner.
- Lancement manuel et clic vers les trois lieux.

**Dépend de :** T1, T5, T6.
**Fichiers :** `game/world/world.tscn`, `game/world/hero.tscn`, `game/world/movement_click.gd`, `game/world/walk_grid.gd`, `game/tests/unit/test_walk_grid.gd`.
**Taille :** M.

#### T9 — Shell 40/60, HUD, panneau de récit

**But :** avoir le cadre de jeu et les informations de base.

**Acceptation :**
- `main.tscn` instancie le monde dans un `SubViewport` et le récit à droite.
- HUD : HP, or, heure, lieu, bouton langue placeholder, boutons Sauvegarder/Charger placeholder.
- Le panneau de récit affiche un texte de debug.
- Layout lisible en 1280 × 720 ; le comportement < 900 px sera finalisé en T17.

**Vérification :**
- Lancement manuel.
- Test headless de chargement de la scène principale.

**Dépend de :** T1, T6, T7.
**Fichiers :** `game/main.tscn`, `game/ui/hud.tscn`, `game/ui/hud.gd`, `game/ui/story_panel.tscn`, `game/main.gd`.
**Taille :** M.

#### Checkpoint CP3 — Monde + shell

- [ ] Le jeu démarre et le héros marche.
- [ ] Le HUD affiche les valeurs de l'état.
- [ ] Le runner passe.
- [ ] Revue humaine avant la narration.

### Phase 4 — Le récit s'affiche

#### T10 — KeywordTagger + tests

**But :** transformer la narration en BBCode sûr et coloré.

**Acceptation :**
- Option C : tags IA valides conservés, puis mots-clés de `keywords.csv`.
- Accents FR et mots EN reconnus.
- BBCode non autorisé échappé.
- Tests unitaires (feu/glace/foudre, injection BBCode, mots hors contexte).

**Vérification :**
- Test runner.

**Dépend de :** T6.
**Fichiers :** `game/narration/keyword_tagger.gd`, `game/tests/unit/test_keyword_tagger.gd`.
**Taille :** S.

#### T11 — Panneau de récit, machine à écrire, effets

**But :** rendre la lecture agréable et animée.

**Acceptation :**
- Frappe progressive, clic pour terminer.
- Effets `burn`, `freeze`, `shock` installés.
- Seules les 4 dernières entrées s'animent.
- Intégration dans `story_panel.tscn` avec un bouton de démo.
- Aucun BBCode dangereux exécuté.

**Vérification :**
- Lancement manuel de la démo.
- Test headless du panneau (frappe terminée après un temps simulé si possible).

**Dépend de :** T9, T10.
**Fichiers :** `game/narration/narration_panel.gd`, `game/narration/effects/{burn,freeze,shock}_effect.gd`, `game/ui/story_panel.tscn`, `game/main.gd`.
**Taille :** M.

#### Checkpoint CP4 — Récit

- [ ] La démo affiche un texte avec les 3 effets.
- [ ] Le clic termine la frappe.
- [ ] Le runner passe.
- [ ] Revue humaine avant l'IA.

### Phase 5 — Un tour IA complet

#### T12 — Prompt, parseur, adaptateurs + tests

**But :** préparer et vérifier la réponse IA avant toute action.

**Acceptation :**
- Prompt ordonné règles → codex → résumé → état → IDs → action+langue.
- Parseur : JSON cassé, marqueur absent, commande/ID inconnus, bornes, injection, > 5 commandes.
- Une réponse invalide produit `errors` et zéro changement.
- `CopyPasteAdapter` copie le prompt et attend le collage ; annulation = chaîne vide.
- Tests unitaires complets.

**Vérification :**
- Test runner.
- Revue des fixtures de réponse (S1, S6, S8).

**Dépend de :** T6, T7.
**Fichiers :** `game/ai/{ai_adapter,copy_paste_adapter,prompt_builder,dm_reply_parser}.gd`, `game/tests/unit/test_{prompt_builder,dm_reply_parser}.gd`, `game/tests/fixtures/replies/*.txt`.
**Taille :** M.

#### T13 — Dialogue de collage + orchestration DM

**But :** jouer un tour jusqu'à la narration, sans encore appliquer les commandes de scène.

**Acceptation :**
- Le bouton Agir construit le prompt et copie le texte.
- Le dialogue permet de coller, valider ou annuler.
- Une réponse valide affiche la narration ; les changements d'état sont appliqués après la frappe.
- Une réponse invalide affiche les erreurs et laisse l'état intact.
- L'input est verrouillé pendant le tour.
- Si le presse-papiers échoue, le prompt reste sélectionnable dans le dialogue.

**Vérification :**
- Test d'intégration `test_turn_flow.gd`.
- Test manuel avec une réponse collée à la main.

**Dépend de :** T9, T12.
**Fichiers :** `game/autoload/dm.gd`, `game/ui/paste_dialog.tscn`, `game/ui/paste_dialog.gd`, `game/main.gd`, `game/tests/integration/test_turn_flow.gd`.
**Taille :** M.

#### T14 — SceneDirector + application des commandes

**But :** faire obéir le monde aux commandes déjà validées.

**Acceptation :**
- `move_to`, `spawn`, `despawn`, `weather` ont un effet visible après la narration.
- `emote` et `request_roll` sont journalisés sans animation/résolution.
- Un ID sans scène ou sans marqueur produit un avertissement, pas un crash.
- Une commande non validée n'atteint jamais la scène.
- Test d'intégration du tour complet.

**Vérification :**
- Test runner.
- Manuel : une réponse avec `spawn rust_wolf` fait apparaître le loup ; `move_to old_mill` déplace le héros.

**Dépend de :** T8, T11, T13.
**Fichiers :** `game/world/scene_director.gd`, `game/main.gd`, `game/tests/integration/test_turn_commands.gd`.
**Taille :** M.

#### Checkpoint CP5 — Boucle IA

- [ ] Un tour copier-coller complet fonctionne.
- [ ] Une commande déplace le héros ou fait apparaître le loup.
- [ ] Une réponse cassée ne change pas l'état.
- [ ] Revue humaine avant la persistance.

### Phase 6 — Garder et traduire

#### T15 — Sauvegarde/chargement UI + autosave

**But :** retrouver une partie après fermeture.

**Acceptation :**
- Boutons Sauvegarder/Charger dans le HUD.
- Autosave après chaque tour réussi.
- Rechargement : état, RNG et langue identiques.
- Erreur de sauvegarde affichée sans crash.
- Test d'aller-retour et test d'un fichier invalide.

**Vérification :**
- Test runner.
- Manuel : jouer, sauvegarder, quitter, relancer, charger.

**Dépend de :** T7, T9, T14.
**Fichiers :** `game/autoload/game.gd`, `game/ui/hud.tscn`, `game/ui/hud.gd`, `game/main.gd`, `game/tests/integration/test_save_flow.gd`.
**Taille :** M.

#### T16 — Bascule FR/EN complète

**But :** jouer dans les deux langues sans redémarrer.

**Acceptation :**
- Bouton langue dans le HUD.
- UI, noms, mots-clés, codex et prompt suivant la langue.
- Langue sauvegardée/restaurée.
- Aucune clé manquante ; `content_check` reste vert.
- Test d'intégration FR → EN → FR.

**Vérification :**
- Test runner.
- Manuel : basculer, agir, vérifier le prompt et la narration.

**Dépend de :** T6, T9, T12, T14.
**Fichiers :** `game/autoload/content.gd`, `game/ui/hud.gd`, `game/main.gd`, `game/ai/prompt_builder.gd`, `game/tests/integration/test_bilingual.gd`.
**Taille :** M.

#### Checkpoint CP6 — Persistance + langues

- [ ] Sauvegarde/chargement complet.
- [ ] Bascule FR/EN sans redémarrage.
- [ ] Tests headless verts.
- [ ] Revue humaine avant la finition.

### Phase 7 — Finir et livrer

#### T17 — Responsive, erreurs et statuts

**But :** rendre la build présentable et robuste.

**Acceptation :**
- 40/60 en 1280 × 720 ; empilé sous 900 px, sans chevauchement.
- Indicateur d'attente IA et barre de statut.
- Erreurs de parseur, de sauvegarde et de contenu visibles.
- Aucun texte d'UI codé en dur.

**Vérification :**
- Manuel aux deux tailles.
- Test headless de chargement de la scène.

**Dépend de :** T9, T14, T16.
**Fichiers :** `game/main.tscn`, `game/main.gd`, `game/ui/hud.tscn`, `game/ui/story_panel.tscn`.
**Taille :** M.

#### T18 — Tests complets + scénarios IA

**But :** prouver les critères du SPEC.

**Acceptation :**
- Tests unitaires et d'intégration listés en SPEC §8.2 passent.
- Scénarios S1, S6, S8 rejoués avec le vrai prompt.
- Rapport daté `docs/m1-ai-tests.md` avec réponses, verdicts et limites.
- Aucun test supprimé ou affaibli.

**Vérification :**
- `godot --headless --path game --script res://tests/run_tests.gd`
- `python3 tools/content_check.py --check --langs fr,en`
- Relecture du rapport IA.

**Dépend de :** T14, T15, T16, T17.
**Fichiers :** `game/tests/**`, `docs/m1-ai-tests.md`.
**Taille :** M.

#### T19 — Export final, AC et documentation

**But :** fermer M1 avec une build privée et un suivi à jour.

**Acceptation :**
- Export macOS (et Windows si disponible) lancé et testé.
- Build privée accessible sur itch.io.
- AC1–AC13 du SPEC vérifiés un par un.
- README, journal et cases cochées mis à jour.
- Aucun secret, `.godot/` ou `builds/` commité.

**Vérification :**
- Export + lancement manuel.
- Checklist AC1–AC13.
- `git status --short`.

**Dépend de :** T2, T18.
**Fichiers :** `game/export_presets.cfg`, `README.md`, `SPEC.md` (si une décision change), `docs/m1-ai-tests.md`.
**Taille :** M.

## 7. Checkpoints et commandes de vérification

À chaque checkpoint :

```bash
godot --headless --path game --quit
godot --headless --path game --script res://tests/run_tests.gd
python3 tools/content_check.py --check --langs fr,en
```

- **CP1** après T1–T2 : le projet démarre, une build privée existe.
- **CP2** après T3–T7 : contenu et cœur testables.
- **CP3** après T8–T9 : monde visible et shell.
- **CP4** après T10–T11 : récit animé.
- **CP5** après T12–T14 : un tour IA complet.
- **CP6** après T15–T16 : sauvegarde et bilingue.
- **CP7** après T17–T19 : AC et build finale.

Chaque checkpoint exige une **revue humaine** avant de continuer.

## 8. Parallélisation

- **Parallélisable :** T3 et T7 après T1 ; T4 et T5 après T3 ; T8 et T9 après T6/T7 ; T10 et T12 ; T15 et T16 après T14.
- **Séquentiel obligatoire :** T1 → T2 ; T12 → T13 → T14 ; T14 → T15/T16 ; T18 → T19.
- **Coordination :** le contrat de `Content.allowed_ids()` et le format de prompt doivent être figés avant de paralléliser T8 et T12.

## 9. Risques et mitigations

| Risque | Tâches | Mitigation |
|---|---|---|
| Godot ou modèles d'export absents | T1/T2 | Installer 4.7.2 + templates avant de commencer ; ne pas cocher sans exécution |
| Export/itch.io découvert trop tard | T2/T19 | Smoke build dès la phase 1 |
| Contenu bilingue incomplet | T3/T4/T16 | Checker strict, petit volume M1, revue du scénariste |
| UI 40/60 difficile à reparenter | T9/T17 | Tester tôt 1280/900 ; garder les panneaux indépendants |
| Presse-papiers indisponible | T13 | Prompt affiché et sélectionnable en secours |
| IA qui invente ou dérive | T12/T18 | Règles, codex complet, parseur, S1/S6/S8 |
| IDs de lieux incohérents scène/contenu | T8 | IDs depuis `Content`, avertissement si marqueur absent |
| Sauvegarde/RNG divergent | T15 | Tests de round-trip et fichier invalide |
| Périmètre qui gonfle | Toutes | Hors-périmètre SPEC §1.4, AC stricts |

## 10. Traçabilité des critères

| AC | Tâches |
|---|---|
| AC1 commandes headless | T1, T18 |
| AC2 contenu FR/EN | T3, T4, T6, T18 |
| AC3 layout | T9, T17 |
| AC4 déplacement | T8 |
| AC5 narration/effets | T10, T11 |
| AC6 tour IA | T13, T14 |
| AC7 réponse invalide | T12, T13 |
| AC8 sauvegarde/RNG | T7, T15 |
| AC9 bilingue | T6, T16 |
| AC10 tests | T18 |
| AC11 scénarios IA | T18 |
| AC12 build privée | T2, T19 |
| AC13 secrets/contenu en dur | T19 |

## 11. Règles d'exécution

- Travailler sur `Beta-0.1`, une tâche à la fois, en cochant après vérification réelle.
- Committer aux checkpoints ; pas de push forcé, pas de commit de `.godot/`, `builds/` ou secrets.
- Si Godot n'est pas disponible, s'arrêter à T1 et le signaler ; ne jamais simuler un test.
- Toute décision qui change le SPEC ou les contrats doit être reportée dans `SPEC.md` avant le code.
- Mettre à jour README et journal à chaque checkpoint.
