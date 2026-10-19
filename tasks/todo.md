# TODO — Brasswake Reach M1

> Suivi d'implémentation du [plan](plan.md). Cocher uniquement après vérification réelle.
> Branche : `Beta-0.1`. Godot 4.7.2 requis.

## Phase 1 — Une build qui démarre et s'exporte

- [x] **T1 — Bootstrap du projet Godot**
  - Acceptance : projet Godot, scène principale, autoloads `Game`/`Content`/`DM`, runner de tests.
  - Verify : `godot --headless --path game --quit` et `godot --headless --path game --script res://tests/run_tests.gd`.
  - Preuve : Godot 4.7.2, boot exit 0, `PASS: 1 test file(s)`, autoloads `Game`/`Content`/`DM` présents.
- [ ] **T2 — Export smoke et page itch.io privée**
  - Acceptance : export macOS lançable, archive propre, page privée accessible.
  - Verify : export + lancement manuel + téléversement.
  - Preuve : `builds/macos/BrasswakeReach.zip` exporté (57 Mo) et lancé en headless (exit 0). **Page itch.io non créée : action lead en attente.**

## Checkpoint CP1 — Boot + export

- [x] Le projet démarre.
- [x] Le runner passe.
- [ ] Une build privée existe (build locale OK, upload itch.io en attente).
- [ ] Revue humaine.

## Phase 2 — Contenu et état vérifiables sans UI

- [x] **T3 — Content checker + données M1 + chaînes bilingues**
  - Acceptance : checker strict, données M1, `strings.csv` FR/EN, lore squelette.
  - Verify : `python3 tools/content_check.py --check --langs fr,en`.
  - Preuve : `OK: content looks good (fr, en)` ; test négatif avec clé manquante = exit 1.
- [x] **T4 — Lore M1 bilingue + règles du MJ**
  - Acceptance : Oda et le moulin en FR/EN, règles anti-invention et `move_to`.
  - Verify : `content_check.py` + relecture.
  - Preuve : `writing/{fr,en}/{oda,old-mill}.md`, `dm-rules.md` ; checker vert.
- [x] **T5 — Art placeholder 32 × 32 + crédits**
  - Acceptance : tiles, héros, loup, Oda, icônes ; `CREDITS.md`.
  - Verify : import Godot + inspection.
  - Preuve : 6 PNG 32 × 32, tous importés par Godot, `CREDITS.md` CC0.
- [x] **T6 — Content loader + service de localisation**
  - Acceptance : chargement CSV/MD, `Content.t`, `set_language`, `allowed_ids`, tests.
  - Verify : runner + `content_check.py`.
  - Preuve : `PASS: 6 test file(s)`, tests loader + localisation, CSV en Keep File.
- [x] **T7 — Core état, dés seedés, sauvegarde**
  - Acceptance : dés déterministes, état v1, sauvegarde/chargement, tests.
  - Verify : runner.
  - Preuve : tests `dice`, `game_state`, `save_system` verts ; sauvegarde ronde-trip et rejets testés.

## Checkpoint CP2 — Contenu + cœur

- [x] `content_check.py --check --langs fr,en` passe.
- [x] Le runner headless passe.
- [x] Le loader expose les IDs et les deux langues.
- [ ] Revue humaine.

## Phase 3 — Monde et shell visibles

- [x] **T8 — Zone, héros cliquable, caméra**
  - Acceptance : 3 lieux, pathfinding, collisions, caméra.
  - Verify : runner + clic manuel.
  - Preuve : integration test 24×22, 3 marqueurs, chemin vers le pont ; déplacement jusqu'au moulin vérifié (957 frames, distance 7,5 px).
- [x] **T9 — Shell 40/60, HUD, panneau de récit**
  - Acceptance : monde + récit, HUD, texte de debug, 1280 × 720.
  - Verify : lancement manuel + chargement headless.
  - Preuve : capture 1280×720, split 60/40 corrigé (`split_offset` depuis le centre), HUD alimenté par `Game.state`.

## Checkpoint CP3 — Monde + shell

- [x] Le jeu démarre et le héros marche.
- [x] Le HUD affiche les valeurs de l'état.
- [x] Le runner passe.
- [ ] Revue humaine.

## Phase 4 — Le récit s'affiche

- [x] **T10 — KeywordTagger + tests**
  - Acceptance : option C, accents FR/EN, BBCode échappé, tests.
  - Verify : runner.
  - Preuve : test FR/EN, BBCode échappé, tag IA conservé sans double tag.
- [x] **T11 — Panneau de récit, machine à écrire, effets**
  - Acceptance : frappe, clic pour finir, 3 effets, 4 entrées animées, démo.
  - Verify : manuel + test headless.
  - Preuve : capture avec « braise » en orange, frappe progressive, 3 effets installés.

## Checkpoint CP4 — Récit

- [x] La démo affiche les 3 effets.
- [x] Le clic termine la frappe.
- [x] Le runner passe.
- [ ] Revue humaine.

## Phase 5 — Un tour IA complet

- [x] **T12 — Prompt, parseur, adaptateurs + tests**
  - Acceptance : prompt ordonné, parseur robuste, annulation = chaîne vide, tests.
  - Verify : runner + fixtures S1/S6/S8.
  - Preuve : tests prompt/parseur, 11 puis 13 fichiers de tests ; tags, bornes, injection, JSON cassé.
- [x] **T13 — Dialogue de collage + orchestration DM**
  - Acceptance : prompt copié, collage, narration, état appliqué, erreurs sans changement.
  - Verify : `test_turn_flow.gd` + manuel.
  - Preuve : boucle simulée de bout en bout ; dialogue réel câblé ; annulation gérée.
- [x] **T14 — SceneDirector + application des commandes**
  - Acceptance : `move_to`, `spawn`, `despawn`, `weather` ; IDs inconnus sans crash.
  - Verify : runner + manuel avec `spawn rust_wolf` et `move_to old_mill`.
  - Preuve : e2e : loup apparu, héros au moulin, quête étape 1, or -5, autosave.

## Checkpoint CP5 — Boucle IA

- [x] Un tour copier-coller complet fonctionne.
- [x] Une commande déplace le héros ou fait apparaître le loup.
- [x] Une réponse cassée ne change pas l'état.
- [ ] Revue humaine.

## Phase 6 — Garder et traduire

- [x] **T15 — Sauvegarde/chargement UI + autosave**
  - Acceptance : boutons, autosave, état/RNG/langue restaurés, erreurs visibles.
  - Verify : runner + manuel sauvegarde/relance/chargement.
  - Preuve : test UI sauvegarde/chargement (or restauré), autosave après tour.
- [x] **T16 — Bascule FR/EN complète**
  - Acceptance : UI, noms, mots-clés, codex, prompt ; langue persistée ; tests.
  - Verify : runner + manuel FR → EN → FR.
  - Preuve : bouton langue, test FR→EN→FR, textes et prompt qui suivent.

## Checkpoint CP6 — Persistance + langues

- [x] Sauvegarde/chargement complet.
- [x] Bascule FR/EN sans redémarrage.
- [x] Tests headless verts.
- [ ] Revue humaine.

## Phase 7 — Finir et livrer

- [x] **T17 — Responsive, erreurs et statuts**
  - Acceptance : 40/60 en 1280 × 720, empilé < 900 px, indicateur d'attente, erreurs visibles.
  - Verify : manuel aux deux tailles + chargement headless.
  - Preuve : test 800 px (Stack visible) et 1280 px ; capture ; statuts localisés.
- [ ] **T18 — Tests complets + scénarios IA**
  - Acceptance : tests SPEC §8.2, S1/S6/S8, rapport daté, aucun test affaibli.
  - Verify : runner + `content_check.py` + relecture.
  - Preuve : 13 tests verts ; rapport [docs/m1-ai-tests.md](../docs/m1-ai-tests.md). **Partiel : pas de nouvel appel modèle, S1/S8 restent des défauts de narration.**
- [ ] **T19 — Export final, AC et documentation**
  - Acceptance : export testé, build privée, AC1–AC13, README/journal à jour, aucun secret.
  - Verify : export + checklist + `git status`.
  - Preuve : export macOS 57 Mo relancé (exit 0) ; [docs/m1-ac.md](../docs/m1-ac.md). **Partiel : page itch.io non créée.**

## Checkpoint CP7 — Livraison M1

- [ ] AC1–AC13 vérifiés (AC11 et AC12 partiels).
- [ ] Build privée testée (build locale Oui, itch.io non).
- [x] Documentation à jour.
- [ ] Revue humaine finale.
