# Guide pour l'artiste

> Exemple : les tailles et le style seront fixés après les réponses au questionnaire
> (questions 9 à 14). Dépose tes fichiers dans le dossier OneDrive `art/`.

## Format
- **PNG** avec fond transparent. Ou le fichier **Aseprite** (`.aseprite`) si tu utilises Aseprite :
  le jeu peut lire directement tes animations (tags).
- Taille d'une case : **16 × 16** ou **32 × 32** pixels *(à choisir ensemble)*. Tout est dessiné sur cette grille.
- Pas de flou ni d'anticrénelage : du pixel art « net ».

## Noms de fichiers
En minuscules, sans espaces ni accents, avec un préfixe par type :

| Type | Exemple | Contenu |
|---|---|---|
| `tiles-` | `tiles-foret.png` | Une planche de cases (herbe, chemin, eau, arbres…) |
| `hero-` | `hero-rodeur.png` | Le héros, toutes les animations |
| `creature-` | `creature-rust-wolf.png` | Un monstre (même nom que dans monsters.csv) |
| `npc-` | `npc-oda.png` | Un PNJ sur la carte |
| `npc-…-portrait` | `npc-oda-portrait.png` | Un portrait pour le dialogue |
| `item-` | `item-healing-draught.png` | Une icône d'objet (même nom que dans items.csv) |
| `fx-` | `fx-pluie.png` | Effets : pluie, neige, étincelles… |

## Animations des personnages
Une planche par personnage : **une ligne par animation**, toutes les images de la même taille.

| Ligne | Animation | Images |
|---|---|---|
| 1 | `idle_down` (immobile, face) | 2 |
| 2 | `walk_down` | 4 |
| 3 | `walk_up` | 4 |
| 4 | `walk_left` | 4 |
| 5 | `walk_right` *(ou on retourne walk_left, ça fait une ligne de moins)* | 4 |
| 6 | `attack_down` | 3 |

Dans Aseprite, mets un **tag** par animation avec exactement ces noms.

## Ordre conseillé (pour le prototype)
1. Une planche de cases « forêt + chemin + rivière + pont »
2. Le héros (idle + marche)
3. Un monstre : le loup de rouille
4. Le vieux moulin
5. 5 icônes d'objets

En attendant, le jeu utilise des images gratuites temporaires (par ex. Kenney, licence CC0).
