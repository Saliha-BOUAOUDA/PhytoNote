# PhytoNote

> Application **offline-first** (Android + Linux desktop) de saisie validée en temps réel pour spectrophotométrie UV en chimie des plantes.

## Pourquoi

Sur un spectrophotomètre UV mono-mesure, en conditions de labo sans réseau, avec des gants — la saisie manuelle puis la transcription Excel des semaines plus tard masque les erreurs de pipetage jusqu'à ce qu'elles soient impossibles à corriger.

PhytoNote remplace ce cycle par :

```
Mesure → Saisie immédiate → Validation 🟢🟡🔴 en 200 ms → Décision sur place
```

Si la valeur est 🟡 ou 🔴, le tube est refait tant qu'il est encore préparé.

## Tests scientifiques supportés

8 tests intégrés avec validation visuelle 🟢🟡🔴 et calibration formelle (R², régression linéaire) :

| Code | Test | Référence |
|---|---|---|
| DPPH | Activité anti-radicalaire | Brand-Williams 1995 |
| ABTS | Activité anti-radicalaire ABTS•+ | Re et al. 1999 |
| FRAP | Pouvoir réducteur du Fe³⁺ | Benzie & Strain 1996 |
| CAT | Capacité antioxydante totale | Prieto 1999 |
| TPC | Polyphénols totaux | Singleton & Rossi 1965 |
| TFC | Flavonoïdes totaux | Zhishen et al. 1999 |
| ANTIBAC | Microdilution MIC/MBC sur plaque 96 puits | CLSI M07-A11 |
| ANTIINF | BSA denaturation (anti-inflammatoire) | Sarveswaran 2017 |

Plantes, extraits, standards, bactéries et enzymes sont **éditables** depuis l'écran « Catalogue » sans toucher au code.

## Installation

### Android (APK)

Télécharger l'APK `arm64-v8a` depuis la [dernière release](../../releases/latest), puis sur le téléphone :

1. Activer « Sources inconnues » dans les paramètres
2. Ouvrir le `.apk` → installer
3. L'icône apparaît dans le drawer

### Linux (Ubuntu 22.04+ / Debian)

Télécharger le `.deb` depuis la [dernière release](../../releases/latest) :

```bash
sudo dpkg -i phytonote_<version>_amd64.deb
```

Ou double-clic sur le fichier dans Files → « Software Install ».

Dépendances système (déjà installées par défaut sur Ubuntu) : `libgtk-3-0`, `libglib2.0-0`, `libstdc++6`.

## Build depuis les sources

Prérequis : Flutter 3.5+, Dart 3.5+, JDK 17 (Android), `dpkg-deb` + `python3-pil` (Linux `.deb`).

```bash
git clone git@github.com:Saliha-BOUAOUDA/PhytoNote.git
cd PhytoNote/app
flutter pub get

# Dev sur desktop
flutter run -d linux

# Release APK
flutter build apk --release --split-per-abi

# Release .deb Linux
cd ..
./scripts/build_deb.sh
# → build/phytonote_<version>_amd64.deb
```

## Stack technique

- **Flutter / Dart** — UI multiplateforme (Android + Linux + macOS + Windows)
- **SQLite** (`sqflite` + `sqflite_common_ffi`) — stockage offline-first
- **fl_chart** — courbes de calibration et IC50 live
- **excel** — export multi-feuilles
- **share_plus** — partage natif Android (WhatsApp / Drive / mail)

## Architecture

```
Calibration  ←  référencée par  →  Session  →  contient  →  Measurement
  (lot de réactif)                  (1 manip)              (1 DO + statut)
```

Catalogue éditable (SQLite) : `plants`, `extracts`, `standards`, `bacteria`, `enzymes` — soft-delete par `is_archived` pour préserver les sessions historiques.

## Contraintes structurantes

- 100 % offline pour les opérations cœur (zéro dépendance réseau)
- Saisie avec gants : boutons ≥ 72 dp, espacement ≥ 24 dp, contraste WCAG AA
- Auto-commit live : valeur sauvegardée à chaque frappe (pas de bouton OK requis)
- Barre de navigation au-dessus du clavier pour passer d'un champ à l'autre sans viser
- Spectro UV mono-mesure : 1 saisie par tube, pas de plate reader
- DOs brutes = seule source de vérité (pas de calculs déjà faits ailleurs)

## License

[GPL-3.0-or-later](./LICENSE) — copyleft fort. Si vous redistribuez une version modifiée, vous devez publier vos modifications sous la même licence. Aligné avec la science ouverte (Linux, R, eLabFTW…).

Copyright © 2026 Saliha BOUAOUDA.

---

PhytoNote fait partie de l'écosystème [**PhytochemHub**](https://phytochemhub.com) — plateforme d'agrégation des projets scientifiques.
