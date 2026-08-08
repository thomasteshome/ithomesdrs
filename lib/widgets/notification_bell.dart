import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'app_ui.dart';
import '../firestore_safe.dart';

/// Describes who this bell is scoped to so notifications are filtered to
/// the right audience ('user' | 'department' | 'all').
class NotificationScope {
  final String role; // 'expert' | 'deptHead' | 'dean'
  final String? department;

  const NotificationScope({required this.role, this.department});
}

/// Top-bar notification bell with a live unread badge and an anchored
/// popup panel listing notifications from the 'notifications' collection.
class NotificationBell extends StatefulWidget {
  final NotificationScope scope;
  final Color color;

  const NotificationBell({
    super.key,
    required this.scope,
    this.color = AppPalette.textMuted,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _overlay;
  bool _open = false;
  bool _marking = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.email ?? '';

  Stream<QuerySnapshot<Object?>> get _stream => FirebaseFirestore.instance
      .collection('notifications')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots();

  bool _visibleToMe(Map<String, dynamic> data) {
    // Optional role gate: e.g. ['deptHead', 'dean'] means only those roles
    // see this notification (used so department-scoped notices don't spam
    // every expert in the department).
    final roles = data['roles'];
    if (roles is List && roles.isNotEmpty) {
      final mine = widget.scope.role.toLowerCase();
      final allowed = roles
          .map((r) => r.toString().toLowerCase())
          .any((r) => r == mine);
      if (!allowed) return false;
    }
    final audience = (data['audience'] ?? 'all').toString();
    final target = (data['userId'] ?? '').toString();
    if (audience == 'all') return true;
    if (widget.scope.role == 'dean') {
      // The Dean sees college-wide + every department, but not private
      // user-to-user notifications addressed to someone else.
      return audience != 'user' || (target.isNotEmpty && target == _myUid);
    }
    if (audience == 'user') {
      return target.isNotEmpty && target == _myUid;
    }
    // 'department' audience
    final dept = (data['department'] ?? '').toString();
    final myDept = widget.scope.department ?? '';
    return dept.isNotEmpty && myDept.isNotEmpty && dept == myDept;
  }

  // ============================ PANEL OPEN/CLOSE ============================
  void _toggle() => _open ? _close() : _openPanel();

  void _openPanel() {
    if (_overlay != null) return; // avoid double-insert on rapid taps
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final screen = MediaQuery.of(context).size;
    final topLeft = box.localToGlobal(Offset.zero);
    final panelWidth = screen.width < 420 ? screen.width - 16 : 400.0;
    final right = screen.width - (topLeft.dx + box.size.width);
    final panelHeight =
        (screen.height - topLeft.dy - 32).clamp(280.0, 520.0).toDouble();

    setState(() => _open = true);
    _overlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Tap-away barrier
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          Positioned(
            top: topLeft.dy + box.size.height + 8,
            right: right < 8 ? 8 : right,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelWidth,
                height: panelHeight,
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppPalette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: _buildPanel(),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _open = false);
  }

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  // ============================ BELL BUTTON ============================
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot>[];
        final visible = docs
            .where((d) => _visibleToMe(d.data() as Map<String, dynamic>))
            .toList();
        final unread =
            visible.where((d) => !docBool(d, 'read')).length;

        return InkWell(
          key: _anchorKey,
          onTap: _toggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_none,
                  color: _open ? AppPalette.primary : widget.color,
                  size: 24,
                ),
                if (unread > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================ PANEL CONTENT ============================
  Widget _buildPanel() {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? <QueryDocumentSnapshot>[])
            .where((d) => _visibleToMe(d.data() as Map<String, dynamic>))
            .toList();
        final unread = docs.where((d) => !docBool(d, 'read')).toList();
        if (unread.isNotEmpty && !_marking) {
          _marking = true; // auto-clear on open, guarded against re-fires
          _markAllRead(unread).whenComplete(() => _marking = false);
        }

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      color: AppPalette.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppPalette.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unread new',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close, size: 18),
                    color: AppPalette.textMuted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppPalette.border),
            // List
            Expanded(
              child: docs.isEmpty
                  ? const _EmptyNotifications()
                  : ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) =>
                          _NotificationTile(data: docs[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markAllRead(List<QueryDocumentSnapshot<Object?>> unread) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final d in unread) {
      batch.update(d.reference, {'read': true});
    }
    try {
      await batch.commit();
    } catch (_) {
      // Best-effort.
    }
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 46, color: AppPalette.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          const Text(
            'No notifications yet',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppPalette.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Plan decisions and report updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final DocumentSnapshot data;
  const _NotificationTile({required this.data});

  IconData _iconFor(String type) {
    switch (type) {
      case 'plan_approved':
        return Icons.verified_rounded;
      case 'revision':
        return Icons.edit_note_rounded;
      case 'report':
        return Icons.assignment_turned_in_rounded;
      case 'plan':
        return Icons.assignment_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'plan_approved':
        return const Color(0xFF16A34A);
      case 'revision':
        return const Color(0xFFEA580C);
      case 'report':
        return AppPalette.primary;
      case 'plan':
        return const Color(0xFF0D9488);
      default:
        return AppPalette.textSecondary;
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    // Read through safe helpers so legacy notification docs that lack a
    // field never throw 'Bad state: field does not exist'.
    final title = docStr(data, 'title', 'Notification');
    final message = docStr(data, 'message');
    final type = docStr(data, 'type', 'info');
    final read = docBool(data, 'read');
    final rawTs = docVal(data, 'timestamp');

    return Container(
      decoration: BoxDecoration(
        color: read ? Colors.transparent : AppPalette.primary.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: AppPalette.border.withValues(alpha: 0.6)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBubble(icon: _iconFor(type), color: _colorFor(type), size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: read
                              ? AppPalette.textSecondary
                              : AppPalette.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _timeAgo(rawTs is Timestamp ? rawTs : null),
                      style: const TextStyle(
                          fontSize: 10.5, color: AppPalette.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (!read) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFFDC2626), shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}
