import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/dept_head_sidebar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeptHeadDashboard extends StatefulWidget {
  const DeptHeadDashboard({super.key});

  @override
  State<DeptHeadDashboard> createState() => _DeptHeadDashboardState();
}

class _DeptHeadDashboardState extends State<DeptHeadDashboard> {
  int _currentIndex = 0;
  
  // Controllers for the Broadcast Tool
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Logic: Send Broadcast to Firestore
  Future<void> _sendBroadcast() async {
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('broadcasts').add({
      'subject': _subjectController.text,
      'body': _messageController.text,
      'sender': 'Department Head',
      'dept': 'ICT', // You can make this dynamic based on logged-in user
      'timestamp': FieldValue.serverTimestamp(),
    });

    _subjectController.clear();
    _messageController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Announcement Broadcasted Successfully!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          DeptHeadSidebar(
  currentIndex: _currentIndex,
  onTabSelected: (index) {
    if (index == 5) {
      _handleLogout(); // This must match the name of your logout function
    } else {
      setState(() => _currentIndex = index);
    }
  },
),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildOverview(),
                      _buildReviewPlansTable(),
                      _buildBroadcastTool(),
                      _buildStaffAccessTable(),
                      const Center(child: Text("Settings")),
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

  Widget _buildHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: Colors.white, 
        border: Border(bottom: BorderSide(color: Colors.black12))
      ),
      child: Row(
        children: [
          const Text("Department Management Portal", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          const Text("Head of Dept", 
            style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
          const SizedBox(width: 20),
          const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 20)),
        ],
      ),
    );
  }

  Widget _buildBroadcastTool() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Broadcast Announcement", 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Column(
              children: [
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: "Subject", 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _messageController,
                  maxLines: 5, 
                  decoration: const InputDecoration(
                    labelText: "Message Body", 
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _sendBroadcast,
                    icon: const Icon(Icons.send),
                    label: const Text("Send to All Staff"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffAccessTable() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Staff & Instructor Access", 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('dept', isEqualTo: 'ICT') // Scoped to Dept
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  return SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text("Name")),
                        DataColumn(label: Text("Role")),
                        DataColumn(label: Text("Actions")),
                      ],
                      rows: snapshot.data!.docs.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        return DataRow(cells: [
                          DataCell(Text(data['name'] ?? "User")),
                          DataCell(Chip(label: Text(data['role'] ?? "Staff"))),
                          DataCell(IconButton(
                            icon: const Icon(Icons.settings_backup_restore, color: Colors.orange),
                            onPressed: () {}, // Reset password logic
                          )),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
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
          child: const Text("Cancel")
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(context, true), 
          child: const Text("Logout", style: TextStyle(color: Colors.white))
        ),
      ],
    ),
  );

  if (confirm == true) {
    await FirebaseAuth.instance.signOut();
  }
}

  Widget _buildOverview() => const Center(child: Text("Welcome, Dept Head. Access your tools via the sidebar."));
  Widget _buildReviewPlansTable() => const Center(child: Text("Instructor Plans Awaiting Approval"));
}