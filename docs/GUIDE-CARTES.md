# Guide des cartes (pour l'artiste)

> Version Beta-0.3, décidée par le lead le 2 novembre 2026.
> Le monde du jeu est une **grille de grandes cartes carrées** posées côte à côte, comme un échiquier.
> Tu dessines la carte du monde et les lieux importants ; le jeu fabrique tout seul le reste.
> Dépose tes fichiers dans le dossier OneDrive `art/` (le lead les copie dans le jeu).

## Les mots de ce guide

| Mot | Ce que c'est |
|---|---|
| **Carré** | Une grande carte du monde : **64 × 64 cases**. Le héros la traverse en une douzaine de secondes |
| **Case** | Un petit carré de sol dans le jeu : 32 × 32 pixels à l'écran (herbe, eau, arbre…) |
| **Genre** | Le genre de terrain d'un carré : prairie, forêt, collines, route, marais, lac, montagne |
| **Sortie** | Une case du bord d'un carré par laquelle le héros peut partir vers le carré voisin |

## En bref : trois choses à dessiner

1. **La carte du monde** (`world.png`) : **1 pixel = 1 carré**. La couleur du pixel dit le genre du carré.
2. **Les carrés faits à la main** (`squares/*.png`), pour les lieux importants : **64 × 64 pixels, 1 pixel = 1 case**. La couleur du pixel dit quelle case mettre.
3. **Les cases** (`art/tiles-placeholder.png`) : les petites images de 32 × 32 pixels (herbe, chemin, eau, arbre…).

Les deux premiers fichiers sont de **petites images de couleurs**, comme un plan. C'est le jeu qui les transforme en vraie carte avec les images des cases.

## 1. La carte du monde : `maps/world.png`

- **1 pixel = 1 carré.** Une image de 48 × 48 pixels donne un monde de 48 × 48 carrés. **Tu choisis la taille** : le lead veut un monde « très grand ». Au-delà de 1024 × 1024, le jeu préviendra que le chargement peut être lent.
- La **couleur** de chaque pixel donne le **genre** du carré (tableau ci-dessous, fichier `maps/kinds.csv`).
- Le héros ne va **jamais** sur un lac ou une montagne, ni hors de l'image. Les bords de l'image sont donc la fin du monde.
- **Les carrés faits à la main se peignent en magenta** (`#ff00ff`), pour qu'on les voie bien sur la carte.
- Les routes : peins une suite de pixels « route » qui se touchent par les côtés (pas en diagonale). Le jeu dessine un chemin qui relie les carrés de route voisins et les carrés faits à la main.
- Le carré de départ (le chemin du moulin) est au milieu de la carte d'essai, au pixel x = 24, y = 24.

### Les couleurs des genres (`maps/kinds.csv`)

| Genre | Couleur | Le héros peut y aller ? |
|---|---|---|
| `meadow` (prairie) | `#8fd16a` | oui |
| `forest` (forêt) | `#1f6b2e` | oui |
| `hills` (collines) | `#b08a4f` | oui |
| `road` (route) | `#e8c27a` | oui |
| `marsh` (marais) | `#6f8f6a` | oui |
| `lake` (lac) | `#3a7bd5` | non |
| `mountain` (montagne) | `#7a7a7a` | non |
| `handmade` (fait à la main) | `#ff00ff` (magenta) | oui, s'il existe dans `squares.csv` |

Tu peux changer une couleur ou ajouter un genre : c'est une ligne dans `kinds.csv` (`id,colour,passable`). Pour un nouveau genre, préviens le lead : il ajoute son nom en français et en anglais, et en attendant le jeu le dessine comme une prairie.

## 2. Les carrés faits à la main : `maps/squares/*.png`

- **64 × 64 pixels**, pas un de plus ou de moins. **1 pixel = 1 case.**
- Chaque couleur correspond à une case du tableau `maps/tiles.csv` (ci-dessous). Une couleur inconnue sera signalée avec sa position, et le héros ne pourra pas marcher dessus.
- **Nom du fichier** : en minuscules, sans espaces ni accents, avec `-` ou `_` (exemple : `moulin-nord.png`).
- Pour placer un carré dans le monde, il faut une ligne dans `maps/squares.csv` :

  ```
  file,x,y,kind
  mill-road.png,24,24,road
  ```

  `x` et `y` sont la position du pixel magenta sur `world.png` (on compte à partir de 0, depuis le coin en haut à gauche). `kind` est le genre auquel le carré ressemble (il sert pour son nom à l'écran et pour les routes voisines). Le lead peut écrire cette ligne pour toi : dis-lui juste où va le carré.
- Les **lieux nommés** (le vieux moulin, le pont…) sont des points dans un carré. Le lead les place dans `data/locations.csv` (colonnes `square,x,y`) : dis-lui sur quelle case se tient chaque lieu. Le point doit être sur une case où l'on peut marcher.
- Un carré fait à la main n'est jamais recopié dans les sauvegardes : si tu l'améliores plus tard, les parties en cours verront la nouvelle version.

## 3. Les sorties

- Une **case où l'on peut marcher sur le bord** d'un carré est une **sortie** vers le carré voisin de ce côté. Quand le héros s'arrête dessus, le jeu demande au Maître du jeu s'il peut passer.
- **Les coins ne sont jamais des sorties.**
- **Laisse les sorties au milieu des bords : cases 30 à 33** (on compte de 0 à 63). Les carrés fabriqués par le jeu ouvrent exactement ces cases-là, donc les passages se font face. Si ta sortie est ailleurs, ça marche quand même : le héros arrive sur la case la plus proche.
- Partout ailleurs, ferme le bord : arbres, rochers, murs, eau…
- Une sortie qui donne sur un lac, une montagne ou le bord du monde ne mène nulle part : la vérification le signale (un avertissement, pas une erreur).
- Les carrés fabriqués par le jeu ouvrent le milieu de chaque côté qui donne sur un carré où l'on peut aller, et ferment les autres (avec de l'eau face à un lac, des rochers face à une montagne).

## 4. Les couleurs des cases (`maps/tiles.csv`)

| Case | Couleur dans les carrés | On marche dessus ? | Calque | Numéro dans la planche |
|---|---|---|---|---|
| `grass` (herbe) | `#4c9a3c` | oui | sol | 0 |
| `path` (chemin) | `#c8a46a` | oui | sol | 1 |
| `water` (eau) | `#2c6fbf` | non | sol | 2 |
| `tree` (arbre) | `#1d4d24` | non | obstacle | 3 |
| `rock` (rocher) | `#8a8a8a` | non | obstacle | 4 |
| `floor` (plancher) | `#ffd27f` | oui | sol | 5 |
| `wall` (mur) | `#4a3f3a` | non | obstacle | 6 |
| `bridge` (pont) | `#b0682a` | oui | sol | 7 |
| `sand` (sable) | `#e8d49a` | oui | sol | 8 |
| `flowers` (fleurs) | `#e48fc0` | oui | sol | 9 |
| `forest_floor` (sous-bois) | `#5a7d2a` | oui | sol | 10 |
| `dirt` (terre) | `#9a7148` | oui | sol | 11 |
| `mud` (boue) | `#6e5f3a` | oui | sol | 12 |
| `reeds` (roseaux) | `#b5b84a` | non | obstacle | 13 |
| `wheel` (roue du moulin) | `#c9a227` | non | obstacle | 14 |

- **Sol** : la case remplit tout le carré de 32 × 32.
- **Obstacle** : l'image est dessinée **par-dessus** le sol (fond transparent). Le jeu met dessous le sol le plus courant autour. Un obstacle bloque toujours le héros.
- Les cases `grass`, `path`, `water`, `tree`, `rock`, `flowers`, `forest_floor`, `dirt`, `mud` et `reeds` servent à fabriquer les carrés automatiques : garde-les (tu peux changer leur image ou leur couleur).

## 5. La planche des cases : `art/tiles-placeholder.png`

- Des cases de **32 × 32 pixels**, **8 par ligne**. On les numérote à partir de 0 : de gauche à droite, puis la ligne suivante (la 2e ligne commence au numéro 8).
- Le **numéro** de chaque case est la colonne `tileset_index` de `tiles.csv`.
- **Ajouter une case** = dessiner l'image dans une place libre de la planche + ajouter une ligne dans `tiles.csv` (`id,colour,walkable,layer,tileset_index`). Aucun code à changer.
- Les images actuelles sont temporaires (fabriquées par un script). Remplace-les quand tu veux, en gardant la même place. Quand ta propre planche sera prête, dis-le au lead : le nom du fichier est fixé dans le jeu pour l'instant.

## 6. Couleurs exactes : réglages de ton logiciel

Le jeu lit les couleurs **au pixel près**. Une couleur à peine différente (`#4c9a3d` au lieu de `#4c9a3c`) est une couleur inconnue.

- Outil **crayon** de 1 pixel, **sans anticrénelage** (pas de bords adoucis), pas de flou, pas de dégradé.
- Pas de redimensionnement « lissé » : si tu agrandis pour travailler, réduis ensuite en « plus proche voisin ».
- Enregistre en **PNG** normal (pas entrelacé). La transparence est ignorée : peins chaque pixel.
- **Aseprite / LibreSprite** : le mode « Indexé » avec une palette de ces couleurs exactes est idéal.
- **Krita / GIMP** : désactive la conversion de profil de couleur à l'export si on te la propose.
- Astuce : crée une palette avec les couleurs des deux tableaux ci-dessus, et ne peins qu'avec elle.

## 7. Comment on vérifie

Le lead lance cette commande après avoir copié tes fichiers :

```bash
python3 tools/content_check.py --check --langs fr,en
```

Exemples de messages et quoi faire :

| Message | Quoi faire |
|---|---|
| `unknown colour #4c9a3d at (12, 40)` | Le pixel x = 12, y = 40 n'a pas une couleur du tableau : repeins-le |
| `the image is 65 x 64 pixels, it must be 64 x 64` | Recadre l'image à 64 × 64 |
| `pixel (30, 12) is magenta but squares.csv has no hand-made square there` | Ajoute la ligne dans `squares.csv`, ou repeins le pixel |
| `paint pixel (24, 24) of world.png magenta` | Le carré fait à la main n'est pas en magenta sur la carte du monde |
| `4 exit tile(s) on the north edge … face square … (lake)` | Une sortie mène dans un lac : ferme ce bord, ou change le voisin |
| `the marker of 'old_mill' … is on a blocked tile (water)` | Le lieu est posé sur une case bloquée : déplace le lieu ou la case |

## Avant d'envoyer

- [ ] `world.png` : seulement les couleurs du tableau des genres ; les carrés faits à la main en magenta.
- [ ] Chaque carré fait à la main : 64 × 64 pixels, seulement les couleurs du tableau des cases.
- [ ] Les sorties au milieu des bords (cases 30 à 33), aucune dans les coins.
- [ ] Les noms de fichiers en minuscules, sans espaces ni accents.
- [ ] Tu as dit au lead où va chaque nouveau carré (x, y sur la carte du monde) et où sont ses lieux.
