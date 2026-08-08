import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// NOTIFICATION SERVICE
/// Tiny helper for writing notification records into the Firestore
/// 'notifications' collection. Notifications are scoped by an optional
/// recipient [userId] (audience 'user'), an optional [department]
/// (audience 'department'), or sent college-wide (audience 'all').
/// ============================================================================

/// Pushes a notification record. Never throws — notification failures must
/// not block the primary workflow that triggered them.
Future<void> pushNotification({
  required String title,
  required String message,
  String? userId,
  String? department,
  String? audience,
  List<String>? roles,
  String type = 'info',
  String? priority,
}) async {
  final target = audience ??
      (userId != null ? 'user' : (department != null ? 'department' : 'all'));
  try {
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'message': message,
      'type': type,
      'userId': userId,
      'department': department,
      'audience': target,
      // Optional role gate, e.g. ['deptHead', 'dean'] — keeps department
      // notifications from broadcasting to every expert in the department.
      'roles': roles,
      // Optional priority (High / Normal / Low) from broadcast tools.
      'priority': priority,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // Swallow: notifications are best-effort.
  }
}
