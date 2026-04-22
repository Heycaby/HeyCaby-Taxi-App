/// Dutch chauffeurspas (Kiwa) — 8–12 digits, optional NL prefix (migration 041 guide).
class ChauffeurspasValidationResult {
  const ChauffeurspasValidationResult({
    required this.valid,
    required this.cleaned,
    this.error,
  });

  final bool valid;
  final String cleaned;
  final String? error;
}

ChauffeurspasValidationResult validateChauffeurspasNumber(String input) {
  var cleaned = input.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
  if (cleaned.startsWith('NL')) {
    cleaned = cleaned.substring(2);
  }
  if (!RegExp(r'^\d{8,12}$').hasMatch(cleaned)) {
    return ChauffeurspasValidationResult(
      valid: false,
      cleaned: cleaned,
      error:
          'Een chauffeurspas nummer bestaat uit 8 tot 12 cijfers. Controleer uw pas.',
    );
  }
  return ChauffeurspasValidationResult(valid: true, cleaned: cleaned);
}
