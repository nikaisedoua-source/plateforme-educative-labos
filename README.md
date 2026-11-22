# Labos libres de la plateforme éducative

Copies de logiciels libres, ouvertes dans le Labo de la plateforme. Elles sont servies gratuitement par GitHub Pages,
sans serveur à payer. Chaque dossier contient sa licence (`LICENCE.txt`) et l'origine de son code (`SOURCE.txt`).
Le site est reconstruit par `construire_labos.sh` (avec `labos.py`) à partir des versions figées indiquées.

| Dossier | Logiciel | Auteurs | Licence |
|---|---|---|---|
| `phet/` | Simulations PhET (en français) | PhET Interactive Simulations, université du Colorado Boulder | CC BY 4.0 |
| `circuit/` | CircuitJS | Paul Falstad et contributeurs | GPL-2.0 |
| `optique/` | Ray Optics Simulation | Yi-Ting Tu et contributeurs | Apache-2.0 |
| `logique/` | LogicEmu | Lode Vandevenne | MIT |
| `molecules/` | 3Dmol.js et structures PubChem | université de Pittsburgh ; NIH | BSD-3 ; domaine public |
| `netlogo/` | NetLogo Web et modèles de sa bibliothèque | Uri Wilensky, CCL, Northwestern University | GPL-2.0 ; modèles CC BY-NC-SA 3.0 |
| `snap/` | Snap! 12.4 | Jens Mönig, Bernat Romagosa, université de Berkeley | AGPL-3.0 |
| `python/` | JupyterLite et noyau Pyodide | projet Jupyter ; Pyodide | BSD-3 ; MPL-2.0 |
| `blockly/` | Blockly Games, version sans serveur | Google | Apache-2.0 |
| `musique/` | Music Blocks | Sugar Labs | AGPL-3.0 |

## Retouches

Toutes faites par `construire_labos.sh`. Les fichiers servis sont le code source complet de chaque logiciel, retouches
comprises.

- **CircuitJS** : la ligne d'import Dropbox est retirée, et le cache hors ligne est remplacé par un fichier vide.
- **Ray Optics** : les pages d'accueil des autres langues sont retirées. Le simulateur garde toutes ses traductions.
- **Snap!** :
  - le pisteur Matomo est retiré ;
  - le compte Snap!Cloud est désactivé, et les projets s'enregistrent dans le navigateur ou en fichier ;
  - l'interface est en français ;
  - le manuel au format Word est retiré, le PDF reste.
- **Music Blocks** :
  - « Planet » (partage public des projets sur le serveur de Sugar Labs) est retirée ;
  - l'interface est en français par défaut ;
  - les vidéos, les guides de Turtle Blocks, les sources `.po` et les tests sont retirés.
- **Blockly Games** : c'est la version sans serveur, comme la cible `offline` du Makefile d'origine. La compilation
  utilise le compilateur Closure natif au lieu de Java.
- **NetLogo Web** : la page exportable ne contient ni Google Analytics ni Google Fonts. Un modèle est inséré dans
  chaque page.
- **JupyterLite** : l'interface est en français, sans nouvelles ni vérification de mise à jour. Le cahier
  « Premiers pas en Python » a été écrit pour le site (voir `retouches/python/`).
- **Molécules** : la page `molecules/index.html` a été écrite pour le site (voir `retouches/molecules/`).
