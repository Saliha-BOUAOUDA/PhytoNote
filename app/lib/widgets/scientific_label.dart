import 'package:flutter/material.dart';

/// Texte scientifique avec italique optionnel — utilisé pour afficher les
/// noms de bactéries (« *E. coli* ») et les noms latins de plantes en gras.
///
/// Si `italic = true`, applique `FontStyle.italic` à tout le texte.
class ScientificLabel extends StatelessWidget {
  const ScientificLabel({
    super.key,
    required this.text,
    this.italic = false,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final bool italic;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text(
      text,
      style: base.copyWith(fontStyle: italic ? FontStyle.italic : FontStyle.normal),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
