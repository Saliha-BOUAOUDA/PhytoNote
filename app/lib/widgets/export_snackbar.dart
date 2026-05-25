import 'dart:io';

import 'package:flutter/material.dart';

import '../services/excel_export.dart';

/// Tooltip à afficher sur le bouton "exporter" en haut à droite des écrans.
/// Le wording diffère selon la plateforme : sur Android, le bouton déclenche
/// vraiment un partage (panel système) ; sur desktop, il enregistre simplement
/// le fichier dans Documents/PhytoNote_exports.
String exportButtonTooltip() {
  if (Platform.isAndroid || Platform.isIOS) {
    return 'Exporter Excel & partager';
  }
  return 'Enregistrer en Excel';
}

/// Affiche un snackbar confirmant la génération du fichier Excel.
/// Sur desktop, ajoute un bouton "Ouvrir le dossier" pour appeler
/// [openExportsFolder] à la demande.
void showExportSuccessSnackBar(BuildContext context, File file) {
  final fileName = file.path.split(Platform.pathSeparator).last;
  final isMobile = Platform.isAndroid || Platform.isIOS;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          isMobile
              ? 'Excel généré : $fileName'
              : 'Excel enregistré : Documents/PhytoNote_exports/$fileName',
        ),
        duration: isMobile ? const Duration(seconds: 4) : const Duration(seconds: 8),
        action: isMobile
            ? null
            : const SnackBarAction(
                label: 'Ouvrir le dossier',
                onPressed: openExportsFolder,
              ),
      ),
    );
}

void showExportErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text('Erreur export : $error')));
}
