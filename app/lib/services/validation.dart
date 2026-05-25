enum ValidationLevel { ok, warning, error }

class ValidationResult {
  final ValidationLevel level;
  final String? message;

  const ValidationResult.ok([this.message]) : level = ValidationLevel.ok;
  const ValidationResult.warning(String this.message) : level = ValidationLevel.warning;
  const ValidationResult.error(String this.message) : level = ValidationLevel.error;
}

ValidationResult validateControl(double measured, double? expected) {
  if (expected == null) return const ValidationResult.ok();
  if (measured < 0 || measured > 4) {
    return const ValidationResult.error('DO hors plage physique (0–4)');
  }
  final delta = (measured - expected).abs();
  if (delta <= 0.05) {
    return const ValidationResult.ok('Conforme à l\'attendu');
  }
  if (delta <= 0.15) {
    return ValidationResult.warning(
      'Écart ${delta.toStringAsFixed(3)} avec ${expected.toStringAsFixed(3)} attendu',
    );
  }
  return ValidationResult.error(
    'Écart trop important : attendu ~${expected.toStringAsFixed(3)}, mesuré ${measured.toStringAsFixed(3)}',
  );
}

ValidationResult validateDO(double rawDO) {
  if (rawDO < 0) return const ValidationResult.error('DO négative impossible');
  if (rawDO > 4) return const ValidationResult.error('DO > 4 — lecture saturée, diluer');
  if (rawDO > 3.5) return const ValidationResult.warning('DO élevée, proche saturation');
  if (rawDO == 0) return const ValidationResult.warning('DO = 0 — vérifier la lecture');
  return const ValidationResult.ok();
}

double? parseDecimal(String input) {
  final cleaned = input.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}
