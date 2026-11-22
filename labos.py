"""Aides de construire_labos.sh (sans dépendance : lancé avec le python3 du système).

phet-slugs              simulations PhET du Labo, lues dans backend/app/open_resources.py (une seule liste à tenir) ;
netlogo <gabarit> <modèles> <sortie>
                        une page autonome NetLogo Web par modèle (le modèle est inséré dans la page exportable de
                        NetLogo Web, sans pisteur ni police extérieure) ;
molecules-liste         les molécules de la page 3D (numéro PubChem, nom, formule, famille), au format JSON.
"""

import html
import json
import re
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[2]

# Modèles NetLogo (bibliothèque officielle, Uri Wilensky et CCL Northwestern, CC BY-NC-SA 3.0) : slug → fichier.
# Les fiches (titre, matière, niveaux) sont dans backend/app/open_resources.py ; un test vérifie que les deux
# listes concordent.
NETLOGO_MODELS = {
    "loups-moutons": "Sample Models/Biology/Wolf Sheep Predation.nlogox",
    "lapins-herbe": "Sample Models/Biology/Rabbits Grass Weeds.nlogox",
    "virus": "Sample Models/Biology/Virus.nlogox",
    "vih": "Sample Models/Biology/HIV.nlogox",
    "glycemie": "Sample Models/Biology/Blood Sugar Regulation.nlogox",
    "phalenes": "Sample Models/Biology/Evolution/Peppered Moths.nlogox",
    "daisyworld": "Sample Models/Biology/Daisyworld.nlogox",
    "enzymes": "Sample Models/Chemistry & Physics/Chemical Reactions/Enzyme Kinetics.nlogox",
    "climat": "Sample Models/Earth Science/Climate Change.nlogox",
    "feu-de-foret": "Sample Models/Earth Science/Fire.nlogox",
    "gaz-boite": "Sample Models/Chemistry & Physics/GasLab/GasLab Gas in a Box.nlogox",
    "gaz-piston": "Sample Models/Chemistry & Physics/GasLab/GasLab Isothermal Piston.nlogox",
    "cinetique": "Sample Models/Chemistry & Physics/Chemical Reactions/Simple Kinetics 1.nlogox",
    "equilibre-chimique": "Sample Models/Chemistry & Physics/Chemical Reactions/Chemical Equilibrium.nlogox",
    "radioactivite": "Sample Models/Chemistry & Physics/Radioactivity/Decay.nlogox",
    "ondes": "Sample Models/Chemistry & Physics/Waves/Wave Machine.nlogox",
}

# Molécules de la page 3D : numéro PubChem (structure 3D, domaine public), nom, formule brute, famille.
MOLECULES = [
    (962, "Eau", "H_2O", "Chimie minérale"),
    (222, "Ammoniac", "NH_3", "Chimie minérale"),
    (280, "Dioxyde de carbone", "CO_2", "Chimie minérale"),
    (784, "Peroxyde d'hydrogène (eau oxygénée)", "H_2O_2", "Chimie minérale"),
    (24823, "Ozone", "O_3", "Chimie minérale"),
    (1118, "Acide sulfurique", "H_2SO_4", "Chimie minérale"),
    (944, "Acide nitrique", "HNO_3", "Chimie minérale"),
    (297, "Méthane", "CH_4", "Hydrocarbures"),
    (6324, "Éthane", "C_2H_6", "Hydrocarbures"),
    (6334, "Propane", "C_3H_8", "Hydrocarbures"),
    (7843, "Butane", "C_4H_{10}", "Hydrocarbures"),
    (6360, "Méthylpropane (isobutane)", "C_4H_{10}", "Hydrocarbures"),
    (6325, "Éthylène (éthène)", "C_2H_4", "Hydrocarbures"),
    (6326, "Acétylène (éthyne)", "C_2H_2", "Hydrocarbures"),
    (8078, "Cyclohexane", "C_6H_{12}", "Hydrocarbures"),
    (241, "Benzène", "C_6H_6", "Hydrocarbures"),
    (1140, "Toluène", "C_7H_8", "Hydrocarbures"),
    (887, "Méthanol", "CH_4O", "Composés oxygénés"),
    (702, "Éthanol", "C_2H_6O", "Composés oxygénés"),
    (753, "Glycérol", "C_3H_8O_3", "Composés oxygénés"),
    (712, "Méthanal (formaldéhyde)", "CH_2O", "Composés oxygénés"),
    (177, "Éthanal", "C_2H_4O", "Composés oxygénés"),
    (180, "Propanone (acétone)", "C_3H_6O", "Composés oxygénés"),
    (284, "Acide méthanoïque", "CH_2O_2", "Composés oxygénés"),
    (176, "Acide éthanoïque (acide acétique)", "C_2H_4O_2", "Composés oxygénés"),
    (8857, "Éthanoate d'éthyle (ester)", "C_4H_8O_2", "Composés oxygénés"),
    (996, "Phénol", "C_6H_6O", "Composés oxygénés"),
    (6115, "Aniline", "C_6H_7N", "Composés azotés"),
    (1176, "Urée", "CH_4N_2O", "Composés azotés"),
    (750, "Glycine", "C_2H_5NO_2", "Biologie"),
    (5950, "Alanine", "C_3H_7NO_2", "Biologie"),
    (5793, "Glucose", "C_6H_{12}O_6", "Biologie"),
    (5988, "Saccharose", "C_{12}H_{22}O_{11}", "Biologie"),
    (5997, "Cholestérol", "C_{27}H_{46}O", "Biologie"),
    (5957, "ATP (adénosine triphosphate)", "C_{10}H_{16}N_5O_{13}P_3", "Biologie"),
    (2244, "Aspirine", "C_9H_8O_4", "Médicaments"),
    (1983, "Paracétamol", "C_8H_9NO_2", "Médicaments"),
    (2519, "Caféine", "C_8H_{10}N_4O_2", "Médicaments"),
]


def phet_slugs() -> list[str]:
    text = (BACKEND / "app" / "open_resources.py").read_text(encoding="utf-8")
    return list(dict.fromkeys(re.findall(r'_phet\("([a-z0-9-]+)"', text)))


def standalone_page(template: str) -> str:
    """Page exportable de NetLogo Web, sans Google Analytics ni Google Fonts (aucune requête vers Google)."""
    page, n = re.subn(r'if \(!params\.has\("disableAnalytics"\)\)', "if (false)", template)
    if n != 1:
        raise SystemExit("NetLogo : bloc Google Analytics introuvable, page à vérifier")
    page = re.sub(r'\s*<link[^>]+fonts\.(googleapis|gstatic)\.com[^>]*>', "", page)
    if "fonts.googleapis" in page or 'id="nlogo-code"' not in page:
        raise SystemExit("NetLogo : page exportable inattendue")
    return page


def build_netlogo(template_path: str, models_dir: str, out_dir: str) -> None:
    page = standalone_page(Path(template_path).read_text(encoding="utf-8"))
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for slug, rel in NETLOGO_MODELS.items():
        code = (Path(models_dir) / rel).read_text(encoding="utf-8")
        if "</script" in code.lower():
            raise SystemExit(f"NetLogo : {rel} contient </script>")
        tag = (f'<script type="text/nlogo" id="nlogo-code" data-filename="{html.escape(Path(rel).name)}">'
               f"{code}</script>")
        result = re.sub(r'<script type="text/nlogo" id="nlogo-code"[^>]*></script>', lambda _m: tag, page, count=1)
        (out / f"{slug}.html").write_text(result, encoding="utf-8")
    print(f"NetLogo : {len(NETLOGO_MODELS)} modèles")


if __name__ == "__main__":
    command = sys.argv[1]
    if command == "phet-slugs":
        print("\n".join(phet_slugs()))
    elif command == "netlogo":
        build_netlogo(*sys.argv[2:5])
    elif command == "molecules-liste":
        print(json.dumps([{"cid": c, "nom": n, "formule": f, "famille": g} for c, n, f, g in MOLECULES],
                         ensure_ascii=False, indent=1))
