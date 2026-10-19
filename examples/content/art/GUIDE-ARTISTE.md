# Guide pour l'artiste

> Choisi le 19 octobre (questionnaire) : **pixel art, vue de dessus, personnages en 8 directions**,
> images gratuites temporaires en attendant tes dessins. La taille des cases (question 10) reste à choisir.
> Dépose tes fichiers dans le dossier OneDrive `art/`.

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
| 4 | `walk_right` | 4 |
| 5 | `walk_down_right` (diagonale) | 4 |
| 6 | `walk_up_right` (diagonale) | 4 |
| 7 | `attack_down` | 3 |
| 8 | `walk_left` *(facultatif)* | 4 |
| 9 | `walk_down_left` *(facultatif)* | 4 |
| 10 | `walk_up_left` *(facultatif)* | 4 |

- **Lignes 8 à 10 facultatives :** sans elles, le jeu retourne les lignes « right » (effet miroir). Ça fait 3 lignes de moins à dessiner.
- **Pour commencer, 4 directions suffisent** (`walk_down`, `walk_up`, `walk_right`) : en attendant les diagonales, le jeu utilise `walk_right` (ou son miroir).

Dans Aseprite, mets un **tag** par animation avec exactement ces noms.

## Ordre conseillé (pour le prototype)
1. Une planche de cases « forêt + chemin + rivière + pont »
2. Le héros (idle + marche)
3. Un monstre : le loup de rouille
4. Le vieux moulin
5. 5 icônes d'objets

En attendant, le jeu utilise des images gratuites temporaires (par ex. Kenney, licence CC0).
