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

## Utilisation

### Prérequis

**Matériel labo**
- Spectrophotomètre UV à mono-mesure (cuvettes 1 mL)
- Plaque 96 puits (uniquement pour le test antibactérien `ANTIBAC`)
- Solvants, standards de référence et extraits préparés selon ton protocole

**Plateforme**
- Android 7+ (avec ~20 MB de stockage libre), ou Linux Ubuntu 22.04+ / Debian
- **Aucun réseau requis** : l'app fonctionne 100 % hors ligne pour les opérations cœur

### Vue d'ensemble du workflow

PhytoNote s'organise autour de trois entités liées :

```
Catalogue   →   Calibration   →   Manip (Session)
plantes,         courbe étalon       saisie validée des DOs,
extraits,        pour un couple      validation 🟢🟡🔴 live,
standards,       (test, standard,    IC50 live, export Excel
bactéries,       lot de réactif)
enzymes
```

L'écran d'accueil expose ces trois portes d'entrée plus quelques utilitaires (Catalogue, Calibrations, Reprendre une manip, Paramètres).

### Étape 1 — Remplir le catalogue (~10 min, à faire une fois)

À l'installation, le catalogue est vide. Avant la première manip, ouvre l'écran **Catalogue** depuis l'accueil. Cinq onglets : *Plantes · Extraits · Standards · Bactéries · Enzymes*.

Deux façons de peupler :

- **Bouton « + Plante / + Extrait / … »** (FAB en bas à droite) pour ajouter manuellement. Chaque entrée a des champs détaillés (nom scientifique, organe, famille pour les plantes ; polarité pour les extraits ; ChEMBL ID + masse molaire pour les standards ; Gram + souche ATCC pour les bactéries ; numéro EC pour les enzymes).
- **Icône ⬇ « Importer un Starter Pack »** (en haut à droite) pour importer un des 11 packs JSON pré-remplis et sourcés bibliographiquement :
  - *Extraits & solvants courants*
  - *Standards antioxydants / antibactériens / anti-inflammatoires*
  - *Bactéries panel standard / ESKAPE / pathogènes alimentaires / autres*
  - *Enzymes antidiabétiques / anti-inflammatoires / autres*

> **Astuce code custom** : chaque entrée a un champ « Code custom » (ex. `RP` pour Romarin, `EC` pour Eucalyptus). Optionnel mais utile pour anonymiser tes échantillons dans les exports Excel et publications.

Tu peux à tout moment « archiver » une entrée (soft-delete) : elle disparaît des listes actives mais reste rattachée à l'historique des sessions où elle a servi.

### Étape 2 — Créer une calibration

Une calibration = une courbe étalon pour un couple **(test, standard, lot de réactif)**. Obligatoire avant les sessions DPPH, ABTS, FRAP, CAT, TPC, TFC (les tests ANTIBAC et ANTIINF n'utilisent pas de calibration linéaire).

Depuis l'accueil → **Calibrations** → bouton **+** en bas à droite.

Cascading 4-5 étapes :

1. **Test** : DPPH, FRAP, CAT, TPC, TFC, ABTS
2. **Standard** (si plusieurs compatibles) : par exemple Acide ascorbique (AA), Acide gallique (GA), Trolox (TRX) selon le test
3. **Lot de réactif** : numéro fournisseur (optionnel, ex. *Sigma 12345-A*) + **date d'ouverture du flacon**
4. **Plan d'acquisition** : réplicats par concentration (2/3/4) + nombre de dilutions par 2 si configurable (6/8/10)
5. **DO contrôle (référence)** : DO attendue pour le contrôle (test + solvant), modifiable selon ton lot

Bouton **« Saisir les points »** → grille des points de calibration. À chaque DO tapée, PhytoNote met à jour **en live** la régression linéaire (pente, ordonnée à l'origine, **R²**) et affiche la courbe via `fl_chart`. Tu peux exclure un point aberrant d'un toggle : le R² recalcule instantanément.

Bouton **« Valider et sauvegarder »** → la calibration devient utilisable pour les manips suivantes du même couple, tant que tu ne la marques pas obsolète.

### Étape 3 — Lancer une manip

Depuis l'accueil → grande carte verte **« Nouvelle manip »**.

Cascading 4-7 étapes (selon le test choisi) :

1. **Test** : DPPH, ABTS, FRAP, CAT, TPC, TFC, ANTIBAC, ANTIINF
2. **Plante** (depuis ton catalogue)
3. **Type d'extrait** (MeOH, EtOH, EtOAc, EO…)
4. **Réplicats par concentration** (2/3/4)
5. **Standard de référence** (si plusieurs compatibles avec le test)
6. **Souche bactérienne** (uniquement pour ANTIBAC)
7. **DO contrôle attendu** (uniquement si le test en nécessite un)

Bouton **« Démarrer la manip »** → PhytoNote cherche automatiquement la calibration valide la plus récente pour le couple **(test, standard)**. Si aucune n'est trouvée, une snackbar t'avertit ⚠ mais la manip continue (sans calcul d'équivalents). Tu peux toujours en créer une après et lier la session.

### Étape 4 — Saisir les mesures (le cœur du workflow)

#### Mode classique (DPPH, ABTS, FRAP, CAT, TPC, TFC, ANTIINF)

L'écran de session affiche une grille : une ligne par concentration, une colonne par réplicat. À chaque lecture du spectro, tu tapes la DO dans la cellule active :

- **🟢 Vert** : valeur cohérente avec la calibration (dans la tolérance)
- **🟡 Jaune** : suspecte — à confirmer ou refaire
- **🔴 Rouge** : aberrante — refais le tube tant qu'il est encore préparé

La validation s'affiche en **~200 ms**, donc tu peux décider sur place. Les valeurs jaunes/rouges ne bloquent rien : elles sont enregistrées mais signalées dans l'export Excel.

**Auto-commit live** : pas de bouton OK. Chaque frappe est sauvegardée immédiatement en SQLite, donc même une coupure de batterie ne fait rien perdre.

**Barre de navigation gants-friendly** au-dessus du clavier : `◀ Préc · Suiv ▶ · Terminé`. Boutons ≥ 72 dp pour être tapables avec des gants nitrile.

**Bandeau sticky des résultats** en haut de l'écran : dès que la régression converge, l'**IC50** estimé et les équivalents (AAE / GAE / TE…) s'affichent en temps réel, mis à jour à chaque saisie. Tu vois immédiatement si ta cinétique « tient debout » avant même d'avoir fini la série.

#### Mode plaque 96 puits (ANTIBAC)

L'écran présente la plaque entière. Chaque puits est cliquable.

- **Plan d'échantillon** : les colonnes B-K reçoivent les dilutions de ton extrait (8 concentrations × 8 réplicats par défaut).
- **Plan de standard antibiotique** : ciprofloxacine ou gentamicine en colonnes dédiées, comme contrôle positif d'inhibition.
- **Contrôles obligatoires** : `T+` (bactérie sans extrait, croissance attendue) et `T−` (milieu seul, stérilité) en colonnes A et L.

Saisie par puits : croissance (oui/non) ou DO si tu as un lecteur de plaque. PhytoNote calcule :
- **CMI** (Concentration Minimale Inhibitrice) automatiquement à partir des puits sans croissance
- **CMB** (Concentration Minimale Bactéricide) saisie manuellement après ré-ensemencement sur gélose (champ dédié)

### Étape 5 — Exporter et partager

Bouton **« Exporter Excel »** depuis l'écran de session. Génère un fichier `.xlsx` multi-feuilles dans :
- **Android** : `~/Documents/PhytoNote_exports/` (visible dans l'app Files)
- **Linux** : `~/Documents/PhytoNote_exports/`

Feuilles produites :
1. **Couverture** — métadonnées de la session (plante, extrait, test, opérateur, dates)
2. **Calibration liée** — courbe et coefficients de la calibration utilisée
3. **Mesures brutes** — toutes les DOs tapées, avec leur statut 🟢🟡🔴
4. **Résultats calculés** — concentrations équivalentes, IC50, statistiques
5. **Plaque** (uniquement ANTIBAC) — disposition complète des puits + CMI/CMB

Sur **Android**, une snackbar « Partager » apparaît après l'export : ouvre le picker natif (WhatsApp, Drive, mail, etc.). Sur **Linux**, le fichier est dans le dossier — ouvre-le avec LibreOffice ou Excel.

### Reprendre une manip interrompue

L'écran d'accueil affiche en permanence un compteur : *« N manips en cours »*. Si tu fermes l'app au milieu d'une session :

- Accueil → **« Reprendre une manip »** → liste des sessions actives, filtrable.
- Tape sur ta session : tu retrouves toutes les DOs déjà saisies, la barre IC50, la calibration liée, exactement dans l'état où tu l'avais laissée.

Grâce à l'auto-commit, **aucune saisie n'est jamais perdue**.

### Astuces pratiques

- **Pill « Hors ligne »** en haut de l'accueil : rappelle que rien ne quitte le téléphone. PhytoNote ne fait aucun appel réseau pour son cœur métier.
- **Codes plantes anonymisés** : utilise le champ « Code custom » du catalogue (ex. `RP`, `EC`, `P1`) pour que tes exports ne révèlent pas les noms scientifiques avant publication.
- **Suivi de fraîcheur du réactif** : à l'ouverture d'une calibration, PhytoNote affiche depuis combien de jours le lot est ouvert. À toi de décider si tu recalibres.
- **Historique filtrable** : l'écran *Calibrations* et la liste *Reprendre une manip* permettent de filtrer / supprimer / dupliquer les anciennes entrées.

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

## Auteur

**Saliha BOUAOUDA** — Casablanca, Maroc (UTC +01:00)

- Email : [sl.bouaouda@gmail.com](mailto:sl.bouaouda@gmail.com)
- Site / hub : [phytochemhub.com](https://phytochemhub.com/)
- LinkedIn : [saliha-bouaouda](https://www.linkedin.com/in/saliha-bouaouda-97b04320a/?locale=fr)
- ResearchGate : [Saliha-Bouaouda](https://www.researchgate.net/profile/Saliha-Bouaouda)
- ORCID : [0009-0000-9663-462X](https://orcid.org/0009-0000-9663-462X)

---

PhytoNote fait partie de l'écosystème [**PhytochemHub**](https://phytochemhub.com) — plateforme d'agrégation des projets scientifiques.
