/// ============================================================================
/// SAFE FIRESTORE FIELD ACCESS
/// ----------------------------------------------------------------------------
/// `DocumentSnapshot.operator[]` (e.g. `doc['department']`) and
/// `DocumentSnapshot.get('field')` throw a `Bad state: field does not exist`
/// StateError whenever a field is missing from a legacy document. These
/// helpers read through `doc.data()` (a plain Map) so missing/null fields
/// fall back to a default instead of crashing the widget tree.
/// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Read a field as a non-null string, defaulting to [fallback] when the
/// document, the field, or the value is missing/null.
String docStr(DocumentSnapshot doc, String field, [String fallback = '']) {
  final data = doc.data() as Map<String, dynamic>?;
  final raw = data != null ? data[field] : null;
  return raw == null ? fallback : raw.toString();
}

/// Read a field as a raw (nullable) value, returning null when missing.
Object? docVal(DocumentSnapshot doc, String field) {
  final data = doc.data() as Map<String, dynamic>?;
  return data != null ? data[field] : null;
}

/// Read a bool field, defaulting to [fallback] (false) when missing.
bool docBool(DocumentSnapshot doc, String field, [bool fallback = false]) {
  final raw = docVal(doc, field);
  return raw is bool ? raw : fallback;
}

/// Case-insensitive, whitespace-trimmed department equality so 'ICT',
/// 'ict' and '  ICT  ' all match. Missing/null values normalize to ''.
bool deptMatches(String? a, String? b) {
  final na = (a ?? '').toString().trim().toLowerCase();
  final nb = (b ?? '').toString().trim().toLowerCase();
  return na == nb;
}

/// Normalize a department string for grouping/keys: trimmed + lowercased,
/// defaulting to '' when null/missing.
String normDept(String? raw) => (raw ?? '').toString().trim().toLowerCase();
