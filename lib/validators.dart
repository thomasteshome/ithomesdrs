/// ============================================================================
/// SHARED CLIENT-SIDE FORM VALIDATORS
/// Used by the Enterprise Registration, Visit Plan, Support Report and
/// account-creation forms across the GIC portals. All checks are run before
/// data is written to Firestore.
/// ============================================================================

/// Non-empty after trimming.
String? requiredField(String? value, {String message = 'This field is required'}) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}

final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp _phoneRe = RegExp(r'^\+?[0-9][0-9\s\-]{6,14}$');

/// Valid email format. When [optional] is true an empty value is allowed,
/// but a non-empty value must still be a valid email.
String? emailField(String? value, {bool optional = false}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return optional ? null : 'Email is required';
  if (!_emailRe.hasMatch(v)) return 'Enter a valid email address';
  return null;
}

/// Valid phone format (digits, optional leading +, spaces/dashes allowed).
String? phoneField(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Phone number is required';
  if (!_phoneRe.hasMatch(v)) return 'Enter a valid phone number';
  return null;
}

/// Password minimum length (Firebase Auth requires at least 6 characters).
String? passwordField(String? value, {int minLength = 6}) {
  final v = value ?? '';
  if (v.isEmpty) return 'Password is required';
  if (v.length < minLength) {
    return 'Password must be at least $minLength characters';
  }
  return null;
}
