import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pdf_reports.dart';
import 'notification_service.dart';
import 'firestore_safe.dart';
import 'change_password.dart';
import 'widgets/expert_sidebar.dart';
import 'widgets/app_ui.dart';
import 'widgets/notification_bell.dart';

class ExpertDashboard extends StatefulWidget {
  const ExpertDashboard({super.key});

  @override
  State<ExpertDashboard> createState() => _ExpertDashboardState();
}

class _ExpertDashboardState extends State<ExpertDashboard> {
  int _currentIndex = 0;
  String?
      _editingPlanId; // When set, the plan form edits this doc (resubmission after revision)

  // Enterprise Contacts scope: 'assigned' (from my weekly schedule) or
  // 'dept' (all enterprises in my department, read-only reference).
  String _enterpriseScope = 'assigned';

  // Profile
  String _myName = 'Expert';
  String _myEmail = '';
  String _myDepartment = '';

  // Plan submission form
  final _planFormKey = GlobalKey<FormState>();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _outcomeController = TextEditingController();
  final TextEditingController _resourcesController = TextEditingController();
  final TextEditingController _tasksController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // Technology proposal form
  final _techFormKey = GlobalKey<FormState>();
  final TextEditingController _techNameController = TextEditingController();
  final TextEditingController _techCategoryController = TextEditingController();
  final TextEditingController _techReasonController = TextEditingController();

  static const List<String> _reportTemplates = [
    'Standard Visit Report',
    'Technology Transfer Report',
    'Training & Capacity Building',
    'Model Enterprise Support',
    'Productivity Improvement',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _targetController.dispose();
    _locationController.dispose();
    _descController.dispose();
    _outcomeController.dispose();
    _resourcesController.dispose();
    _tasksController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _techNameController.dispose();
    _techCategoryController.dispose();
    _techReasonController.dispose();
    super.dispose();
  }

  // ============================ PROFILE ============================
  Future<void> _loadProfile() async {
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
        _myName = ((data?['fullName'] ??
                    data?['name'] ??
                    user.displayName ??
                    'Expert')
                .toString())
            .trim();
        _myEmail = user.email ?? '';
        _myDepartment =
            ((data?['department'] ?? data?['dept'] ?? '').toString()).trim();
      });
    } catch (_) {
      // Keep the default profile values if the lookup fails.
    }
  }

  String get _expertId => _myEmail.isNotEmpty ? _myEmail : 'Expert User';

  bool _isMyPlan(Map<String, dynamic> data) {
    final by = (data['submittedBy'] ?? '').toString();
    final name = (data['expertName'] ?? '').toString();
    return by == _expertId ||
        (name.isNotEmpty && name == _myName) ||
        by == 'Expert User';
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFDC2626) : AppPalette.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ============================ HELPERS ============================
  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'Select Date',
    );
    if (picked != null) ctrl.text = DateFormat('yyyy-MM-dd').format(picked);
  }

  String _fmtDate(Object? raw) {
    if (raw == null) return '—';
    final s = raw.toString();
    if (s.isEmpty) return '—';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
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

  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url));
    } catch (_) {
      _snack('Could not open: $url', error: true);
    }
  }

  // ============================ SUBMIT PLAN ============================
  Future<void> _submitPlan() async {
    if (!(_planFormKey.currentState?.validate() ?? false)) return;
    if (_startDateController.text.isEmpty || _endDateController.text.isEmpty) {
      _snack('Please choose the visit start and end dates.', error: true);
      return;
    }
    try {
      if (DateTime.parse(_endDateController.text)
          .isBefore(DateTime.parse(_startDateController.text))) {
        _snack('End date cannot be before the start date.', error: true);
        return;
      }
    } catch (_) {
      // Dates come from the date picker; ignore anything unparseable.
    }
    final user = FirebaseAuth.instance.currentUser;
    final data = <String, dynamic>{
      'targetEnterprise': _targetController.text.trim(),
      'location': _locationController.text.trim(),
      'description': _descController.text.trim(),
      'tasks': _tasksController.text.trim(),
      'expectedOutcomes': _outcomeController.text.trim(),
      'resources': _resourcesController.text.trim(),
      'startDate': _startDateController.text,
      'endDate': _endDateController.text,
      'department': _myDepartment.isEmpty ? 'ICT' : _myDepartment,
      'expertName': _myName,
      'submittedBy': user?.email ?? 'Expert User',
      'status': 'Pending Dean Review',
      'timestamp': FieldValue.serverTimestamp(),
    };
    try {
      if (_editingPlanId != null) {
        await FirebaseFirestore.instance
            .collection('expert_plans')
            .doc(_editingPlanId)
            .update({
          ...data,
          'status': 'Pending Dean Review',
          'revisionFeedback': FieldValue.delete(),
          'reviewedAt': FieldValue.delete(),
        });
        _snack('Plan updated and resubmitted for approval.');
      } else {
        await FirebaseFirestore.instance.collection('expert_plans').add(data);
        _snack('Visit plan submitted for review.');
      }
      await pushNotification(
        title:
            _editingPlanId != null ? 'Plan Resubmitted' : 'New Visit Plan Submitted',
        message:
            'Visit plan for ${_targetController.text.trim()} has been submitted for ${_editingPlanId != null ? 'resubmission' : 'review'}.',
        department: _myDepartment,
        roles: const ['deptHead', 'dean'],
        type: 'plan',
      );
      _clearPlanForm();
    } catch (e) {
      _snack('Submission failed: $e', error: true);
    }
  }

  void _clearPlanForm() {
    _targetController.clear();
    _locationController.clear();
    _descController.clear();
    _outcomeController.clear();
    _resourcesController.clear();
    _tasksController.clear();
    _startDateController.clear();
    _endDateController.clear();
    setState(() => _editingPlanId = null);
  }

  void _editPlan(DocumentSnapshot doc, Map<String, dynamic> data) {
    _targetController.text = (data['targetEnterprise'] ?? '').toString();
    _locationController.text = (data['location'] ?? '').toString();
    _descController.text = (data['description'] ?? '').toString();
    _outcomeController.text = (data['expectedOutcomes'] ?? '').toString();
    _resourcesController.text = (data['resources'] ?? '').toString();
    _tasksController.text = (data['tasks'] ?? '').toString();
    _startDateController.text = (data['startDate'] ?? '').toString();
    _endDateController.text = (data['endDate'] ?? '').toString();
    setState(() {
      _editingPlanId = doc.id;
      _currentIndex = 1;
    });
    _snack('Editing plan — adjust the details and resubmit.');
  }

  // ============================ SUBMIT TECHNOLOGY ============================
  Future<void> _submitTechnology() async {
    if (!(_techFormKey.currentState?.validate() ?? false)) return;
    try {
      await FirebaseFirestore.instance.collection('proposed_technologies').add({
        'techName': _techNameController.text.trim(),
        'category': _techCategoryController.text.trim(),
        'purpose': _techReasonController.text.trim(),
        'status': 'Pending',
        'submittedBy': _expertId,
        'expertName': _myName,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _techNameController.clear();
      _techCategoryController.clear();
      _techReasonController.clear();
      _snack('Technology proposal sent to the Dean.');
    } catch (e) {
      _snack('Proposal failed: $e', error: true);
    }
  }

  // ============================ WORKFLOW ACTIONS ============================
  Future<void> _startVisit(DocumentSnapshot doc) async {
    try {
      await doc.reference.update({'status': 'In Progress'});
      _snack('Visit started — you can now track your task checklist.');
    } catch (e) {
      _snack('Failed to start visit: $e', error: true);
    }
  }

  Future<void> _toggleTask(
      DocumentSnapshot doc, Map<String, dynamic> data, String task) async {
    final raw = data['taskChecklist'];
    final checklist =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    checklist[task] = !(checklist[task] == true);
    try {
      await doc.reference.update({'taskChecklist': checklist});
    } catch (e) {
      _snack('Failed to update checklist: $e', error: true);
    }
  }

  void _showReportDialog(DocumentSnapshot doc, Map<String, dynamic> data) {
    final tasksCtrl =
        TextEditingController(text: (data['tasksPerformed'] ?? '').toString());
    final challengesCtrl =
        TextEditingController(text: (data['challenges'] ?? '').toString());
    final solutionsCtrl = TextEditingController(
        text: (data['solutionsProvided'] ?? '').toString());
    final verifierCtrl =
        TextEditingController(text: (data['verifiedBy'] ?? '').toString());
    final finalReportCtrl =
        TextEditingController(text: (data['finalReport'] ?? '').toString());
    String reportTemplate =
        (data['reportTemplate'] ?? _reportTemplates.first).toString();
    if (!_reportTemplates.contains(reportTemplate)) {
      reportTemplate = _reportTemplates.first;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Submit Support Report',
                textAlign: TextAlign.center),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['targetEnterprise'] ?? 'Enterprise',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    '${_fmtDate(data['startDate'])}  →  ${_fmtDate(data['endDate'])}',
                    style: const TextStyle(
                        color: AppPalette.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    value: reportTemplate,
                    decoration: appInputDecoration(
                      label: 'Report Format',
                      icon: Icons.description_outlined,
                    ),
                    items: _reportTemplates
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setDialogState(
                        () => reportTemplate = v ?? reportTemplate),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: finalReportCtrl,
                    maxLines: 4,
                    decoration: appInputDecoration(
                      label: 'Final Report Summary',
                      hint: 'Summarize what was achieved during the visit',
                      icon: Icons.article_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: tasksCtrl,
                    maxLines: 2,
                    decoration: appInputDecoration(
                      label: 'Tasks Performed',
                      icon: Icons.checklist_rtl,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: challengesCtrl,
                    maxLines: 2,
                    decoration: appInputDecoration(
                      label: 'Challenges Faced',
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: solutionsCtrl,
                    maxLines: 2,
                    decoration: appInputDecoration(
                      label: 'Solutions Provided',
                      icon: Icons.lightbulb_outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: verifierCtrl,
                    decoration: appInputDecoration(
                      label: 'Verified By (Name / Role)',
                      icon: Icons.verified_outlined,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel',
                    style: TextStyle(color: AppPalette.textMuted)),
              ),
              GradientButton(
                label: 'Submit Report',
                icon: Icons.send_rounded,
                width: 170,
                height: 44,
                fontSize: 13,
                colors: AppPalette.successGradient,
                onPressed: () async {
                  if (finalReportCtrl.text.trim().isEmpty) {
                    _snack('Please write a final report summary.', error: true);
                    return;
                  }
                  try {
                    await doc.reference.update({
                      'reportTemplate': reportTemplate,
                      'finalReport': finalReportCtrl.text.trim(),
                      'tasksPerformed': tasksCtrl.text.trim(),
                      'challenges': challengesCtrl.text.trim(),
                      'solutionsProvided': solutionsCtrl.text.trim(),
                      'verifiedBy': verifierCtrl.text.trim(),
                      'status': 'Completed',
                      'reportDate': FieldValue.serverTimestamp(),
                    });
                    await pushNotification(
                      title: 'Support Report Submitted',
                      message:
                          'A support report for ${data['targetEnterprise'] ?? 'the enterprise'} has been submitted for review.',
                      department:
                          (data['department'] ?? _myDepartment).toString(),
                      roles: const ['deptHead', 'dean'],
                      type: 'report',
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    _snack('Support report submitted!');
                  } catch (e) {
                    _snack('Report failed: $e', error: true);
                  }
                },
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      tasksCtrl.dispose();
      challengesCtrl.dispose();
      solutionsCtrl.dispose();
      verifierCtrl.dispose();
      finalReportCtrl.dispose();
    });
  }

  // ============================ CHANGE PASSWORD ============================
  Future<void> _changePassword() async {
    final changed = await showChangePasswordDialog(context);
    if (changed && mounted) {
      _snack('Password updated successfully.');
    }
  }

  // ============================ LOGOUT ============================
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Logout', textAlign: TextAlign.center),
        content: const Text(
            'Are you sure you want to sign out? Any unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        _snack('Logout failed: $e', error: true);
      }
    }
  }

  // ============================ BUILD ============================
  @override
  Widget build(BuildContext context) {
    final bool isWide =
        MediaQuery.of(context).size.width >= AppPalette.desktopBreakpoint;
    return Scaffold(
      backgroundColor: AppPalette.background,
      // On narrow screens the fixed 260px sidebar would crush the content, so
      // it collapses into a hamburger drawer instead of a side rail.
      drawer: isWide
          ? null
          : Drawer(
              width: 260,
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: ExpertSidebar(
                currentIndex: _currentIndex,
                onTabSelected: (index) {
                  Navigator.of(context).pop();
                  if (index == 7) {
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
            ExpertSidebar(
              currentIndex: _currentIndex,
              onTabSelected: (index) {
                if (index == 7) {
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
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({required bool isWide}) {
    final initials = _myName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
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
            const Icon(Icons.school_rounded,
                color: AppPalette.primary, size: 26),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Text(
              'Instructor Service Portal',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textPrimary),
            ),
          ),
          NotificationBell(
            scope: NotificationScope(role: 'expert', department: _myDepartment),
          ),
          if (isWide) ...[
            const SizedBox(width: 18),
            Container(width: 1, height: 30, color: AppPalette.border),
            const SizedBox(width: 18),
          ] else
            const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppPalette.primary,
            child: Text(
              initials.isEmpty ? 'E' : initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
          if (isWide) ...[
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_myName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimary)),
                Text(
                  _myDepartment.isEmpty ? 'Expert' : 'Expert · $_myDepartment',
                  style: const TextStyle(
                      fontSize: 11, color: AppPalette.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    final views = <Widget>[
      _buildOverview(),
      _buildScheduleView(),
      _buildPlanFormView(),
      _buildSupportReportsView(),
      _buildEnterpriseContactsView(),
      _buildTechProposalView(),
      _buildSettingsView(),
    ];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
                begin: const Offset(0.03, 0), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child));
      },
      child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex), child: views[_currentIndex]),
    );
  }

  // ============================ OVERVIEW ============================
  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreetingBanner(),
          const SizedBox(height: 24),
          const Text('Performance at a Glance',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textPrimary)),
          const SizedBox(height: 14),
          _buildMetricRow(),
          const SizedBox(height: 28),
          _buildQuickActions(),
          const SizedBox(height: 28),
          _buildAnnouncements(),
        ],
      ),
    );
  }

  Widget _buildGreetingBanner() {
    final firstName = _myName.split(' ').first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4338CA), Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $firstName 👋',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Plan enterprise visits, track approvals and submit your support reports — all in one place.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    GradientButton(
                      label: 'Submit Visit Plan',
                      icon: Icons.assignment_add,
                      width: 190,
                      height: 44,
                      fontSize: 13,
                      onPressed: () => setState(() => _currentIndex = 1),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentIndex = 2),
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('Reports Due'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = ((constraints.maxWidth - 48) / 4).clamp(180.0, 400.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _overviewMetric(
                title: 'Total Enterprises',
                subtitle: 'in your department',
                icon: Icons.business_rounded,
                color: const Color(0xFF6366F1),
                trend: _myDepartment.isEmpty ? 'All' : _myDepartment,
                width: cardW,
                stream: FirebaseFirestore.instance
                    .collection('enterprises')
                    .snapshots(),
                compute: (docs) {
                  if (_myDepartment.isEmpty) return docs.length;
                  return docs
                      .where((d) =>
                          deptMatches(docStr(d, 'department'), _myDepartment))
                      .length;
                },
              ),
              const SizedBox(width: 16),
              _overviewMetric(
                title: 'Approved Plans',
                subtitle: 'ready to execute',
                icon: Icons.fact_check_rounded,
                color: const Color(0xFF16A34A),
                trend: 'Live',
                trendIcon: Icons.bolt_rounded,
                width: cardW,
                stream: FirebaseFirestore.instance
                    .collection('expert_plans')
                    .snapshots(),
                compute: (docs) => docs
                    .where((d) =>
                        _isMyPlan(d.data() as Map<String, dynamic>) &&
                        (docStr(d, 'status') == 'Approved' ||
                            docStr(d, 'status') == 'Approved by Dept Head'))
                    .length,
              ),
              const SizedBox(width: 16),
              _overviewMetric(
                title: 'Reports Due',
                subtitle: 'awaiting your report',
                icon: Icons.description_rounded,
                color: const Color(0xFFEA580C),
                trend: 'Action',
                trendIcon: Icons.arrow_upward_rounded,
                width: cardW,
                stream: FirebaseFirestore.instance
                    .collection('expert_plans')
                    .snapshots(),
                compute: (docs) => docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final s = (data['status'] ?? '').toString();
                  return _isMyPlan(data) &&
                      (s == 'Approved' || s == 'In Progress') &&
                      (data['finalReport'] ?? '').toString().isEmpty;
                }).length,
              ),
              const SizedBox(width: 16),
              _overviewMetric(
                title: 'My Plans',
                subtitle: 'total submissions',
                icon: Icons.assignment_rounded,
                color: const Color(0xFF7C3AED),
                trend: 'All',
                width: cardW,
                stream: FirebaseFirestore.instance
                    .collection('expert_plans')
                    .snapshots(),
                compute: (docs) => docs
                    .where((d) => _isMyPlan(d.data() as Map<String, dynamic>))
                    .length,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _overviewMetric({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String trend,
    required double width,
    IconData? trendIcon,
    required Stream<QuerySnapshot<Object?>> stream,
    required int Function(List<QueryDocumentSnapshot<Object?>>) compute,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final docs =
            snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
        final value = docs.isEmpty ? '0' : compute(docs).toString();
        return SizedBox(
          width: width,
          child: MetricCard(
            title: title,
            value: value,
            subtitle: subtitle,
            icon: icon,
            color: color,
            trend: trend,
            trendIcon: trendIcon,
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary)),
        const SizedBox(height: 14),
        Row(
          children: [
            _quickActionTile(
              icon: Icons.biotech_rounded,
              title: 'Propose Tech',
              subtitle: 'Recommend a technology',
              gradient: AppPalette.accentGradient,
              onTap: () => setState(() => _currentIndex = 4),
            ),
            const SizedBox(width: 16),
            _quickActionTile(
              icon: Icons.contacts_rounded,
              title: 'Enterprise Contacts',
              subtitle: 'Browse the directory',
              gradient: AppPalette.primaryGradient,
              onTap: () => setState(() => _currentIndex = 3),
            ),
            const SizedBox(width: 16),
            _quickActionTile(
              icon: Icons.settings_suggest_rounded,
              title: 'Account Settings',
              subtitle: 'View your profile',
              gradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
              onTap: () => setState(() => _currentIndex = 5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: HoverCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              IconBubble(icon: icon, color: gradient.first, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppPalette.textPrimary)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppPalette.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppPalette.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.campaign_rounded,
                color: AppPalette.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Department Announcements',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimary)),
          ],
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('department_announcements')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = (snapshot.data?.docs ?? <QueryDocumentSnapshot>[])
                .where((d) {
                  final dept = docStr(d, 'department');
                  return _myDepartment.isEmpty ||
                      dept.isEmpty ||
                      deptMatches(dept, _myDepartment);
                })
                .take(3)
                .toList();
            if (docs.isEmpty) {
              return GlassCard(
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined,
                        color: AppPalette.textMuted, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'No announcements yet. Check back soon for updates from your department head.',
                        style: TextStyle(
                            color: AppPalette.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final priority = (data['priority'] ?? 'Normal').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HoverCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconBubble(
                          icon: priority == 'High'
                              ? Icons.priority_high_rounded
                              : Icons.notifications_active_outlined,
                          color: priority == 'High'
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF6366F1),
                          size: 40,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['title'] ?? 'Announcement',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppPalette.textPrimary),
                                    ),
                                  ),
                                  StatusChip(priority,
                                      color: priority == 'High'
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF6366F1)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                data['message'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppPalette.textSecondary,
                                    height: 1.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '— ${data['sender'] ?? 'Dept Head'}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppPalette.textMuted,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ============================ MY WEEKLY SCHEDULE ============================
  Widget _buildScheduleView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.calendar_month_rounded,
            title: 'My Weekly Schedule',
            subtitle:
                'Visits assigned by your Department Head. Turn any schedule into a visit plan in one tap.',
          ),
          const SizedBox(height: 22),
          StreamBuilder<QuerySnapshot>(
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
                    child: Text('Error loading schedules: ${snapshot.error}'));
              }
              final docs = (snapshot.data?.docs ?? []).where((d) {
                final m = d.data() as Map<String, dynamic>;
                final byEmail = (m['expertEmail'] ?? '').toString();
                final byName = (m['expertName'] ?? '').toString();
                return (byEmail.isNotEmpty && byEmail == _myEmail) ||
                    (byName.isNotEmpty && byName == _myName);
              }).toList();
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  decoration: BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppPalette.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_available_outlined,
                          size: 56, color: AppPalette.textMuted.withValues(alpha: 0.6)),
                      const SizedBox(height: 12),
                      const Text(
                        'No schedules assigned yet',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your Department Head assigns weekly enterprise visits here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.5, color: AppPalette.textMuted),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final doc in docs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildScheduleCard(doc.data() as Map<String, dynamic>),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> sched) {
    final daysRaw = sched['days'];
    final dayList = daysRaw is List
        ? daysRaw.map((e) => e.toString()).toList()
        : <String>[];
    return HoverCard(
      padding: const EdgeInsets.all(20),
      radius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBubble(
              icon: Icons.event_repeat_rounded,
              color: AppPalette.primary,
              size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (sched['enterpriseName'] ?? 'Unknown Enterprise')
                            .toString(),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.textPrimary),
                      ),
                    ),
                    StatusChip('Weekly', color: AppPalette.primary),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmtDate(sched['startDate'])}  →  ${_fmtDate(sched['endDate'])}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppPalette.textSecondary),
                ),
                const SizedBox(height: 10),
                if (dayList.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: dayList.map((d) => _scheduleDayChip(d)).toList(),
                  ),
                if ((sched['objectives'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    (sched['objectives'] ?? '').toString(),
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppPalette.textSecondary,
                        height: 1.4),
                  ),
                ],
                const SizedBox(height: 14),
                GradientButton(
                  label: 'Create Visit Plan for this Schedule',
                  icon: Icons.playlist_add_rounded,
                  height: 44,
                  fontSize: 13,
                  onPressed: () => _createPlanFromSchedule(sched),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleDayChip(String day) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        day,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppPalette.primary),
      ),
    );
  }

  // Pre-fill the visit plan submission form with this schedule's details and
  // jump straight to the Submit Plan tab.
  void _createPlanFromSchedule(Map<String, dynamic> sched) {
    setState(() {
      _editingPlanId = null;
      _targetController.text = (sched['enterpriseName'] ?? '').toString();
      _locationController.text = (sched['enterpriseWoreda'] ?? '').toString();
      _descController.text = (sched['objectives'] ?? '').toString();
      _startDateController.text = (sched['startDate'] ?? '').toString();
      _endDateController.text = (sched['endDate'] ?? '').toString();
      // Clear any stale draft fields so the pre-filled form starts clean.
      _tasksController.clear();
      _outcomeController.clear();
      _resourcesController.clear();
      _currentIndex = 2; // Submit Plan tab
    });
    _snack('Schedule pre-filled — review and submit your visit plan.');
  }

  // ============================ PLAN FORM + MY PLANS ============================
  Widget _buildPlanFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.note_add_rounded,
            title: _editingPlanId != null
                ? 'Edit Visit Plan'
                : 'Submit a New Visit Plan',
            subtitle:
                'Detail your enterprise visit so the Department Head and Dean can approve it.',
          ),
          const SizedBox(height: 22),
          GlassCard(
            padding: const EdgeInsets.all(26),
            child: Form(
              key: _planFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Target Enterprise',
                      icon: Icons.business_rounded),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _targetController,
                    decoration: appInputDecoration(
                      hint: 'e.g. Ayka Addis Textile',
                      icon: Icons.business_rounded,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enterprise name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Location / Woreda',
                      icon: Icons.location_on_rounded),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _locationController,
                    decoration: appInputDecoration(
                      hint: 'e.g. Hawassa Industrial Park, Woreda 03',
                      icon: Icons.location_on_rounded,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Location is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('Start Date',
                                icon: Icons.event_rounded),
                            const SizedBox(height: 8),
                            _dateField(_startDateController),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('End Date',
                                icon: Icons.event_available_rounded),
                            const SizedBox(height: 8),
                            _dateField(_endDateController),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Detailed Objectives',
                      icon: Icons.flag_rounded),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: appInputDecoration(
                      hint: 'What specific problems are you solving on-site?',
                      icon: Icons.flag_rounded,
                      alignLabel: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Objectives are required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Planned Tasks (one per line)',
                      icon: Icons.checklist_rounded),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tasksController,
                    maxLines: 4,
                    decoration: appInputDecoration(
                      hint:
                          '• Baseline assessment\n• Staff training\n• Equipment calibration',
                      icon: Icons.checklist_rounded,
                      alignLabel: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Expected Outcomes',
                      icon: Icons.trending_up_rounded),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _outcomeController,
                    decoration: appInputDecoration(
                      hint:
                          'e.g. Improved production by 20%, staff trained on IoT',
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Resources / Tools Required',
                      icon: Icons.construction_rounded),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _resourcesController,
                    decoration: appInputDecoration(
                      hint:
                          'e.g. Laptop, GIC service vehicle, measurement tools',
                      icon: Icons.construction_rounded,
                    ),
                  ),
                  const SizedBox(height: 26),
                  GradientButton(
                    label: _editingPlanId != null
                        ? 'Update & Resubmit Plan'
                        : 'Submit Formal Plan',
                    icon: Icons.send_rounded,
                    onPressed: _submitPlan,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 34),
          const Row(
            children: [
              Icon(Icons.folder_shared_rounded,
                  color: AppPalette.primary, size: 24),
              SizedBox(width: 10),
              Text(
                'My Submitted Plans',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMyPlansList(),
        ],
      ),
    );
  }

  Widget _dateField(TextEditingController ctrl) {
    return InkWell(
      onTap: () => _pickDate(ctrl),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: appInputDecoration(
          hint: 'Tap to pick',
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

  Widget _buildMyPlansList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('expert_plans')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyState(
              Icons.error_outline, 'Could not load plans', '${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = (snapshot.data?.docs ?? <QueryDocumentSnapshot>[])
            .where((d) => _isMyPlan(d.data() as Map<String, dynamic>))
            .toList();
        if (docs.isEmpty) {
          return _emptyState(
            Icons.inbox_outlined,
            'No plans submitted yet',
            'Use the form above to submit your first enterprise visit plan.',
          );
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildPlanCard(doc, data),
            );
          }).toList(),
        );
      },
    );
  }

  // ============================ SUPPORT REPORTS ============================
  Widget _buildSupportReportsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionTitle(
                  icon: Icons.fact_check_rounded,
                  title: 'Support Reports',
                  subtitle:
                      'Track plans that need your report and review completed submissions.',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _currentIndex = 1),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Plan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.primary,
                  side: const BorderSide(color: AppPalette.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('expert_plans')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = (snapshot.data?.docs ?? <QueryDocumentSnapshot>[])
                  .where((d) => _isMyPlan(d.data() as Map<String, dynamic>))
                  .toList();
              if (docs.isEmpty) {
                return _emptyState(
                  Icons.description_outlined,
                  'Nothing to report yet',
                  'Once your plan is approved, you can submit a support report here.',
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildPlanCard(doc, data),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================ PLAN CARD ============================
  Widget _buildPlanCard(DocumentSnapshot doc, Map<String, dynamic> data) {
    final String status = (data['status'] ?? 'Pending Dean Review').toString();
    final Color statusColor = AppPalette.statusColor(status);
    final tasks =
        _parseTasks((data['tasks'] ?? data['description'] ?? '').toString());
    final rawChecklist = data['taskChecklist'];
    final checklist = rawChecklist is Map
        ? Map<String, dynamic>.from(rawChecklist)
        : <String, dynamic>{};
    final done = checklist.values.where((v) => v == true).length;
    final canResubmit = const [
      'Pending Dean Review',
      'Pending',
      'Approved by Dept Head',
      'Needs Revision',
      'Revision Requested',
    ].contains(status);
    final needsReport = status == 'In Progress';
    final revisionFeedback = (data['revisionFeedback'] ?? '').toString();
    final deptHeadFeedback = (data['deptHeadFeedback'] ?? '').toString();

    return HoverCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(
                icon: status == 'Completed'
                    ? Icons.verified_rounded
                    : status == 'In Progress'
                        ? Icons.play_circle_fill_rounded
                        : Icons.business_center_rounded,
                color: statusColor,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['targetEnterprise'] ?? 'Unknown Enterprise',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppPalette.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_fmtDate(data['startDate'])}  →  ${_fmtDate(data['endDate'])}'
                      '${(data['location'] ?? '').toString().isNotEmpty ? '  ·  ${data['location']}' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: AppPalette.textMuted),
                    ),
                  ],
                ),
              ),
              StatusChip(status, color: statusColor),
            ],
          ),
          const Divider(height: 26),
          if ((data['description'] ?? '').toString().isNotEmpty) ...[
            _planInfoRow(Icons.flag_outlined, 'Objectives',
                data['description'].toString()),
            const SizedBox(height: 6),
          ],
          if ((data['expectedOutcomes'] ?? '').toString().isNotEmpty) ...[
            _planInfoRow(Icons.trending_up, 'Expected Outcomes',
                data['expectedOutcomes'].toString()),
            const SizedBox(height: 6),
          ],
          if ((data['resources'] ?? '').toString().isNotEmpty) ...[
            _planInfoRow(Icons.construction_outlined, 'Resources',
                data['resources'].toString()),
            const SizedBox(height: 6),
          ],
          if (tasks.isNotEmpty) ...[
            const Text('Planned Tasks',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppPalette.textPrimary)),
            const SizedBox(height: 8),
            ...tasks.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      checklist[t] == true
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 17,
                      color: checklist[t] == true
                          ? const Color(0xFF16A34A)
                          : AppPalette.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 13,
                          color: checklist[t] == true
                              ? AppPalette.textMuted
                              : AppPalette.textSecondary,
                          decoration: checklist[t] == true
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (revisionFeedback.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.feedback_outlined,
                      size: 18, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Revision requested: $revisionFeedback',
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF9A3412)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (deptHeadFeedback.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status == 'Rejected'
                    ? const Color(0xFFFEF2F2)
                    : status == 'Needs Revision'
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status == 'Rejected'
                      ? const Color(0xFFFEE2E2)
                      : status == 'Needs Revision'
                          ? const Color(0xFFFFEDD5)
                          : const Color(0xFFCCFBF1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    status == 'Rejected'
                        ? Icons.block
                        : Icons.verified_user_outlined,
                    size: 18,
                    color: status == 'Rejected'
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0D9488),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status == 'Rejected'
                          ? 'Rejected: $deptHeadFeedback'
                          : 'Department Head: $deptHeadFeedback',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: status == 'Rejected'
                            ? const Color(0xFF991B1B)
                            : const Color(0xFF115E59),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (status == 'In Progress' && tasks.isNotEmpty) ...[
            const Text('On-Site Task Progress',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppPalette.textPrimary)),
            const SizedBox(height: 8),
            ...tasks.map(
              (t) => InkWell(
                onTap: () => _toggleTask(doc, data, t),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        checklist[t] == true
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 19,
                        color: checklist[t] == true
                            ? const Color(0xFF16A34A)
                            : AppPalette.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 13,
                            decoration: checklist[t] == true
                                ? TextDecoration.lineThrough
                                : null,
                            color: checklist[t] == true
                                ? AppPalette.textMuted
                                : AppPalette.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.touch_app_outlined,
                          size: 14, color: AppPalette.textMuted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('$done of ${tasks.length} completed',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppPalette.textMuted)),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: done / tasks.length,
                      minHeight: 6,
                      backgroundColor: AppPalette.border,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (status == 'Completed') ...[
            const Text('Final Report Summary',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppPalette.textPrimary)),
            const SizedBox(height: 8),
            if ((data['reportTemplate'] ?? '').toString().isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.description_outlined,
                      size: 15, color: AppPalette.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Format: ${data['reportTemplate']}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary),
                  ),
                ],
              ),
            if ((data['finalReport'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(data['finalReport'].toString(),
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppPalette.textSecondary)),
            ],
            if ((data['tasksPerformed'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _planInfoRow(Icons.checklist_rtl, 'Tasks Performed',
                  data['tasksPerformed'].toString()),
            ],
            if ((data['challenges'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              _planInfoRow(Icons.warning_amber_rounded, 'Challenges',
                  data['challenges'].toString()),
            ],
            if ((data['solutionsProvided'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              _planInfoRow(Icons.lightbulb_outline, 'Solutions',
                  data['solutionsProvided'].toString()),
            ],
          ],
          const Divider(height: 24),
          Row(
            children: [
              if (canResubmit) ...[
                OutlinedButton.icon(
                  onPressed: () => _editPlan(doc, data),
                  icon: const Icon(Icons.edit_note, size: 17),
                  label: const Text('Edit & Resubmit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.primary,
                    side: const BorderSide(color: AppPalette.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (status == 'Approved') ...[
                GradientButton(
                  label: 'Start Visit',
                  icon: Icons.play_arrow_rounded,
                  width: 140,
                  height: 42,
                  fontSize: 13,
                  colors: AppPalette.successGradient,
                  onPressed: () => _startVisit(doc),
                ),
                const SizedBox(width: 10),
              ],
              if (needsReport) ...[
                GradientButton(
                  label: 'Submit Report',
                  icon: Icons.assignment_turned_in_rounded,
                  width: 160,
                  height: 42,
                  fontSize: 13,
                  onPressed: () => _showReportDialog(doc, data),
                ),
                const SizedBox(width: 10),
              ],
              if (status == 'Completed')
                OutlinedButton.icon(
                  onPressed: () => printSupportReportPdf(data),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                  label: const Text('Print PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              const Spacer(),
              Tooltip(
                message: 'Print visit plan',
                child: IconButton(
                  onPressed: () => printVisitPlanPdf(data),
                  icon: const Icon(Icons.print_outlined,
                      size: 19, color: AppPalette.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppPalette.textMuted),
        const SizedBox(width: 8),
        Text('$label:  ',
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppPalette.textSecondary)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12.5,
                  color: AppPalette.textSecondary,
                  height: 1.4)),
        ),
      ],
    );
  }

  // ============================ ENTERPRISE CONTACTS ============================
  Widget _buildEnterpriseContactsView() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.contacts_outlined,
            title: 'Enterprise Contacts',
            subtitle: _myDepartment.isEmpty
                ? 'Directory of registered enterprises'
                : 'Registered enterprises in your department — $_myDepartment',
          ),
          const SizedBox(height: 16),
          // Scope toggle: assigned (from weekly schedule) vs all department.
          Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'assigned',
                    label: Text('My Assigned Enterprises'),
                    icon: Icon(Icons.event_repeat_rounded, size: 17),
                  ),
                  ButtonSegment(
                    value: 'dept',
                    label: Text('All Department Enterprises'),
                    icon: Icon(Icons.account_tree_outlined, size: 17),
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
                  _enterpriseScope == 'assigned'
                      ? 'Enterprises assigned to you in your weekly schedule.'
                      : 'All enterprises in ${_myDepartment.isEmpty ? 'your department' : _myDepartment} for reference.',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppPalette.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('enterprises')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, entSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('expert_schedules')
                      .snapshots(),
                  builder: (context, schedSnapshot) {
                    if (entSnapshot.hasError) {
                      return _emptyState(Icons.error_outline,
                          'Could not load contacts', '${entSnapshot.error}');
                    }
                    if (entSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        schedSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Lookup of enterprises assigned to this expert, keyed by
                    // enterprise doc id (exact) and normalized name (legacy
                    // schedules fall back to name matching).
                    final assignedById = <String, List<String>>{};
                    final assignedByName = <String, List<String>>{};
                    final myUid = FirebaseAuth.instance.currentUser?.uid;
                    for (final d in schedSnapshot.data?.docs ?? []) {
                      final m = d.data() as Map<String, dynamic>;
                      final id = (m['expertId'] ?? '').toString();
                      final email = (m['expertEmail'] ?? '').toString();
                      final name = (m['expertName'] ?? '').toString();
                      final isMine = (id.isNotEmpty &&
                              myUid != null &&
                              id == myUid) ||
                          (email.isNotEmpty && email == _myEmail) ||
                          (name.isNotEmpty && name == _myName);
                      if (!isMine) continue;
                      final daysRaw = m['days'];
                      final dayList = daysRaw is List
                          ? daysRaw.map((e) => e.toString()).toList()
                          : <String>[];
                      final entId = (m['enterpriseId'] ?? '').toString();
                      if (entId.isNotEmpty) assignedById[entId] = dayList;
                      final entKey =
                          normDept((m['enterpriseName'] ?? '').toString());
                      if (entKey.isNotEmpty) assignedByName[entKey] = dayList;
                    }

                    final docs =
                        (entSnapshot.data?.docs ?? <QueryDocumentSnapshot>[])
                            .where((d) {
                      if (_enterpriseScope == 'assigned') {
                        if (assignedById.containsKey(d.id)) return true;
                        final data = d.data() as Map<String, dynamic>;
                        final entName = normDept(
                            ((data['entName'] ?? data['name'] ?? '')
                                    .toString())
                                .trim());
                        return assignedByName.containsKey(entName);
                      }
                      if (_myDepartment.isEmpty) return true;
                      final dept = docStr(d, 'department');
                      return dept.isEmpty || deptMatches(dept, _myDepartment);
                    }).toList();

                    if (docs.isEmpty) {
                      return _emptyState(
                        Icons.contacts_outlined,
                        _enterpriseScope == 'assigned'
                            ? (schedSnapshot.hasError
                                ? 'Could not load your assigned schedule'
                                : 'No enterprises assigned to you yet')
                            : 'No enterprises found',
                        _enterpriseScope == 'assigned'
                            ? (schedSnapshot.hasError
                                ? 'Schedule data is unavailable right now. Please try again later.'
                                : 'Assigned enterprises from your weekly schedule appear here. Check your Schedule tab.')
                            : (_myDepartment.isEmpty
                                ? 'No enterprises registered yet.'
                                : 'No enterprises registered under $_myDepartment yet.'),
                      );
                    }
                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 320,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        // Taller cards so the extra Initial Capital line and
                        // the Scheduled badge never overflow on narrow grids.
                        childAspectRatio: 0.9,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        // The 'Scheduled: <day>' badge only shows in the
                        // assigned view (requirement 3).
                        final dayList = _enterpriseScope == 'assigned'
                            ? (assignedById[doc.id] ??
                                assignedByName[normDept(
                                        ((data['entName'] ?? data['name'] ?? '')
                                                .toString())
                                            .trim())] ??
                                const <String>[])
                            : const <String>[];
                        return _contactCard(data,
                            scheduledDay:
                                _enterpriseScope == 'assigned'
                                    ? _nextScheduleDay(dayList)
                                    : null);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Next upcoming scheduled visit day from the assigned schedule's day list.
  String? _nextScheduleDay(List<String> days) {
    if (days.isEmpty) return null;
    const weekdayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final today = DateTime.now().weekday - 1; // Monday = 0
    for (int offset = 0; offset < 7; offset++) {
      final idx = (today + offset) % 7;
      if (days.contains(weekdayNames[idx])) return weekdayNames[idx];
    }
    return null;
  }

  Widget _contactCard(Map<String, dynamic> data, {String? scheduledDay}) {
    final name = (data['entName'] ?? data['name'] ?? 'Enterprise').toString();
    final phone = (data['phone'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final rep = (data['repName'] ?? data['contactPerson'] ?? '—').toString();
    final woreda = (data['woreda'] ?? data['address'] ?? '—').toString();
    final sector = (data['sector'] ?? '—').toString();
    final isModel = data['isModel'] == true;

    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(
                icon: isModel ? Icons.star_rounded : Icons.business_rounded,
                color:
                    isModel ? const Color(0xFFD97706) : AppPalette.primary,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppPalette.textPrimary)),
                    Text('$sector · $woreda',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppPalette.textMuted)),
                  ],
                ),
              ),
              if (isModel) const StatusChip('Model', color: Color(0xFFD97706)),
            ],
          ),
          if (scheduledDay != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_available_rounded,
                      size: 13, color: Color(0xFF16A34A)),
                  const SizedBox(width: 5),
                  Text(
                    'Scheduled: $scheduledDay',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
          ],
        const SizedBox(height: 14),
        _contactLine(Icons.person_outline, 'Representative', rep),
          const SizedBox(height: 6),
          _contactLine(
              Icons.phone_outlined, 'Phone', phone.isEmpty ? '—' : phone),
          const SizedBox(height: 6),
          _contactLine(Icons.payments_outlined, 'Initial Capital',
              formatInitialCapital(data['initialCapital'])),
          const Spacer(),
          Row(
            children: [
              if (phone.isNotEmpty)
                IconButton(
                  onPressed: () => _launch('tel:$phone'),
                  icon: const Icon(Icons.call_rounded,
                      color: Color(0xFF16A34A), size: 20),
                  tooltip: 'Call',
                ),
              if (email.isNotEmpty)
                IconButton(
                  onPressed: () => _launch('mailto:$email'),
                  icon: const Icon(Icons.email_rounded,
                      color: AppPalette.primary, size: 20),
                  tooltip: 'Email',
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => printEnterpriseDetailsPdf(data),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('PDF'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactLine(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppPalette.textMuted),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 11.5, color: AppPalette.textMuted)),
        Expanded(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.textPrimary)),
        ),
      ],
    );
  }

  // ============================ TECH PROPOSALS ============================
  Widget _buildTechProposalView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.biotech_rounded,
            title: 'Propose a Technology',
            subtitle:
                'Recommend new technologies to help Gofa Industrial College and its enterprises.',
          ),
          const SizedBox(height: 22),
          GlassCard(
            padding: const EdgeInsets.all(26),
            child: Form(
              key: _techFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Technology Name',
                      icon: Icons.precision_manufacturing_rounded),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _techNameController,
                    decoration: appInputDecoration(
                      hint: 'e.g. Solar Irrigation Pump',
                      icon: Icons.precision_manufacturing_rounded,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Technology name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Category', icon: Icons.category_rounded),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _techCategoryController,
                    decoration: appInputDecoration(
                      hint: 'e.g. AI, IoT, Cloud, Renewable Energy',
                      icon: Icons.category_rounded,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Category is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Purpose & Benefits',
                      icon: Icons.help_outline_rounded),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _techReasonController,
                    maxLines: 3,
                    decoration: appInputDecoration(
                      hint:
                          'How will this help GIC and its partner enterprises?',
                      icon: Icons.help_outline_rounded,
                      alignLabel: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Purpose is required'
                        : null,
                  ),
                  const SizedBox(height: 26),
                  GradientButton(
                    label: 'Submit Proposal',
                    icon: Icons.send_rounded,
                    colors: AppPalette.accentGradient,
                    onPressed: _submitTechnology,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 34),
          const Row(
            children: [
              Icon(Icons.history_rounded,
                  color: AppPalette.primary, size: 24),
              SizedBox(width: 10),
              Text(
                'My Technology Proposals',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTechStatusList(),
        ],
      ),
    );
  }

  Widget _buildTechStatusList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('proposed_technologies')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyState(Icons.error_outline, 'Could not load proposals',
              '${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs =
            (snapshot.data?.docs ?? <QueryDocumentSnapshot>[]).where((d) {
          final data = d.data() as Map<String, dynamic>;
          final by = (data['submittedBy'] ?? '').toString();
          final name = (data['expertName'] ?? '').toString();
          return by == _expertId ||
              (name.isNotEmpty && name == _myName) ||
              by == 'Expert User';
        }).toList();
        if (docs.isEmpty) {
          return _emptyState(
            Icons.biotech_outlined,
            'No proposals yet',
            'Submit your first technology proposal using the form above.',
          );
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? 'Pending').toString();
            final color = AppPalette.statusColor(status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: HoverCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    IconBubble(
                        icon: Icons.biotech_rounded, color: color, size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['techName'] ?? 'Unnamed Technology',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppPalette.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${data['category'] ?? 'General'} · ${(data['purpose'] ?? '').toString().length > 60 ? '${(data['purpose'] ?? '').toString().substring(0, 60)}…' : (data['purpose'] ?? '')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppPalette.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusChip(status, color: color),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ============================ SETTINGS ============================
  Widget _buildSettingsView() {
    final initials = _myName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.settings_suggest_rounded,
            title: 'Account Settings',
            subtitle: 'Your profile information and account options.',
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: AppPalette.primary,
                      child: Text(
                        initials.isEmpty ? 'E' : initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_myName,
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.textPrimary)),
                          const SizedBox(height: 4),
                          Text(_myEmail.isEmpty ? 'No email on file' : _myEmail,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppPalette.textSecondary)),
                        ],
                      ),
                    ),
                    StatusChip(
                        _myDepartment.isEmpty ? 'Expert' : _myDepartment),
                  ],
                ),
                const Divider(height: 32),
                _settingRow(Icons.badge_outlined, 'Full Name', _myName),
                const SizedBox(height: 12),
                _settingRow(Icons.email_outlined, 'Email Address',
                    _myEmail.isEmpty ? '—' : _myEmail),
                const SizedBox(height: 12),
                _settingRow(Icons.account_tree_outlined, 'Department',
                    _myDepartment.isEmpty ? '—' : _myDepartment),
                const SizedBox(height: 12),
                _settingRow(Icons.workspace_premium_outlined, 'Role',
                    'Expert / Instructor'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassCard(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Actions',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                    'Update your password or sign out of the GIC Expert Portal.',
                    style: TextStyle(
                        fontSize: 12.5, color: AppPalette.textMuted)),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Change Password',
                  icon: Icons.lock_reset_rounded,
                  height: 46,
                  fontSize: 14,
                  onPressed: _changePassword,
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Logout Account',
                  icon: Icons.logout_rounded,
                  height: 46,
                  fontSize: 14,
                  colors: const [Color(0xFFF87171), Color(0xFFDC2626)],
                  onPressed: _handleLogout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'GIC Expert Portal · Gofa Industrial College',
              style: TextStyle(fontSize: 11.5, color: AppPalette.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(IconData icon, String label, String value) {
    return Row(
      children: [
        IconBubble(icon: icon, color: AppPalette.primary, size: 36),
        const SizedBox(width: 14),
        Text(label,
            style: const TextStyle(
                fontSize: 12.5,
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppPalette.textPrimary),
          ),
        ),
      ],
    );
  }

  // ============================ SHARED ============================
  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 58,
                color: AppPalette.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: AppPalette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
