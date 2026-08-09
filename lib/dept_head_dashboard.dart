import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as ex;
import 'package:file_saver/file_saver.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'widgets/dept_head_sidebar.dart';
import 'widgets/app_ui.dart';
import 'widgets/notification_bell.dart';
import 'notification_service.dart';
import 'validators.dart';
import 'pdf_reports.dart';
import 'firestore_safe.dart';
import 'change_password.dart';

class _ChartData {
  final String category;
  final double value;
  _ChartData(this.category, this.value);
}

class DeptHeadDashboard extends StatefulWidget {
  const DeptHeadDashboard({super.key});

  @override
  State<DeptHeadDashboard> createState() => _DeptHeadDashboardState();
}

class _DeptHeadDashboardState extends State<DeptHeadDashboard> {
  int _currentIndex = 0;

  // The Department Head's own department (loaded from their profile).
  // Every user they manage and every plan they see is scoped to this.
  String _myDepartment = '';
  String _myName = '';
  bool _deptLoaded = false;

  // Status filter for the Plans & Reports tab
  String _planFilter = 'All';

  // Priority for broadcast announcements
  String _priority = 'Normal';

  // Controllers for the Enterprise Contacts tab
  final TextEditingController _contactsSearchController =
      TextEditingController();
  String _contactsQuery = '';

  // Enterprise registry scope: 'dept' (this department only) or
  // 'all' (college-wide, read-only). Enterprise records are managed
  // centrally by the Dean — Department Heads never add them.
  String _enterpriseScope = 'dept';

  // Controllers for the Broadcast Tool
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _contactsSearchController.dispose();
    super.dispose();
  }

  // Load the logged-in Department Head's department + name so everything
  // downstream (user management, plan visibility, broadcasts) is scoped to it.
  Future<void> _loadMyProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        _myDepartment =
            ((data?['department'] ?? data?['dept'] ?? '').toString()).trim();
        _myName = ((data?['fullName'] ??
                    data?['name'] ??
                    user.displayName ??
                    'Department Head')
                .toString())
            .trim();
        _deptLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _deptLoaded = true);
    }
  }

  // ==================== BROADCAST TOOL ====================
  Future<void> _sendBroadcast() async {
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    try {
      // Published to department_announcements so experts in this department
      // see it live on their My Overview feed (filtered by department).
      await FirebaseFirestore.instance
          .collection('department_announcements')
          .add({
        'title': _subjectController.text,
        'message': _messageController.text,
        'sender': _myName,
        'department':
            _myDepartment, // Scoped to the logged-in Dept Head's department
        'priority': _priority,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Broadcast failed: $e")),
        );
      }
      return;
    }

    if (!mounted) return;
    _subjectController.clear();
    _messageController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Announcement Broadcasted Successfully!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide =
        MediaQuery.of(context).size.width >= AppPalette.desktopBreakpoint;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // On narrow screens the fixed 260px sidebar would crush the content, so
      // it collapses into a hamburger drawer instead of a side rail.
      drawer: isWide
          ? null
          : Drawer(
              width: 260,
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: DeptHeadSidebar(
                currentIndex: _currentIndex,
                onTabSelected: (index) {
                  Navigator.of(context).pop();
                  if (index == 8) {
                    _handleLogout();
                  } else {
                    setState(() => _currentIndex = index);
                  }
                },
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            DeptHeadSidebar(
              currentIndex: _currentIndex,
              onTabSelected: (index) {
                if (index == 8) {
                  _handleLogout();
                } else {
                  setState(() => _currentIndex = index);
                }
              },
            ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(isWide: isWide),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildOverview(), // 0: Overview
                      _buildPlansAndReportsView(), // 1: Plans & Reports
                      _buildEnterpriseContactsView(), // 2: Enterprise Contacts
                      _buildBroadcastTool(), // 3: Broadcast
                      _buildUserManagementView(), // 4: User Management
                      _buildScheduleManagementView(), // 5: Schedule
                      _buildTechFeedbackView(), // 6: Tech & Feedback
                      _buildSettingsView(), // 7: Settings
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({required bool isWide}) {
    return Container(
      height: 74,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 30 : 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppPalette.primary),
                tooltip: "Menu",
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          if (isWide) ...[
            const Icon(Icons.manage_accounts_rounded,
                color: AppPalette.primary, size: 26),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Text(
              "Department Management Portal",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textPrimary),
            ),
          ),
          NotificationBell(
            scope:
                NotificationScope(role: 'deptHead', department: _myDepartment),
          ),
          if (isWide && _myDepartment.isNotEmpty) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppPalette.primary.withValues(alpha: 0.25)),
              ),
              child: Text("${_myDepartment.toUpperCase()} DEPARTMENT",
                  style: const TextStyle(
                      color: AppPalette.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ],
          if (isWide && _myName.isNotEmpty) ...[
            const SizedBox(width: 20),
            Text(_myName.isEmpty ? "Head of Dept" : _myName,
                style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
          const SizedBox(width: 20),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppPalette.primary,
            child: Icon(Icons.person, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  // ==================== OVERVIEW TAB ====================
  Widget _buildOverview() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('expert_plans')
            .where('department', isEqualTo: _myDepartment)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.hasData
              ? snapshot.data!.docs
              : <QueryDocumentSnapshot>[];
          int pending = docs
              .where((d) =>
                  docStr(d, 'status') == 'Pending Dean Review' ||
                  docStr(d, 'status') == 'Pending' ||
                  docStr(d, 'status') == 'Needs Revision')
              .length;
          int approved = docs
              .where((d) =>
                  docStr(d, 'status') == 'Approved' ||
                  docStr(d, 'status') == 'Approved by Dept Head')
              .length;
          int inProgress =
              docs.where((d) => docStr(d, 'status') == 'In Progress').length;
          int completed =
              docs.where((d) => docStr(d, 'status') == 'Completed').length;

          if (_deptLoaded && _myDepartment.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  "No department is assigned to your profile yet.\n"
                  "Ask the Dean to update your user profile with your department.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.blueGrey, fontSize: 15, height: 1.5),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Department Overview",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              Text(
                _myDepartment.isEmpty
                    ? "Loading department profile…"
                    : "Monitor and manage field operations for the $_myDepartment department.",
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _kpiCard("Submitted Plans", "$pending", Icons.assignment,
                      Colors.orange),
                  const SizedBox(width: 20),
                  _kpiCard("Approved", "$approved", Icons.thumb_up_alt_outlined,
                      Colors.green),
                  const SizedBox(width: 20),
                  _kpiCard("Field Visits Active", "$inProgress",
                      Icons.person_pin_circle, Colors.indigo),
                  const SizedBox(width: 20),
                  _kpiCard("Completed Reports", "$completed", Icons.verified,
                      Colors.blue),
                ],
              ),
              const SizedBox(height: 30),
              _buildAnalyticsSection(docs),
              const SizedBox(height: 30),
              const Text("Recent Plans From My Department",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                                "No plans submitted by $_myDepartment experts yet.",
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: docs.length > 5 ? 5 : docs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildMiniPlanTile(doc, data);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniPlanTile(DocumentSnapshot doc, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Pending Dean Review';
    final color = _planStatusColor(status);
    return HoverCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      radius: 12,
      child: Row(
        children: [
          IconBubble(icon: Icons.business, color: AppPalette.primary, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['targetEnterprise'] ?? 'Unknown Enterprise',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  "${data['expertName'] ?? 'Expert'} · ${data['startDate'] ?? '—'} → ${data['endDate'] ?? '—'}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          _statusBadge(status, color),
        ],
      ),
    );
  }

  // ==================== LIVE ANALYTICS CHARTS ====================
  // Donut of plan statuses (department scope) + bar of enterprises by sector.
  Widget _buildAnalyticsSection(List<QueryDocumentSnapshot> plans) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('enterprises')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final entDocs =
            (snapshot.data?.docs ?? <QueryDocumentSnapshot>[]).where((d) {
          if (_myDepartment.isEmpty) return true;
          final dept = docStr(d, 'department');
          return dept.isEmpty || deptMatches(dept, _myDepartment);
        }).toList();
        return Row(
          children: [
            Expanded(
                child:
                    _chartCard('Plan Statuses', _buildPlanStatusDonut(plans))),
            const SizedBox(width: 20),
            Expanded(
                child: _chartCard(
                    'Enterprises by Sector', _buildSectorBarChart(entDocs))),
          ],
        );
      },
    );
  }

  Widget _buildPlanStatusDonut(List<QueryDocumentSnapshot> plans) {
    final buckets = <String, int>{
      'Approved': 0,
      'Pending Review': 0,
      'Revisions': 0,
      'In Progress': 0,
      'Completed': 0,
      'Rejected': 0,
    };
    for (final d in plans) {
      final s = docStr(d, 'status');
      if (s == 'Approved') {
        buckets['Approved'] = buckets['Approved']! + 1;
      } else if (s == 'Approved by Dept Head' ||
          s == 'Pending Dean Review' ||
          s == 'Pending') {
        buckets['Pending Review'] = buckets['Pending Review']! + 1;
      } else if (s == 'Needs Revision' || s == 'Revision Requested') {
        buckets['Revisions'] = buckets['Revisions']! + 1;
      } else if (s == 'In Progress') {
        buckets['In Progress'] = buckets['In Progress']! + 1;
      } else if (s == 'Completed') {
        buckets['Completed'] = buckets['Completed']! + 1;
      } else if (s == 'Rejected') {
        buckets['Rejected'] = buckets['Rejected']! + 1;
      }
    }
    final data = buckets.entries
        .where((e) => e.value > 0)
        .map((e) => _ChartData(e.key, e.value.toDouble()))
        .toList();

    const colors = <String, Color>{
      'Approved': Color(0xFF16A34A),
      'Pending Review': Color(0xFFD97706),
      'Revisions': Color(0xFFEA580C),
      'In Progress': Color(0xFF2563EB),
      'Completed': Color(0xFF7C3AED),
      'Rejected': Color(0xFFDC2626),
    };
    return SfCircularChart(
      legend: const Legend(isVisible: true, position: LegendPosition.bottom),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CircularSeries>[
        DoughnutSeries<_ChartData, String>(
          dataSource: data,
          xValueMapper: (_ChartData d, _) => d.category,
          yValueMapper: (_ChartData d, _) => d.value,
          pointColorMapper: (_ChartData d, _) =>
              colors[d.category] ?? const Color(0xFF64748B),
          dataLabelSettings: const DataLabelSettings(isVisible: true),
          radius: '80%',
          innerRadius: '58%',
        ),
      ],
    );
  }

  Widget _buildSectorBarChart(List<QueryDocumentSnapshot> docs) {
    final counts = <String, int>{};
    for (final d in docs) {
      final s = docStr(d, 'sector', 'Other').trim();
      final key = s.isEmpty ? 'Other' : s;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final data = counts.entries
        .map((e) => _ChartData(e.key, e.value.toDouble()))
        .toList();
    return SfCartesianChart(
      primaryXAxis: const CategoryAxis(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        ColumnSeries<_ChartData, String>(
          dataSource: data,
          xValueMapper: (_ChartData d, _) => d.category,
          yValueMapper: (_ChartData d, _) => d.value,
          color: AppPalette.primary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary),
          ),
          const SizedBox(height: 12),
          Expanded(child: chart),
        ],
      ),
    );
  }

  // ==================== PLANS & REPORTS TAB ====================
  Widget _buildPlansAndReportsView() {
    return Container(
      margin: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined,
                  color: Color(0xFF0D47A1), size: 30),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Plans & Field Reports",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B))),
                  Text(
                    _myDepartment.isEmpty
                        ? "Loading department…"
                        : "Monitor plans, active visits and completed reports from $_myDepartment experts",
                    style: TextStyle(
                        color: Colors.blueGrey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('expert_plans')
                  .where('department', isEqualTo: _myDepartment)
                  .snapshots(),
              builder: (context, snapshot) {
                if (_deptLoaded && _myDepartment.isEmpty) {
                  return const Center(
                    child: Text(
                      "No department is assigned to your profile yet.\n"
                      "Ask the Dean to update your user profile with your department.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.blueGrey, fontSize: 15, height: 1.5),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text("Error loading plans: ${snapshot.error}"));
                }

                final allDocs = snapshot.data?.docs ?? [];

                int countFor(String f) {
                  if (f == 'All') return allDocs.length;
                  if (f == 'Pending Dean Review') {
                    return allDocs
                        .where((d) =>
                            docStr(d, 'status') == 'Pending Dean Review' ||
                            docStr(d, 'status') == 'Pending')
                        .length;
                  }
                  return allDocs.where((d) => docStr(d, 'status') == f).length;
                }

                final filtered = allDocs.where((doc) {
                  final s =
                      (doc.data() as Map<String, dynamic>?)?['status'] ?? '';
                  if (_planFilter == 'All') return true;
                  if (_planFilter == 'Pending Dean Review') {
                    return s == 'Pending Dean Review' || s == 'Pending';
                  }
                  return s == _planFilter;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _planFilterChip('All', countFor('All')),
                        _planFilterChip('Pending Dean Review',
                            countFor('Pending Dean Review')),
                        _planFilterChip('Approved by Dept Head',
                            countFor('Approved by Dept Head')),
                        _planFilterChip('Approved', countFor('Approved')),
                        _planFilterChip(
                            'Needs Revision', countFor('Needs Revision')),
                        _planFilterChip('Rejected', countFor('Rejected')),
                        _planFilterChip('In Progress', countFor('In Progress')),
                        _planFilterChip('Completed', countFor('Completed')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_outlined,
                                      size: 60, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text("No plans with status '$_planFilter'.",
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 15)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final doc = filtered[index];
                                final data = doc.data() as Map<String, dynamic>;
                                return _buildPlanCard(doc, data);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _planFilterChip(String label, int count) {
    final bool selected = _planFilter == label;
    return ChoiceChip(
      label: Text("$label ($count)"),
      selected: selected,
      onSelected: (_) => setState(() => _planFilter = label),
      selectedColor: AppPalette.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.blueGrey,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
          color: selected ? AppPalette.primary : Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }

  // One plan/report card in the Dept Head monitoring tab
  Widget _buildPlanCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    final String status = data['status'] ?? 'Pending Dean Review';
    final Color statusColor = _planStatusColor(status);
    final List<String> tasks =
        _parseTasks(data['tasks'] ?? data['description'] ?? '');

    final checklistRaw = data['taskChecklist'];
    final Map<String, dynamic> checklist = checklistRaw is Map
        ? Map<String, dynamic>.from(checklistRaw)
        : <String, dynamic>{};
    int done = checklist.values.where((v) => v == true).length;

    final comments = data['deptHeadComments'];

    return HoverCard(
      padding: const EdgeInsets.all(20),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: enterprise + expert + status badge
          Row(
            children: [
              IconBubble(
                  icon: Icons.business, color: AppPalette.primary, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['targetEnterprise'] ?? 'Unknown Enterprise',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      "${data['expertName'] ?? data['submittedBy'] ?? 'Expert'} · ${data['department'] ?? _myDepartment}",
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _statusBadge(status, statusColor),
            ],
          ),
          const Divider(height: 24),

          _infoRow(Icons.location_on_outlined, "Target Location",
              data['location'] ?? 'N/A'),
          _infoRow(Icons.calendar_month_outlined, "Visit Dates",
              "${data['startDate'] ?? 'N/A'}  →  ${data['endDate'] ?? 'N/A'}"),
          const SizedBox(height: 12),

          // Planned tasks
          const Text("Planned Tasks / Objectives",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          if (tasks.isEmpty)
            const Text("No tasks listed.",
                style: TextStyle(fontSize: 13, color: Colors.blueGrey))
          else
            ...tasks.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(t, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),

          // Expected outcomes
          if ((data['expectedOutcomes'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text("Expected Outcomes",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Text(data['expectedOutcomes'].toString(),
                style: TextStyle(color: Colors.green.shade800, fontSize: 13)),
          ],

          // Dean's revision feedback (if the Dean sent the plan back)
          if ((data['revisionFeedback'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.feedback_outlined,
                      size: 18, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Dean feedback: ${data['revisionFeedback']}",
                        style: TextStyle(
                            color: Colors.orange.shade900, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],

          // Department Head's own review decision (approve / revision / reject)
          if (status == 'Approved by Dept Head' ||
              status == 'Needs Revision' ||
              status == 'Rejected') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status == 'Rejected'
                    ? Colors.red.shade50
                    : status == 'Needs Revision'
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: status == 'Rejected'
                      ? Colors.red.shade200
                      : status == 'Needs Revision'
                          ? Colors.orange.shade200
                          : Colors.green.shade200,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    status == 'Rejected'
                        ? Icons.block
                        : status == 'Needs Revision'
                            ? Icons.edit_note
                            : Icons.thumb_up_alt_outlined,
                    size: 18,
                    color: status == 'Rejected'
                        ? Colors.red.shade800
                        : status == 'Needs Revision'
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (data['deptHeadFeedback'] ?? '').toString().isNotEmpty
                          ? "Your review: ${data['deptHeadFeedback']}"
                          : "Marked as '$status'.",
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // On-site task progress (for in-progress visits)
          if (status == 'In Progress') ...[
            const SizedBox(height: 12),
            const Text("On-Site Task Checklist",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            if (tasks.isEmpty)
              const Text("No tasks on this plan yet.",
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey))
            else ...[
              Row(
                children: [
                  Text("$done of ${tasks.length} tasks completed",
                      style: const TextStyle(
                          fontSize: 12, color: Colors.blueGrey)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: done / tasks.length,
                backgroundColor: Colors.grey.shade200,
                color: Colors.green,
              ),
            ],
          ],

          // Completed final report summary
          if (status == 'Completed') ...[
            const SizedBox(height: 12),
            if ((data['reportTemplate'] ?? '').toString().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.description_outlined,
                      size: 16, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 6),
                  Text(
                    "Format: ${data['reportTemplate']}",
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const Text("Final Report Summary",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            if (!_deptTemplateSectionsEmpty(data))
              ..._deptTemplateSections(data)
            else if ((data['finalReport'] ?? '').toString().isNotEmpty)
              Text(data['finalReport'].toString(),
                  style: const TextStyle(fontSize: 13, height: 1.4))
            else ...[
              if ((data['tasksPerformed'] ?? '').toString().isNotEmpty)
                Text("Tasks performed: ${data['tasksPerformed']}",
                    style: const TextStyle(fontSize: 13)),
              if ((data['challenges'] ?? '').toString().isNotEmpty)
                Text("Challenges: ${data['challenges']}",
                    style: const TextStyle(fontSize: 13)),
              if ((data['solutionsProvided'] ?? '').toString().isNotEmpty)
                Text("Solutions: ${data['solutionsProvided']}",
                    style: const TextStyle(fontSize: 13)),
            ],
          ],

          // Department Head feedback thread
          if (comments is List && comments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text("Department Head Feedback",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...comments.map<Widget>((raw) {
              final c = raw is Map
                  ? Map<String, dynamic>.from(raw)
                  : <String, dynamic>{};
              final at = c['at'];
              String dateStr = '';
              if (at is Timestamp) {
                final dt = at.toDate();
                dateStr = " · ${dt.day}/${dt.month}/${dt.year}";
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.comment_outlined,
                          size: 16, color: Color(0xFF3730A3)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${c['byName'] ?? c['by'] ?? 'Department Head'}$dateStr",
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3730A3)),
                            ),
                            const SizedBox(height: 2),
                            Text("${c['text'] ?? ''}",
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 5),
              Text(_formatPlanDate(data['timestamp']),
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ],
          ),
          const SizedBox(height: 16),

          // Actions: Approve / Request Revision / Reject (while the plan awaits review)
          if (status == 'Pending Dean Review' ||
              status == 'Pending' ||
              status == 'Revision Requested') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deptHeadDecision(doc, data, 'Revision'),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text("Request Revision"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deptHeadDecision(doc, data, 'Rejected'),
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text("Reject"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _deptHeadDecision(doc, data, 'Approved'),
                    icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                    label: const Text("Approve"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Actions: add feedback (+ view full report when completed)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addDeptHeadFeedback(doc, data),
                  icon: const Icon(Icons.comment_outlined, size: 18),
                  label: Text(status == 'Completed'
                      ? "Comment on Report"
                      : "Add Feedback"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3730A3),
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (status == 'Completed') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCompletedReportDialog(data),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text("View Full Report"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              // PRINT / EXPORT PDF for college archives
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (status == 'Completed') {
                      await printSupportReportPdf(data);
                    } else {
                      await printVisitPlanPdf(data);
                    }
                  },
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text("Export PDF"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D47A1),
                    side: const BorderSide(color: Color(0xFF0D47A1)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Full completed report viewer
  void _showCompletedReportDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(data['targetEnterprise'] ?? "Completed Visit Report"),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Submitted by ${data['expertName'] ?? data['submittedBy'] ?? 'Expert'}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const Divider(height: 24),
                _detailRow("Sector", data['sector']),
                _detailRow("Verified By", data['verifiedBy']),
                _detailRow(
                    "Report Date",
                    _formatTimestamp(
                        data['reportDate'] ?? data['completedAt'])),
                if ((data['reportTemplate'] ?? '').toString().isNotEmpty)
                  _detailRow("Report Format",
                      (data['reportTemplate'] ?? '').toString()),
                const Divider(height: 24),
                if (!_deptTemplateSectionsEmpty(data))
                  ..._deptTemplateSections(data)
                else ...[
                  _reportSection("Tasks Performed", data['tasksPerformed']),
                  _reportSection("Outcomes Achieved", data['outcomesAchieved']),
                  _reportSection("Challenges", data['challenges']),
                  _reportSection(
                      "Solutions Provided", data['solutionsProvided']),
                  _reportSection("Summary Notes", data['finalReport']),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await printSupportReportPdf(data);
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text("Print Report"),
          ),
        ],
      ),
    );
  }

  // Add a Department Head comment to a plan
  void _addDeptHeadFeedback(DocumentSnapshot doc, Map<String, dynamic> data) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Feedback on ${data['targetEnterprise'] ?? 'Plan'}",
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your comment is visible to ${data['expertName'] ?? 'the expert'} and the Dean.",
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: appInputDecoration(
                label: "Comment",
                hint:
                    "e.g., Please prioritize task 2 — the enterprise flagged it as urgent.",
                icon: Icons.comment_outlined,
                alignLabel: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          GradientButton(
            label: "Post Comment",
            icon: Icons.send_rounded,
            width: 170,
            height: 46,
            fontSize: 13,
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final comment = {
                'text': text,
                'by': FirebaseAuth.instance.currentUser?.email ??
                    'Department Head',
                'byName': _myName.isEmpty ? 'Department Head' : _myName,
                'at': FieldValue.serverTimestamp(),
              };
              // Append the comment to the existing thread (avoids arrayUnion +
              // serverTimestamp, which Firestore rejects).
              final planSnap = await doc.reference.get();
              final raw = docVal(planSnap, 'deptHeadComments');
              final comments = raw is List
                  ? raw
                      .map((e) => e is Map
                          ? Map<String, dynamic>.from(e)
                          : <String, dynamic>{})
                      .toList()
                  : <Map<String, dynamic>>[];
              comments.add(comment);
              await doc.reference.update({'deptHeadComments': comments});
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        "Feedback posted. The expert and Dean can see it.")),
              );
            },
          ),
        ],
      ),
    );
  }

  // Department Head approval workflow: Approve / Request Revision / Reject.
  // Writes the new status back to Firestore with an optional comment so the
  // expert sees the decision (and feedback) instantly on their dashboard.
  void _deptHeadDecision(
      DocumentSnapshot doc, Map<String, dynamic> data, String decision) {
    final controller = TextEditingController();
    final bool isApprove = decision == 'Approved';
    final bool isReject = decision == 'Rejected';
    final String status = isApprove
        ? 'Approved by Dept Head'
        : isReject
            ? 'Rejected'
            : 'Needs Revision';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isApprove
              ? "Approve Plan"
              : isReject
                  ? "Reject Plan"
                  : "Request Revision",
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApprove
                  ? "Approve ${data['targetEnterprise'] ?? 'this plan'}? It will move to the Dean for final approval."
                  : isReject
                      ? "Rejecting this plan closes it. ${data['expertName'] ?? 'The expert'} will see the reason."
                      : "Send this plan back to ${data['expertName'] ?? 'the expert'} for changes.",
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText:
                    isApprove ? "Comment (optional)" : "Reason (optional)",
                hintText: isApprove
                    ? "e.g., Looks good — approved. Nice scope."
                    : isReject
                        ? "e.g., Outside the department's mandate for this quarter."
                        : "e.g., Please add more detail on the expected outcomes.",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove
                  ? Colors.green.shade600
                  : isReject
                      ? Colors.redAccent
                      : Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final comment = controller.text.trim();
              await doc.reference.update({
                'status': status,
                'deptHeadFeedback':
                    comment.isEmpty ? FieldValue.delete() : comment,
                'deptHeadReviewedBy':
                    FirebaseAuth.instance.currentUser?.email ??
                        'Department Head',
                'deptHeadReviewedAt': FieldValue.serverTimestamp(),
              });
              final expert = (data['submittedBy'] ?? '').toString();
              if (expert.isNotEmpty) {
                await pushNotification(
                  title: isApprove
                      ? 'Plan Approved by Dept Head'
                      : isReject
                          ? 'Plan Rejected'
                          : 'Revision Requested',
                  message: isApprove
                      ? 'Your visit plan for ${data['targetEnterprise'] ?? 'the enterprise'} was approved by the Department Head.'
                      : isReject
                          ? 'Your visit plan for ${data['targetEnterprise'] ?? 'the enterprise'} was rejected.'
                          : 'Your visit plan for ${data['targetEnterprise'] ?? 'the enterprise'} needs revision.',
                  userId: expert,
                  type: isApprove ? 'plan_approved' : 'revision',
                );
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(isApprove
                        ? "Plan approved — sent to the Dean for final approval."
                        : isReject
                            ? "Plan rejected. The expert can see the reason."
                            : "Revision requested. The expert can see it in their dashboard.")),
              );
            },
            child: Text(isApprove
                ? "Approve Plan"
                : (isReject ? "Reject Plan" : "Send Revision Request")),
          ),
        ],
      ),
    );
  }

  // ==================== USER MANAGEMENT TAB ====================
  Widget _buildUserManagementView() {
    return Container(
      margin: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.manage_accounts_outlined,
                  color: Color(0xFF0D47A1), size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("User Management",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B))),
                    Text(
                      _myDepartment.isEmpty
                          ? "Loading department…"
                          : "Create and manage user accounts for the $_myDepartment department",
                      style: TextStyle(
                          color: Colors.blueGrey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text("Add User"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Strictly scoped to this Dept Head's own department
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('department', isEqualTo: _myDepartment)
                  .snapshots(),
              builder: (context, snapshot) {
                if (_deptLoaded && _myDepartment.isEmpty) {
                  return const Center(
                    child: Text(
                      "No department is assigned to your profile yet.\n"
                      "Ask the Dean to update your user profile with your department.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.blueGrey, fontSize: 15, height: 1.5),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text("Error loading users: ${snapshot.error}"));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off_outlined,
                            size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text("No users found in the $_myDepartment department.",
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(
                            "Use 'Add User' to create accounts for your staff.",
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildUserCard(doc, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    final name =
        (data['fullName'] ?? data['name'] ?? 'Unnamed User').toString();
    final email = (data['email'] ?? 'No email').toString();
    final role = (data['role'] ?? 'expert').toString();
    final isHead = role == 'deptHead' || role == 'Department Head';
    final isDean = role == 'dean' || role == 'Dean';

    return HoverCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      radius: 14,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE0E7FF),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Color(0xFF3730A3),
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(email,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          _roleChip(
            isDean
                ? 'Dean'
                : (isHead ? 'Department Head' : _expertRoleLabel(data)),
            isHead,
            color: isDean ? Colors.deepPurple : null,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.visibility_outlined, color: Colors.blueGrey),
            tooltip: "View Details",
            onPressed: () => _showUserDetailsDialog(data),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF0D47A1)),
            tooltip: "Edit User",
            onPressed: () => _showEditUserDialog(doc, data),
          ),
        ],
      ),
    );
  }

  // Create a brand-new login account for a user in this department
  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'expert';
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
              role == 'dean'
                  ? "Add College-wide Dean"
                  : "Add User to $_myDepartment",
              textAlign: TextAlign.center),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "A sign-in account will be created. Experts & Department Heads are assigned to $_myDepartment; Dean accounts are college-wide (all departments).",
                    style:
                        const TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: nameController,
                    decoration: appInputDecoration(
                        label: "Full Name", icon: Icons.person_outline),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: appInputDecoration(
                        label: "College Email", icon: Icons.email_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: appInputDecoration(
                      label: "Temporary Password",
                      icon: Icons.lock_outline,
                      hint:
                          "Share this securely — the user can change it later.",
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    items: const [
                      DropdownMenuItem(value: 'expert', child: Text("Expert")),
                      DropdownMenuItem(
                          value: 'deptHead', child: Text("Department Head")),
                      DropdownMenuItem(value: 'dean', child: Text("Dean")),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => role = v ?? 'expert'),
                    decoration: appInputDecoration(
                        label: "Role",
                        icon: Icons.admin_panel_settings_outlined),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            GradientButton(
              label: saving ? "Creating…" : "Create Account",
              icon: Icons.person_add_alt_1_rounded,
              width: 180,
              height: 46,
              fontSize: 13,
              onPressed: saving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty ||
                          emailController.text.trim().isEmpty ||
                          passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text("Please fill in all fields")),
                        );
                        return;
                      }
                      final emailError = emailField(emailController.text);
                      if (emailError != null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(emailError)),
                        );
                        return;
                      }
                      if (passwordController.text.length < 6) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Password must be at least 6 characters")),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        // 1. Create the Firebase Auth account (so the user can log in)
                        final cred = await FirebaseAuth.instance
                            .createUserWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );
                        // 2. Create the profile — Experts & Dept Heads get this dept,
                        //    Deans are college-wide (All / College Administration).
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(cred.user!.uid)
                            .set({
                          'uid': cred.user!.uid,
                          'fullName': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'role': role,
                          'department': role == 'dean'
                              ? 'College Administration'
                              : _myDepartment,
                          'createdBy': FirebaseAuth.instance.currentUser?.uid,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(role == 'dean'
                                  ? "Dean account created — it's college-wide and won't appear in this department's list."
                                  : "User account created — they can now sign in!")),
                        );
                      } on FirebaseAuthException catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                              content:
                                  Text(e.message ?? "Could not create user")),
                        );
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text("Error: $e")),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // Edit a user's name/role (department stays locked to this Dept Head's dept)
  void _showEditUserDialog(DocumentSnapshot doc, Map<String, dynamic> data) {
    final nameController = TextEditingController(
        text: (data['fullName'] ?? data['name'] ?? '').toString());
    final email = (data['email'] ?? '').toString();
    String role = (data['role'] ?? 'expert').toString();
    if (role == 'Department Head' || role == 'deptHead') {
      role = 'deptHead';
    } else if (role == 'Dean' || role == 'dean') {
      role = 'dean';
    } else {
      role = 'expert';
    }
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Edit User", textAlign: TextAlign.center),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: appInputDecoration(
                      label: "Full Name", icon: Icons.person_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: email),
                  readOnly: true,
                  decoration: appInputDecoration(
                    label: "Email (sign-in ID)",
                    icon: Icons.email_outlined,
                    hint:
                        "Email can't be changed here — use password reset for access issues.",
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'expert', child: Text("Expert")),
                    DropdownMenuItem(
                        value: 'deptHead', child: Text("Department Head")),
                    DropdownMenuItem(value: 'dean', child: Text("Dean")),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'expert'),
                  decoration: appInputDecoration(
                      label: "Role", icon: Icons.admin_panel_settings_outlined),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance
                            .sendPasswordResetEmail(email: email);
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                              content:
                                  Text("Password reset email sent to $email")),
                        );
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                              content: Text("Could not send reset email: $e")),
                        );
                      }
                    },
                    icon: const Icon(Icons.password, size: 18),
                    label: const Text("Send Password Reset Email"),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            GradientButton(
              label: saving ? "Saving…" : "Save Changes",
              icon: Icons.save_rounded,
              width: 180,
              height: 46,
              fontSize: 13,
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(doc.id)
                          .update({
                        'fullName': nameController.text.trim(),
                        'role': role,
                        // Deans are college-wide; everyone else stays in this Dept Head's department
                        'department': role == 'dean'
                            ? 'College Administration'
                            : _myDepartment,
                      });
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("User updated successfully")),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  // Dynamic expert role label, e.g. "ICT Expert", built from the user's
  // assigned department so the role reads naturally in the UI.
  String _expertRoleLabel(Map<String, dynamic> data) {
    final dept =
        ((data['department'] ?? data['dept'] ?? _myDepartment).toString())
            .trim();
    return dept.isEmpty ? 'Expert' : '$dept Expert';
  }

  // Read-only profile details
  void _showUserDetailsDialog(Map<String, dynamic> data) {
    final name =
        (data['fullName'] ?? data['name'] ?? 'Unnamed User').toString();
    final role = (data['role'] ?? 'expert').toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow("Email", (data['email'] ?? 'N/A').toString()),
            _detailRow(
                "Role",
                role == 'dean' || role == 'Dean'
                    ? 'Dean'
                    : (role == 'deptHead' || role == 'Department Head'
                        ? 'Department Head'
                        : _expertRoleLabel(data))),
            _detailRow("Department", (data['department'] ?? 'N/A').toString()),
            _detailRow("Created", _formatTimestamp(data['createdAt'])),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  // ==================== BROADCAST TOOL TAB ====================
  Widget _buildBroadcastTool() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Broadcast Announcement",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textPrimary)),
          const SizedBox(height: 6),
          Text(
            "Send an announcement to all experts in the $_myDepartment department.",
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GlassCard(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _subjectController,
                  decoration: appInputDecoration(
                    label: "Subject",
                    icon: Icons.title,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _messageController,
                  maxLines: 5,
                  decoration: appInputDecoration(
                    label: "Message Body",
                    icon: Icons.message_outlined,
                    alignLabel: true,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text("Priority: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _priority,
                      items: ['High', 'Normal', 'Low']
                          .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _priority = v ?? 'Normal'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: "Send to $_myDepartment Staff",
                  icon: Icons.send_rounded,
                  onPressed: _sendBroadcast,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SCHEDULE MANAGEMENT (weekly visit schedules) ====================

  static const List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  Widget _buildScheduleManagementView() {
    return Container(
      margin: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  color: Color(0xFF0D47A1), size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Weekly Visit Schedules",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B))),
                    Text(
                      _myDepartment.isEmpty
                          ? "Assign weekly enterprise visits to your department experts"
                          : "Assign weekly enterprise visits to $_myDepartment experts",
                      style: TextStyle(
                          color: Colors.blueGrey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
              GradientButton(
                label: "Create Schedule",
                icon: Icons.add_circle_outline_rounded,
                width: 180,
                height: 46,
                fontSize: 13,
                onPressed: () => _showScheduleDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('expert_schedules')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text("Error loading schedules: ${snapshot.error}"));
                }
                final docs = (snapshot.data?.docs ?? []).where((d) {
                  final dept = ((d.data() as Map<String, dynamic>?)?['department']
                          ?? '')
                      .toString();
                  if (dept.isEmpty) return true;
                  return _deptMatches(dept, _myDepartment);
                }).toList();
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_outlined,
                            size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text("No schedules assigned yet.",
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                            "Use “Create Schedule” to assign weekly visits to your experts.",
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return _buildScheduleCard(
                        doc, doc.data() as Map<String, dynamic>);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    final daysRaw = data['days'];
    final dayList = daysRaw is List
        ? daysRaw.map((e) => e.toString()).toList()
        : <String>[];
    return HoverCard(
      padding: const EdgeInsets.all(18),
      radius: 14,
      child: Row(
        children: [
          IconBubble(
              icon: Icons.event_repeat_rounded,
              color: AppPalette.primary,
              size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (data['enterpriseName'] ?? 'Unknown Enterprise')
                            .toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    StatusChip(
                        (data['department'] ?? 'General').toString(),
                        color: AppPalette.teal),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Expert: ${data['expertName'] ?? '—'}  ·  ${_fmtSchedDate(data['startDate'])} → ${_fmtSchedDate(data['endDate'])}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                if (dayList.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: dayList.map((d) => _dayChip(d)).toList(),
                  ),
                if ((data['objectives'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text((data['objectives'] ?? '').toString(),
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                tooltip: 'Edit Schedule',
                onPressed: () => _showScheduleDialog(existing: doc, data: data),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Delete Schedule',
                onPressed: () => _deleteSchedule(doc, data),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayChip(String day) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.25)),
      ),
      child: Text(day,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppPalette.primary)),
    );
  }

  String _fmtSchedDate(Object? raw) {
    if (raw == null) return '—';
    final s = raw.toString();
    if (s.isEmpty) return '—';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  void _deleteSchedule(DocumentSnapshot doc, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Schedule?', textAlign: TextAlign.center),
        content: Text(
            "Remove the weekly schedule for ${data['enterpriseName'] ?? 'this enterprise'} assigned to ${data['expertName'] ?? 'this expert'}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppPalette.textMuted))),
          GradientButton(
            label: 'Delete',
            icon: Icons.delete_forever_rounded,
            width: 130,
            height: 44,
            fontSize: 13,
            colors: const [Color(0xFFF87171), Color(0xFFDC2626)],
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(context);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Schedule deleted.')),
              );
            },
          ),
        ],
      ),
    );
  }

  // Create / edit dialog. Expert + enterprise dropdowns are loaded from the
  // central databases (users + enterprises collections).
  void _showScheduleDialog(
      {DocumentSnapshot? existing, Map<String, dynamic>? data}) {
    final isEdit = existing != null;
    // ID-based selection, null until a valid option is chosen. The dropdown
    // value must match an item id exactly (or be null), otherwise Flutter
    // throws 'DropdownButton assertion failed: value'.
    String? selectedExpertId = (data?['expertId'] ?? '').toString().isEmpty
        ? null
        : (data?['expertId'] ?? '').toString();
    String? selectedEnterpriseId =
        (data?['enterpriseId'] ?? '').toString().isEmpty
            ? null
            : (data?['enterpriseId'] ?? '').toString();
    final objectivesController =
        TextEditingController(text: (data?['objectives'] ?? '').toString());
    final startController =
        TextEditingController(text: (data?['startDate'] ?? '').toString());
    final endController =
        TextEditingController(text: (data?['endDate'] ?? '').toString());
    final daysRaw = data?['days'];
    final selectedDays = daysRaw is List
        ? daysRaw.map((e) => e.toString()).toSet()
        : <String>{};
    bool saving = false;
    // Loaded option lists (assigned by the FutureBuilder) — the save handler
    // resolves the selected ids back to names / emails / woredas from these.
    List<Map<String, dynamic>> loadedEnterprises = [];
    List<Map<String, dynamic>> loadedExperts = [];

    Future<Map<String, List<Map<String, dynamic>>>> loadOptions() async {
      final entSnap = await FirebaseFirestore.instance
          .collection('enterprises')
          .get();
      final userSnap =
          await FirebaseFirestore.instance.collection('users').get();
      final enterprises = <Map<String, dynamic>>[];
      for (final d in entSnap.docs) {
        final m = d.data();
        final name = (m['entName'] ?? '').toString();
        if (name.isEmpty) continue;
        enterprises.add({
          'name': name,
          'woreda': (m['woreda'] ?? '').toString(),
          'id': d.id, // the enterprise doc id — for exact schedule matching
        });
      }
      final experts = <Map<String, dynamic>>[];
      for (final d in userSnap.docs) {
        final m = d.data();
        final role = (m['role'] ?? '').toString();
        if (role != 'expert' && role != 'Expert') continue;
        final dept = (m['department'] ?? '').toString();
        if (_myDepartment.isNotEmpty && !_deptMatches(dept, _myDepartment)) {
          continue;
        }
        final name = ((m['fullName'] ?? m['name'] ?? '').toString()).trim();
        if (name.isEmpty) continue;
        experts.add({
          'name': name,
          'email': (m['email'] ?? '').toString(),
          'id': d.id, // the expert's Firebase Auth uid
        });
      }
      return {'enterprises': enterprises, 'experts': experts};
    }

    // Hoist the future so the dialog doesn't refetch Firestore on every
    // setDialogState rebuild (day-chip tap, dropdown change, etc.).
    final optionsFuture = loadOptions();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Column(
            children: [
              IconBubble(
                  icon: Icons.event_repeat_rounded,
                  color: AppPalette.primary,
                  size: 52),
              const SizedBox(height: 12),
              Text(isEdit ? 'Edit Schedule' : 'Create Weekly Schedule',
                  textAlign: TextAlign.center),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
              future: optionsFuture,
              builder: (context, opts) {
                if (opts.hasError) {
                  return const SizedBox(
                    height: 220,
                    child: Center(
                        child: Text('Could not load schedule options. Please try again.')),
                  );
                }
                if (!opts.hasData) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final enterprises = opts.data!['enterprises']!;
                final experts = opts.data!['experts']!;
                loadedEnterprises = enterprises;
                loadedExperts = experts;

                // Legacy schedules store names but no ids — resolve the id
                // from the stored name so the edit dialog still pre-selects.
                if (selectedExpertId == null) {
                  final legacyName =
                      normDept((data?['expertName'] ?? '').toString());
                  if (legacyName.isNotEmpty) {
                    for (final e in experts) {
                      if (normDept(e['name'].toString()) == legacyName) {
                        selectedExpertId = e['id'].toString();
                        break;
                      }
                    }
                  }
                }
                if (selectedEnterpriseId == null) {
                  final legacyName =
                      normDept((data?['enterpriseName'] ?? '').toString());
                  if (legacyName.isNotEmpty) {
                    for (final e in enterprises) {
                      if (normDept(e['name'].toString()) == legacyName) {
                        selectedEnterpriseId = e['id'].toString();
                        break;
                      }
                    }
                  }
                }
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (experts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            "No experts registered in ${_myDepartment.isEmpty ? 'your department' : _myDepartment} yet. Add them in User Management first.",
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        // Null-safe: if the stored id isn't in the loaded
                        // list, fall back to null so the dropdown never asserts.
                        value: experts.any(
                                (e) => e['id'].toString() == selectedExpertId)
                            ? selectedExpertId
                            : null,
                        items: experts
                            .map((e) => DropdownMenuItem<String>(
                                value: e['id'].toString(),
                                child: Text(e['name'].toString())))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedExpertId = v),
                        decoration: appInputDecoration(
                            label: 'Assigned Expert',
                            icon: Icons.person_outline),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        // Same null-safe check as the expert dropdown.
                        value: enterprises.any((e) =>
                                e['id'].toString() == selectedEnterpriseId)
                            ? selectedEnterpriseId
                            : null,
                        items: enterprises
                            .map((e) => DropdownMenuItem<String>(
                                value: e['id'].toString(),
                                child: Text(e['name'].toString())))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedEnterpriseId = v),
                        decoration: appInputDecoration(
                            label: 'Target Enterprise',
                            icon: Icons.business_outlined),
                      ),
                      const SizedBox(height: 12),
                      const Text('Scheduled Days (up to 2)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.textPrimary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _weekDays.map((day) {
                          final on = selectedDays.contains(day);
                          return FilterChip(
                            label: Text(day),
                            selected: on,
                            onSelected: (sel) => setDialogState(() {
                              if (sel) {
                                if (selectedDays.length < 2) {
                                  selectedDays.add(day);
                                }
                              } else {
                                selectedDays.remove(day);
                              }
                            }),
                            selectedColor: AppPalette.primary,
                            labelStyle: TextStyle(
                              color: on
                                  ? Colors.white
                                  : AppPalette.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: AppPalette.inputFill,
                            side: BorderSide(
                                color: on
                                    ? AppPalette.primary
                                    : AppPalette.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            showCheckmark: false,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: _schedDateField(
                                  startController, setDialogState, 'Start Date')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _schedDateField(
                                  endController, setDialogState, 'End Date')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: objectivesController,
                        maxLines: 3,
                        decoration: appInputDecoration(
                          label: 'Objective Notes',
                          icon: Icons.notes_rounded,
                          alignLabel: true,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel',
                  style: TextStyle(color: AppPalette.textMuted)),
            ),
            GradientButton(
              label: saving
                  ? 'Saving…'
                  : (isEdit ? 'Update Schedule' : 'Create Schedule'),
              icon: Icons.save_rounded,
              width: 190,
              height: 46,
              fontSize: 13,
              onPressed: saving
                  ? null
                  : () async {
                      if (selectedExpertId == null ||
                          selectedEnterpriseId == null ||
                          selectedDays.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please pick an expert, an enterprise and at least one day')),
                        );
                        return;
                      }
                      // Resolve the selected ids back to their records.
                      Map<String, dynamic>? expertEntry;
                      for (final e in loadedExperts) {
                        if (e['id'].toString() == selectedExpertId) {
                          expertEntry = e;
                          break;
                        }
                      }
                      Map<String, dynamic>? entEntry;
                      for (final e in loadedEnterprises) {
                        if (e['id'].toString() == selectedEnterpriseId) {
                          entEntry = e;
                          break;
                        }
                      }
                      if (expertEntry == null || entEntry == null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'The selected expert or enterprise is no longer available. Please pick again.')),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final payload = <String, dynamic>{
                          'expertName': expertEntry['name'],
                          'expertEmail': expertEntry['email'] ?? '',
                          'expertId': expertEntry['id'],
                          'enterpriseName': entEntry['name'],
                          'enterpriseId': entEntry['id'],
                          'enterpriseWoreda': entEntry['woreda'] ?? '',
                          'department': _myDepartment,
                          'days': selectedDays.toList(),
                          'startDate': startController.text,
                          'endDate': endController.text,
                          'objectives': objectivesController.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        if (isEdit) {
                          await FirebaseFirestore.instance
                              .collection('expert_schedules')
                              .doc(existing.id)
                              .update(payload);
                        } else {
                          await FirebaseFirestore.instance
                              .collection('expert_schedules')
                              .add({
                            ...payload,
                            'createdBy':
                                FirebaseAuth.instance.currentUser?.uid,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(isEdit
                                  ? 'Schedule updated.'
                                  : 'Schedule created.')),
                        );
                      } catch (e) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Save failed: $e')),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _schedDateField(
      TextEditingController ctrl, StateSetter setDialogState, String label) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 3),
          helpText: 'Select Date',
        );
        if (picked != null) {
          setDialogState(
              () => ctrl.text = DateFormat('yyyy-MM-dd').format(picked));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: appInputDecoration(
          label: label,
          icon: Icons.calendar_month_rounded,
          suffixIcon:
              const Icon(Icons.arrow_drop_down, color: AppPalette.textMuted),
        ),
        child: Text(
          ctrl.text.isEmpty ? 'Select date' : ctrl.text,
          style: TextStyle(
            color: ctrl.text.isEmpty
                ? AppPalette.textMuted
                : AppPalette.textPrimary,
            fontWeight: ctrl.text.isEmpty ? FontWeight.w400 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ==================== TECH & FEEDBACK TAB (department-scoped) ====================
  Widget _buildTechFeedbackView() {
    return Container(
      margin: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.biotech_outlined,
                  color: Color(0xFF0D47A1), size: 30),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tech Proposals & Expert Feedback",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B))),
                  Text(
                    _myDepartment.isEmpty
                        ? "Loading department…"
                        : "Candidate technologies and support requests from $_myDepartment experts",
                    style: TextStyle(
                        color: Colors.blueGrey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                // ---- PROPOSED TECHNOLOGIES ----
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.teal, size: 22),
                    const SizedBox(width: 8),
                    const Text("Proposed Technologies",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                _deptScopedStream(
                  collection: 'proposed_technologies',
                  emptyText: _myDepartment.isEmpty
                      ? "No technology proposals from your department yet."
                      : "No technology proposals from $_myDepartment experts yet.",
                  itemBuilder: (data) => _techProposalCard(data),
                ),
                const SizedBox(height: 30),

                // ---- EXPERT FEEDBACK / SUPPORT REQUESTS ----
                Row(
                  children: [
                    const Icon(Icons.feedback_outlined,
                        color: Colors.indigo, size: 22),
                    const SizedBox(width: 8),
                    const Text("Expert Feedback / Support Requests",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                _deptScopedStream(
                  collection: 'expert_feedbacks',
                  emptyText: _myDepartment.isEmpty
                      ? "No feedback or support requests from your department yet."
                      : "No feedback or support requests from $_myDepartment experts yet.",
                  itemBuilder: (data) => _feedbackCard(data),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Shared department-scoped stream for tech proposals + expert feedback.
  // Every query carries .where('department', isEqualTo: deptHeadDepartment).
  Widget _deptScopedStream({
    required String collection,
    required String emptyText,
    required Widget Function(Map<String, dynamic> data) itemBuilder,
  }) {
    if (_deptLoaded && _myDepartment.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "No department is assigned to your profile yet.\n"
          "Ask the Dean to update your user profile with your department.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blueGrey, fontSize: 14, height: 1.5),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('department', isEqualTo: _myDepartment)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text("Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent)),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(emptyText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ),
          );
        }
        // Newest-first, sorted client-side (index-free, like the rest of the app)
        final sorted = [...docs]..sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>?)?['timestamp'];
            final tb = (b.data() as Map<String, dynamic>?)?['timestamp'];
            if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
            return 0;
          });
        return Column(
          children: [
            for (final doc in sorted)
              itemBuilder(doc.data() as Map<String, dynamic>),
          ],
        );
      },
    );
  }

  // One candidate-technology card
  Widget _techProposalCard(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'Pending').toString();
    final color = status == 'Approved' ? Colors.green : Colors.orange;
    final String dateStr = _formatTimestamp(data['timestamp']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(data['techName'] ?? 'Unnamed Technology',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              _statusBadge(status, color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "${data['category'] ?? 'General'}${(data['useCase'] ?? '').toString().isNotEmpty ? ' — ${data['useCase']}' : ''}",
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          if ((data['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(data['description'].toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
          ],
          if ((data['reportTemplate'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Format: ${data['reportTemplate']}",
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text(data['expertName'] ?? data['submittedBy'] ?? 'Expert',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              const Spacer(),
              const Icon(Icons.schedule, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text(dateStr,
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ],
          ),
        ],
      ),
    );
  }

  // One expert feedback / support request card
  Widget _feedbackCard(Map<String, dynamic> data) {
    final String dateStr = _formatTimestamp(data['timestamp']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(data['subject'] ?? 'Feedback',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              _statusBadge('Open', Colors.orange),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.indigo.withOpacity(0.3)),
            ),
            child: Text(data['category'] ?? 'General Feedback',
                style: const TextStyle(
                    color: Colors.indigo,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          if ((data['message'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(data['message'].toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontSize: 13,
                    height: 1.4)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text(data['userEmail'] ?? 'Expert',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              const Spacer(),
              const Icon(Icons.schedule, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text(dateStr,
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ],
          ),
        ],
      ),
    );
  }

  // ============ ENTERPRISE REGISTRY TAB (shared 'enterprises' collection — dept or college-wide) ============

  // Export the enterprise registry to Excel — same layout & fields as the
  // Dean's export, following the active view scope (department or all college).
  Future<void> _exportDeptEnterprises() async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheetObject = excel['Enterprise_Report'];
    excel.delete('Sheet1');

    List<ex.CellValue> headers = [
      ex.TextCellValue("LMIS #"),
      ex.TextCellValue("Enterprise Name"),
      ex.TextCellValue("Representative"),
      ex.TextCellValue("Phone"),
      ex.TextCellValue("Sector"),
      ex.TextCellValue("Sub-Sector"),
      ex.TextCellValue("Woreda"),
      ex.TextCellValue("Male"),
      ex.TextCellValue("Female"),
      ex.TextCellValue("Total"),
      ex.TextCellValue("Department"),
    ];
    sheetObject.appendRow(headers);

    final snapshot =
        await FirebaseFirestore.instance.collection('enterprises').get();
    // Export whatever scope is active: this department or all college.
    final docs = snapshot.docs.where((d) {
      if (_enterpriseScope == 'all') return true;
      return _deptMatches(
          ((d.data() as Map<String, dynamic>?)?['department'] ?? '').toString(),
          _myDepartment);
    }).toList();

    for (var doc in docs) {
      final data = doc.data();
      sheetObject.appendRow([
        ex.TextCellValue(data['lmis'] ?? ""),
        ex.TextCellValue(data['entName'] ?? ""),
        ex.TextCellValue(data['repName'] ?? ""),
        ex.TextCellValue(data['phone'] ?? ""),
        ex.TextCellValue(data['sector'] ?? ""),
        ex.TextCellValue(data['subSector'] ?? ""),
        ex.TextCellValue(data['woreda'] ?? ""),
        ex.IntCellValue(data['maleCount'] ?? 0),
        ex.IntCellValue(data['femaleCount'] ?? 0),
        ex.IntCellValue(data['totalCount'] ?? 0),
        ex.TextCellValue(data['department'] ?? _myDepartment),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      await FileSaver.instance.saveFile(
        name: _enterpriseScope == 'all'
            ? "GIC_All_College_Enterprise_Registry"
            : "GIC_${_myDepartment.isEmpty ? 'Department' : _myDepartment}_Enterprise_Registry",
        bytes: Uint8List.fromList(fileBytes),
        ext: "xlsx",
        mimeType: MimeType.microsoftExcel,
      );
    }
  }

  // Full enterprise details dialog (identical to the Dean's)
  void _showEnterpriseDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(data['entName'] ?? "Enterprise Details"),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _detailRow("LMIS Number", data['lmis']),
                _detailRow("Representative", data['repName']),
                _detailRow("Phone", data['phone']),
                const Divider(),
                _detailRow("Main Sector", data['sector']),
                _detailRow("Sub Sector", data['subSector']),
                _detailRow("Woreda", data['woreda']),
                const Divider(),
                _detailRow("Male Count", data['maleCount']?.toString()),
                _detailRow("Female Count", data['femaleCount']?.toString()),
                _detailRow("Total Operators", data['totalCount']?.toString(),
                    isBold: true),
                const Divider(),
                _detailRow("Initial Capital",
                    formatInitialCapital(data['initialCapital']),
                    isBold: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  // The Dean's exact table design, scoped to this Dept Head's own department.
  Widget _buildEnterpriseContactsView() {
    return Container(
      margin: const EdgeInsets.all(30),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          // --- HEADER & SEARCH BAR ---
          Wrap(
            spacing: 12,
            runSpacing: 14,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Enterprise Registry",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _contactsSearchController,
                  decoration: InputDecoration(
                    hintText: "Search by Name or LMIS...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    suffixIcon: _contactsQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _contactsSearchController.clear();
                              setState(() => _contactsQuery = "");
                            })
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() => _contactsQuery = value.toLowerCase());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- SCOPE TOGGLE: department-only vs college-wide read-only ---
          Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'dept',
                    label: Text("My Department"),
                    icon: Icon(Icons.account_tree_outlined, size: 17),
                  ),
                  ButtonSegment(
                    value: 'all',
                    label: Text("All College (Read Only)"),
                    icon: Icon(Icons.public, size: 17),
                  ),
                ],
                selected: {_enterpriseScope},
                onSelectionChanged: (s) =>
                    setState(() => _enterpriseScope = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _enterpriseScope == 'all'
                      ? "Read-only view of every enterprise registered by the Dean."
                      : (_myDepartment.isEmpty
                          ? "Enterprises owned by your department — managed centrally by the Dean."
                          : "Enterprises owned by $_myDepartment — managed centrally by the Dean."),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- FILTERED DATA TABLE ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('enterprises')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // The department-only view needs a department on the profile;
                // the college-wide view works for everyone.
                if (_enterpriseScope == 'dept' &&
                    _deptLoaded &&
                    _myDepartment.isEmpty) {
                  return const Center(
                    child: Text(
                      "No department is assigned to your profile yet.\n"
                      "Ask the Dean to update your user profile with your department.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.blueGrey, fontSize: 15, height: 1.5),
                    ),
                  );
                }
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                // Same collection & schema as the Dean — one source of truth.
                // Scoped client-side with case-insensitive, trimmed matching,
                // or shown college-wide when the "All College" view is active.
                final deptDocs = snapshot.data!.docs.where((d) {
                  if (_enterpriseScope == 'all') return true;
                  return _deptMatches(
                      ((d.data() as Map<String, dynamic>?)?['department'] ?? '')
                          .toString(),
                      _myDepartment);
                }).toList();

                final filteredDocs = deptDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['entName'] ?? "").toString().toLowerCase();
                  final lmis = (data['lmis'] ?? "").toString().toLowerCase();
                  return name.contains(_contactsQuery) ||
                      lmis.contains(_contactsQuery);
                }).toList();

                return Column(
                  children: [
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
                              child: Text(
                                _enterpriseScope == 'all'
                                    ? "No enterprises registered in the college registry yet."
                                    : (_contactsQuery.isEmpty
                                        ? "No enterprises registered in the $_myDepartment department yet.\nEnterprise records are added by the Dean."
                                        : "No enterprises found matching '$_contactsQuery'"),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 15,
                                    height: 1.5),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: [
                                    const DataColumn(label: Text("LMIS #")),
                                    const DataColumn(label: Text("Name")),
                                    const DataColumn(label: Text("Sector")),
                                    if (_enterpriseScope == 'all')
                                      const DataColumn(
                                          label: Text("Department")),
                                    const DataColumn(label: Text("Model?")),
                                    const DataColumn(label: Text("Actions")),
                                  ],
                                  rows: filteredDocs.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final bool isModel =
                                        data['isModel'] ?? false;
                                    final String phone =
                                        (data['phone'] ?? '').toString();
                                    final String email =
                                        (data['email'] ?? '').toString();
                                    return DataRow(cells: [
                                      DataCell(Text(data['lmis'] ?? "")),
                                      DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                              child:
                                                  Text(data['entName'] ?? "")),
                                          if (isModel) ...[
                                            const SizedBox(width: 8),
                                            _entBadge("Model Enterprise",
                                                Colors.amber),
                                          ],
                                        ],
                                      )),
                                      DataCell(Text(data['sector'] ?? "")),
                                      if (_enterpriseScope == 'all')
                                        DataCell(Text(
                                          (data['department'] ?? '—')
                                              .toString(),
                                          style: const TextStyle(fontSize: 13),
                                        )),
                                      DataCell(Icon(
                                        isModel
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: isModel
                                            ? Colors.amber
                                            : Colors.grey.shade400,
                                        size: 20,
                                      )),
                                      DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility,
                                                color: Colors.blue),
                                            onPressed: () =>
                                                _showEnterpriseDetails(data),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.call,
                                                color: Colors.green),
                                            onPressed: phone.isEmpty
                                                ? null
                                                : () => _callContact(phone),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.mail_outline,
                                                color: Colors.indigo),
                                            onPressed: email.isEmpty
                                                ? null
                                                : () => _emailContact(email),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.print_outlined,
                                                color: Color(0xFF0D47A1)),
                                            onPressed: () =>
                                                printEnterpriseDetailsPdf(data),
                                          ),
                                        ],
                                      )),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),

                    // --- THE COUNTER FOOTER ---
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                            _contactsQuery.isEmpty
                                ? "Total Records: ${deptDocs.length}"
                                : "Found ${filteredDocs.length} of ${deptDocs.length} enterprises",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _exportDeptEnterprises,
                            icon: const Icon(Icons.file_download),
                            label: const Text("Export to Excel"),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Small pill badge (e.g., Model Enterprise)
  Widget _entBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  // Call the contact's direct phone number
  Future<void> _callContact(String phone) async {
    final uri =
        Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open the dialer for $phone")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open the dialer: $e")),
        );
      }
    }
  }

  // Compose an email to the contact
  Future<void> _emailContact(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open your email app")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open email: $e")),
        );
      }
    }
  }

  Widget _buildSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.settings_suggest_rounded,
            title: 'Account Settings',
            subtitle: 'Manage your account security and session.',
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBubble(
                        icon: Icons.lock_reset_rounded,
                        color: AppPalette.primary,
                        size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Account Security',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                            _myName.isEmpty
                                ? 'Keep your account safe.'
                                : 'Signed in as $_myName',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppPalette.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                const Text(
                  'Update your password to keep your account secure. You will be asked for your current password to confirm the change.',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: AppPalette.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Change Password',
                  icon: Icons.lock_reset_rounded,
                  height: 48,
                  fontSize: 14,
                  onPressed: _changePassword,
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Logout Account',
                  icon: Icons.logout_rounded,
                  height: 48,
                  fontSize: 14,
                  colors: const [Color(0xFFF87171), Color(0xFFDC2626)],
                  onPressed: _handleLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final changed = await showChangePasswordDialog(context);
    if (changed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    }
  }

  void _handleLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // ==================== SHARED HELPERS ====================

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: MetricCard(
        title: title,
        value: value,
        subtitle: '',
        icon: icon,
        color: color,
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text("$label:  ",
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return StatusChip(status, color: color);
  }

  // Normalize a department string: trim surrounding whitespace and lowercase it
  // so 'Construction', 'construction' and ' CONSTRUCTION ' all compare equal.  // Case-insensitive, trimmed department match (reuses the shared helper
  // from firestore_safe.dart so Dean and Department Head views agree).
  bool _deptMatches(String? a, String? b) => normDept(a) == normDept(b);

  Color _planStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Approved by Dept Head':
        return Colors.teal;
      case 'Needs Revision':
        return Colors.orange;
      case 'Revision Requested':
        return Colors.redAccent;
      case 'Rejected':
        return Colors.redAccent;
      case 'Completed':
        return Colors.blue;
      case 'In Progress':
        return Colors.indigo;
      default:
        return Colors.orange; // Pending Dean Review / legacy Pending
    }
  }

  Widget _roleChip(String label, bool isHead, {Color? color}) {
    final c =
        color ?? (isHead ? const Color(0xFF3730A3) : const Color(0xFF0D47A1));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(label,
          style:
              TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _detailRow(String label, String? value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey)),
          Text(value ?? "N/A",
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  // Render structured template sections with formatted headers (new reports)
  List<Widget> _deptTemplateSections(Map<String, dynamic> data) {
    final raw = data['templateSections'];
    if (raw is! Map || raw.isEmpty) return const [];
    final entries = raw.entries
        .where((e) => (e.value ?? '').toString().trim().isNotEmpty)
        .toList();
    if (entries.isEmpty) return const [];
    return [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.key,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1))),
              const SizedBox(height: 4),
              Text((e.value ?? '').toString().trim(),
                  style: const TextStyle(fontSize: 13, height: 1.5)),
            ],
          ),
        ),
    ];
  }

  // True when the report has no structured template sections (legacy report)
  bool _deptTemplateSectionsEmpty(Map<String, dynamic> data) {
    final raw = data['templateSections'];
    return raw is! Map || raw.isEmpty;
  }

  Widget _reportSection(String title, dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  List<String> _parseTasks(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.length > 1) return lines;
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _formatPlanDate(dynamic raw) {
    if (raw is Timestamp) {
      final dt = raw.toDate();
      return "Submitted: ${dt.day}/${dt.month}/${dt.year}";
    }
    if (raw is String) return "Submitted: $raw";
    return "Submitted: —";
  }

  String _formatTimestamp(dynamic raw) {
    if (raw is Timestamp) {
      final dt = raw.toDate();
      return "${dt.day}/${dt.month}/${dt.year}";
    }
    return "—";
  }
}
