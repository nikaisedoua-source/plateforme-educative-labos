#!/usr/bin/env bash
# Construit le site des labos (copies de logiciels libres) dans $LABOS/site, publié ensuite par publier_labos.sh
# sur https://nikaisedoua-source.github.io/plateforme-educative-labos/ (même adresse que le site : l'élève ne
# quitte jamais la plateforme, et rien n'est à payer).
# Décision utilisateur 2026-11-22 : « tout doit se passer sur mon site sans encaisser de frais d'hébergement »,
# « applique tous ceux qui respectent mes règles […] mais tout doit fonctionner normalement ».
# Usage : construire_labos.sh [phet] [circuit] [optique] [logique] [molecules] [netlogo] [scratch] [snap]
#         [python] [blockly] [musique]      (sans argument : tous)
# Chaque labo garde sa licence (fichier LICENCE.txt dans son dossier) et indique d'où vient son code.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HERE="$ROOT/backend/deploiement/labos"
LABOS="${LABOS_CACHE:-$HOME/.cache/plateforme-educative/labos}"
SITE="$LABOS/site"
SRC="$LABOS/src"
mkdir -p "$SITE" "$SRC"
PY="${PYTHON:-python3}"

# Clone (ou met à jour) un dépôt à une version figée : clone_at <dossier> <url> <révision>
clone_at() {
  if [ ! -d "$SRC/$1/.git" ]; then git clone -q --filter=blob:none "$2" "$SRC/$1"; fi
  git -C "$SRC/$1" fetch -q origin "$3" 2>/dev/null || git -C "$SRC/$1" fetch -q origin
  git -C "$SRC/$1" checkout -q --force "$3"
}

licence() { cp "$1" "$SITE/$2/LICENCE.txt"; printf '%s\n' "$3" > "$SITE/$2/SOURCE.txt"; }

phet() {
  # Simulations PhET (université du Colorado Boulder, CC BY 4.0) : un fichier HTML autonome par simulation,
  # en français quand la traduction existe, sinon en anglais.
  mkdir -p "$SITE/phet"
  local slug ok=0 en=0
  for slug in $("$PY" "$HERE/labos.py" phet-slugs); do
    [ -s "$SITE/phet/$slug.html" ] && { ok=$((ok + 1)); continue; }
    if curl -sfL -m 300 -o "$SITE/phet/$slug.html.part" "https://phet.colorado.edu/sims/html/$slug/latest/${slug}_fr.html"; then
      ok=$((ok + 1))
    else
      curl -sfL -m 300 -o "$SITE/phet/$slug.html.part" "https://phet.colorado.edu/sims/html/$slug/latest/${slug}_en.html"
      en=$((en + 1)); echo "  $slug : pas de traduction française, version anglaise"
    fi
    mv "$SITE/phet/$slug.html.part" "$SITE/phet/$slug.html"
  done
  printf 'PhET Interactive Simulations, University of Colorado Boulder — https://phet.colorado.edu\nLicence CC BY 4.0 : https://creativecommons.org/licenses/by/4.0/\n' > "$SITE/phet/LICENCE.txt"
  echo "PhET : $ok simulations en français, $en en anglais"
}

circuit() {
  # CircuitJS (Paul Falstad et contributeurs, GPL-2.0) : circuits électriques animés, interface en français.
  clone_at circuitjs1 https://github.com/pfalstad/circuitjs1.git 8ac55f22a03606579b822b3dccd4dc10de1ddc5b
  (cd "$SRC/circuitjs1/ts" && npm ci --no-audit --no-fund --loglevel=error && npm run build >/dev/null)
  rm -rf "$SITE/circuit" && cp -R "$SRC/circuitjs1/ts/dist" "$SITE/circuit"
  # Pas de stockage Dropbox ni d'autre service extérieur : le circuit s'enregistre dans le navigateur ou en fichier.
  find "$SITE/circuit" -name '*.html' -exec sed -i '' '/dropbox\.com/d' {} +
  # L'appli enregistre service-worker.js (cache hors ligne de dist.sh) : version vide, sans cache, toujours à jour.
  printf '// Pas de cache hors ligne : la page est toujours servie à jour.\n' > "$SITE/circuit/service-worker.js"
  licence "$SRC/circuitjs1/COPYING.txt" circuit "https://github.com/pfalstad/circuitjs1 (8ac55f2)"
  echo "CircuitJS : $(ls "$SITE/circuit" | tr '\n' ' ')"
}

optique() {
  # Ray Optics Simulation (Yi-Ting Tu et contributeurs, Apache-2.0) : version publiée, en français seulement.
  clone_at ray-optics https://github.com/ricktu288/ray-optics.git fb22782606f90119c2529180c8183b194fbd00b7
  rm -rf "$SITE/optique" && mkdir -p "$SITE/optique"
  rsync -a --exclude .git --exclude '*.map' "$SRC/ray-optics/" "$SITE/optique/"
  # Pages d'accueil et galeries des autres langues retirées (le simulateur garde toutes ses traductions).
  (cd "$SITE/optique" && for d in */; do
    d="${d%/}"; case "$d" in fr|docs|gallery|img|locales|modules|simulator|thirdparty) ;;
      *) [[ "$d" =~ ^[a-z]{2}(-[A-Z]{2})?$ ]] && rm -rf "$d" ;; esac; done)
  licence "$SRC/ray-optics/LICENSE" optique "https://github.com/ricktu288/ray-optics (branche gh-pages, fb22782)"
  echo "Ray Optics : $(du -sh "$SITE/optique" | cut -f1)"
}

logique() {
  # LogicEmu (Lode Vandevenne, MIT) : portes logiques et circuits numériques, sans construction.
  clone_at logicemu https://github.com/lvandeve/logicemu.git 56bd1cae5ee0a83d4f587cd053d680f66f1be3df
  rm -rf "$SITE/logique" && mkdir -p "$SITE/logique"
  rsync -a --exclude .git --exclude 'screenshot*' "$SRC/logicemu/" "$SITE/logique/"
  licence "$SRC/logicemu/LICENSE" logique "https://github.com/lvandeve/logicemu (56bd1ca)"
}

molecules() {
  # Page « Molécules en 3D » écrite pour le site, avec 3Dmol.js (université de Pittsburgh, BSD-3) et les structures 3D
  # de PubChem (NIH, domaine public), téléchargées une fois et servies par le site.
  local O="$SITE/molecules" T="$SRC/3dmol" cid n=0 manque=""
  mkdir -p "$T" && (cd "$T" && [ -f package.json ] || echo '{"private":true}' > package.json
    npm install --no-audit --no-fund --loglevel=error --save-exact 3dmol@2.5.4)
  mkdir -p "$O/data"
  cp "$HERE/molecules/index.html" "$O/index.html"
  cp "$T/node_modules/3dmol/build/3Dmol-min.js" "$O/3Dmol-min.js"
  "$PY" "$HERE/labos.py" molecules-liste > "$O/molecules.json"
  for cid in $("$PY" -c 'import json,sys; print(" ".join(str(m["cid"]) for m in json.load(open(sys.argv[1]))))' "$O/molecules.json"); do
    [ -s "$O/data/$cid.sdf" ] && { n=$((n + 1)); continue; }
    if curl -sfL -m 60 -o "$O/data/$cid.sdf" \
        "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/$cid/SDF?record_type=3d"; then n=$((n + 1))
    else rm -f "$O/data/$cid.sdf"; manque="$manque $cid"; fi
    sleep 0.25  # PubChem demande au plus 5 requêtes par seconde
  done
  [ -z "$manque" ] || { echo "Molécules sans structure 3D PubChem :$manque" >&2; return 1; }
  cp "$T/node_modules/3dmol/LICENSE" "$O/LICENCE.txt"
  printf '%s\n' "3Dmol.js 2.5.4 (BSD-3) : https://github.com/3dmol/3Dmol.js" \
    "Structures 3D : PubChem (NIH), domaine public — https://pubchem.ncbi.nlm.nih.gov" > "$O/SOURCE.txt"
  echo "Molécules : $n structures"
}

netlogo() {
  # NetLogo Web (Uri Wilensky, CCL Northwestern, GPL-2.0) : la page exportable « standalone » de netlogoweb.org,
  # gardée en cache (version notée dans SOURCE.txt), avec un modèle de la bibliothèque officielle inséré dans chaque
  # page. Modèles : CC BY-NC-SA 3.0 (usage non commercial, attribution, partage à l'identique).
  local O="$SITE/netlogo" T="$SRC/netlogo"
  mkdir -p "$T"
  [ -s "$T/standalone.html" ] || curl -sfL -m 120 -o "$T/standalone.html" https://www.netlogoweb.org/standalone
  [ -d "$SRC/netlogo-models/.git" ] || { git clone -q --filter=blob:none --sparse https://github.com/NetLogo/models.git "$SRC/netlogo-models"
    git -C "$SRC/netlogo-models" sparse-checkout set "Sample Models/Biology" "Sample Models/Chemistry & Physics" "Sample Models/Earth Science"; }
  git -C "$SRC/netlogo-models" checkout -q --force 1f05439b199f5abc8659e138f2815f50ad70dc40
  rm -rf "$O" && mkdir -p "$O"
  "$PY" "$HERE/labos.py" netlogo "$T/standalone.html" "$SRC/netlogo-models" "$O"
  printf '%s\n' "NetLogo Web (GPL-2.0) : https://github.com/NetLogo/Galapagos — page exportable de netlogoweb.org, version $(grep -o 'nlwCommit = "[0-9a-f]*"' "$T/standalone.html" | cut -d'"' -f2)" \
    "Modèles : bibliothèque NetLogo (Uri Wilensky, Northwestern University), CC BY-NC-SA 3.0 — https://github.com/NetLogo/models (1f05439)" \
    "Licence des modèles : https://creativecommons.org/licenses/by-nc-sa/3.0/deed.fr" > "$O/SOURCE.txt"
  cp "$O/SOURCE.txt" "$O/LICENCE.txt"
  echo "NetLogo : $(du -sh "$O" | cut -f1)"
}

scratch() {
  # Mis de côté : TurboWarp refuse de s'afficher dans un cadre (« Invalid TurboWarp Embed ») ; non construit par
  # défaut (construire_labos.sh scratch pour essayer).
  # TurboWarp (Scratch modifié, GPL-3.0 ; Scratch : MIT Scratch Foundation) : l'éditeur Scratch complet, en français.
  clone_at scratch-gui https://github.com/TurboWarp/scratch-gui.git 4d8323f77ad68f137a5af87254ff3cab4b68dc7c
  (cd "$SRC/scratch-gui" && npm ci --no-audit --no-fund --loglevel=error \
    && NODE_ENV=production NODE_OPTIONS="${NODE_OPTIONS:-} --openssl-legacy-provider" npm run build >/dev/null)
  rm -rf "$SITE/scratch" && mkdir -p "$SITE/scratch"
  rsync -a --exclude '*.map' "$SRC/scratch-gui/build/" "$SITE/scratch/"
  licence "$SRC/scratch-gui/LICENSE" scratch "https://github.com/TurboWarp/scratch-gui (4d8323f)"
  echo "Scratch (TurboWarp) : $(du -sh "$SITE/scratch" | cut -f1)"
}

snap() {
  # Snap! 12.4 (Jens Mönig, Bernat Romagosa et université de Berkeley, AGPL-3.0) : aucune construction, en français.
  clone_at snap https://github.com/jmoenig/Snap.git v12.4.0
  rm -rf "$SITE/snap" && mkdir -p "$SITE/snap"
  rsync -a --exclude .git --exclude .github --exclude '*.md' --exclude 'SnapManual.docx' "$SRC/snap/" "$SITE/snap/"
  # Ni pisteur Matomo ni compte « Snap!Cloud » (service extérieur) : projets enregistrés dans le navigateur ou en
  # fichier ; interface en français par défaut.
  perl -0pi -e 's{\s*// This is a locally managed Matomo instance\..*?\}\)\(\);}{}s; s{new IDE_Morph\(\)\.openIn\(world\);}{var ide = new IDE_Morph({lang: "fr"});\n                ide.cloud.disable();\n                ide.openIn(world);}' "$SITE/snap/snap.html"
  grep -q "ide.cloud.disable" "$SITE/snap/snap.html" && ! grep -q matomo "$SITE/snap/snap.html"
  licence "$SRC/snap/LICENSE" snap "https://github.com/jmoenig/Snap (v12.4.0)"
  echo "Snap! : $(du -sh "$SITE/snap" | cut -f1)"
}

python() {
  # JupyterLite (projet Jupyter, BSD-3) : cahiers Python dans le navigateur, interface en français, avec un premier
  # cahier d'exercices. Le noyau Pyodide (MPL-2.0) se charge depuis le CDN public jsDelivr, gratuit : l'élève reste ici.
  local V="$SRC/jlite" P="$SRC/jlite-projet"
  [ -x "$V/bin/jupyter" ] || { "$PY" -m venv "$V" && "$V/bin/pip" -q install "jupyterlite-core==0.8.6" \
    "jupyterlite-pyodide-kernel==0.8.6" "jupyterlab-language-pack-fr-FR==4.5.post3" "jupyter-server==2.21.1" "jupyterlab-server==2.28.1"; }
  rm -rf "$P" && mkdir -p "$P"
  rsync -a --exclude '._*' --exclude '.DS_Store' "$HERE/python/" "$P/"
  (cd "$P" && "$V/bin/jupyter" lite build >"$P/construction.log" 2>&1) \
    || { tail -5 "$P/construction.log"; echo "JupyterLite : échec de la construction" >&2; return 1; }
  rm -rf "$SITE/python" && cp -R "$P/_output" "$SITE/python"
  find "$SITE/python" -name '*.map' -delete
  rm -f "$SITE/python"/rspack.config*.js
  curl -sfL -m 60 -o "$SITE/python/LICENCE.txt" https://raw.githubusercontent.com/jupyterlite/jupyterlite/main/LICENSE
  printf '%s\n' "https://github.com/jupyterlite/jupyterlite (jupyterlite-core 0.8.6, noyau Pyodide 0.8.6)" > "$SITE/python/SOURCE.txt"
  echo "JupyterLite : $(du -sh "$SITE/python" | cut -f1)"
}

musique() {
  # Music Blocks (Sugar Labs, AGPL-3.0) : programmer de la musique avec des blocs, sans construction.
  # Retirés : la « Planet » (partage public des projets sur le serveur de Sugar Labs), les guides du mode Turtle Blocks,
  # les vidéos de démonstration, les sources de traduction (.po, déjà compilées dans locales/) et les tests.
  local M="$SITE/musique"
  clone_at musicblocks https://github.com/sugarlabs/musicblocks.git 24ca26029e21ece48d3d0857f06aa41d548165d0
  rm -rf "$M" && mkdir -p "$M"
  rsync -a --exclude .git --exclude .github --exclude '*.md' --exclude planet --exclude TurtleDocs --exclude videos \
    --exclude po --exclude screenshots --exclude test --exclude cypress --exclude '__tests__' --exclude scripts \
    --exclude node_modules --exclude 'loading-animation.mp4' "$SRC/musicblocks/" "$M/"
  (cd "$M" && rm -f ./*.config.js ./*.config.mjs ./gulpfile.* ./dockerfile ./setup.py ./convert_po_to_json.py \
     ./generate_pdf.js ./electron-main.js ./index.js ./jest.* ./lighthouserc.js ./renovate.json ./package*.json)
  perl -0pi -e 's{this\.planet = new PlanetInterface\(this\);}{throw new Error("Planet retirée : projets gardés dans le navigateur ou en fichier");}' "$M/js/activity.js"
  perl -0pi -e 's{src="planet/index\.html"}{src="about:blank"}' "$M/index.html"
  # Français par défaut quand l'élève n'a pas encore choisi de langue (menu Langue toujours disponible).
  perl -0pi -e 's{lang = navigator\.language;}{lang = "fr";}' "$M/js/activity.js"
  perl -0pi -e 's{let lang = navigator\.language;}{let lang = "fr";}' "$M/index.html"
  grep -q 'Planet retirée' "$M/js/activity.js" && grep -q 'src="about:blank"' "$M/index.html" \
    && grep -q 'lang = "fr";' "$M/js/activity.js" && grep -q 'let lang = "fr";' "$M/index.html"
  licence "$SRC/musicblocks/COPYING" musique "https://github.com/sugarlabs/musicblocks (24ca260)"
  echo "Music Blocks : $(du -sh "$M" | cut -f1)"
}

blockly() {
  # Blockly Games (Google, Apache-2.0) : puzzle, labyrinthe, oiseau, tortue, film, musique, étang — version « .html »
  # sans serveur (la galerie et les comptes sont retirés, comme dans la cible « offline » du Makefile d'origine).
  # Le Makefile veut svn (fermé par GitHub), wget et Java : remplacés par git, npm et le compilateur Closure natif.
  local B="$SRC/blockly-games" T="$SRC/blockly-outils" game
  clone_at blockly-games https://github.com/google/blockly-games.git 5d2ff6f39207f7ed31e3d11ba1de277c85efe4c2
  clone_at blockly-for-BG https://github.com/NeilFraser/blockly-for-BG.git 837051b5466457a8f4e956b95bff334d95c26b85
  clone_at SoundJS https://github.com/CreateJS/SoundJS.git 5213ac5696142bcba216ef10bef3105e5be1d4ef
  clone_at JS-Interpreter https://github.com/NeilFraser/JS-Interpreter.git 9c31dcb6bbd210feee8f505b32f9a957eada2c3b
  mkdir -p "$T/bin"
  (cd "$T" && [ -f package.json ] || echo '{"private":true}' > package.json
   npm install --no-audit --no-fund --loglevel=error --save-exact \
     google-closure-compiler-macos@20240317.0.0 ace-builds@1.34.2 @babel/standalone@7.14.8)
  # « java -jar closure-compiler.jar … » appelle le compilateur natif (mêmes options, sans machine Java).
  printf '#!/bin/sh\nshift 2\nexec "%s" "$@"\n' "$T/node_modules/google-closure-compiler-macos/compiler" > "$T/bin/java"
  chmod +x "$T/bin/java"
  # Les scripts de Closure appellent « python » : c’est python3 ici.
  ln -sf "$(command -v "$PY")" "$T/bin/python"
  local TP="$B/appengine/third-party"
  rm -rf "$TP" && mkdir -p "$TP/blockly" "$TP/SoundJS" "$TP/JS-Interpreter" "$TP/ace"
  cp "$T/node_modules/@babel/standalone/babel.min.js" "$TP/"
  cp "$T/node_modules/ace-builds/src-min-noconflict/"{ace.js,mode-javascript.js,theme-chrome.js,worker-javascript.js} "$TP/ace/"
  rsync -a --exclude .git "$SRC/blockly-for-BG/" "$TP/blockly/"
  rsync -a "$SRC/SoundJS/lib/" "$TP/SoundJS/"
  rsync -a --exclude .git "$SRC/JS-Interpreter/" "$TP/JS-Interpreter/"
  cp "$B/third-party/base.js" "$TP/" && cp -R "$B/third-party/soundfonts" "$TP/"
  (cd "$B" && export PATH="$T/bin:$PATH"
   java -jar closure-compiler.jar --language_out ECMASCRIPT5 --language_in ECMASCRIPT5 \
     --js "$TP/JS-Interpreter/acorn.js" --js "$TP/JS-Interpreter/interpreter.js" \
     --js_output_file "$TP/JS-Interpreter/compressed.js"
   "$PY" build/messages_to_json.py >/dev/null && "$PY" build/json_to_js.py >/dev/null
   for game in index puzzle maze bird turtle movie music pond/tutor pond/duck; do
     "$PY" build/compress.py "$game" | tail -1; done)
  local O="$SITE/blockly"
  rm -rf "$O" && cp -R "$B/appengine" "$O"
  (cd "$O" && rm -f ./*.yaml ./*.py ./*.sh admin.html robots.txt index/title.png index/title-beta.png pond/crobots.txt \
     common/stripes.svg third-party/base.js third-party/soundfonts/README.txt
   rm -rf gallery* generated pond/battle ./src ./*/src ./*/*/src
   rm -f ./*/generated/uncompressed.js ./*/*/generated/uncompressed.js
   find third-party/SoundJS -type f ! -name soundjs.min.js -delete
   find third-party/JS-Interpreter -mindepth 1 ! -name compressed.js -exec rm -rf {} +
   find third-party/blockly -mindepth 1 -maxdepth 1 ! -name media -exec rm -rf {} +
   find . -name '.DS_Store' -delete)
  licence "$B/LICENSE" blockly "https://github.com/google/blockly-games (5d2ff6f), version sans serveur"
  echo "Blockly Games : $(du -sh "$O" | cut -f1)"
}

for lab in ${@:-phet circuit optique logique molecules netlogo snap python blockly musique}; do
  echo "== $lab"
  "$lab"
done
du -sh "$SITE" 2>/dev/null | tail -1
