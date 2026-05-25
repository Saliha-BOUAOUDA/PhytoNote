# Changelog

Toutes les versions publiées de PhytoNote. Format inspiré de [Keep a Changelog](https://keepachangelog.com/), versionnement [SemVer](https://semver.org/).

## [1.0.0] — 2026-05-25

### Premier lancement public

- **8 tests scientifiques** intégrés : DPPH, ABTS, FRAP, CAT, TPC, TFC, ANTIBAC, ANTIINF (cf. tableau des références dans le README).
- **Catalogue éditable** 5 catégories : plantes, extraits, standards, bactéries, enzymes — schéma uniforme (`id`, `custom_code` optionnel, `abbreviation`, `name`, `metadata` JSON).
- **11 Starter Packs JSON** téléchargeables depuis l'écran Catalogue (bouton ⬇) : extraits / solvants courants, standards (antioxydants / antibactériens / anti-inflammatoires), bactéries (panel standard / ESKAPE / pathogènes alimentaires / autres), enzymes (antidiabétiques / anti-inflammatoires / autres). Contenu sourcé bibliographiquement (PubMed, ChEMBL).
- **Création de manip cascading** 4-7 étapes selon le test.
- **Saisie mesures avec validation 🟢🟡🔴**, switch d'exclusion par concentration.
- **Vue plaque 96 puits** pour ANTIBAC : CMI auto, CMB manuelle, contrôles obligatoires (T+/T−).
- **Calibration formelle** avec régression linéaire live, R², chart `fl_chart`, exclusion par point.
- **IC50 + équivalents** live sur `SessionScreen` avec mini graph + bandeau sticky.
- **Auto-commit live** des champs DO : sauvegarde à chaque frappe, plus besoin du bouton OK.
- **Barre de navigation gants-friendly** au-dessus du clavier (◀ Préc / Suiv ▶ / Terminé).
- **Historique des manips et calibrations** : filtrable, deletable, resumable.
- **Export Excel multi-feuilles** + share intent natif Android (WhatsApp / Drive / mail).
- **Écran Paramètres** : version, langue (FR actif, EN/AR à venir), liens GitHub, license.
- **Versions Android** (APK `arm64-v8a` ~8 MB) et **Linux desktop** (`.deb` Ubuntu 22+ / Debian).

[1.0.0]: https://github.com/Saliha-BOUAOUDA/PhytoNote/releases/tag/v1.0.0
