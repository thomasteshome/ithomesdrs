import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/expert_sidebar.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Ensure this is at the top

class ExpertDashboard extends StatefulWidget {
  const ExpertDashboard({super.key});

  @override
  State<ExpertDashboard> createState() => _ExpertDashboardState();
}

class _ExpertDashboardState extends State<ExpertDashboard> {
  int _currentIndex = 0;

  // Controllers for Plan Submission
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _techNameController = TextEditingController();
  final TextEditingController _techCategoryController = TextEditingController();
  final TextEditingController _techReasonController = TextEditingController();
  final TextEditingController _sectorController = TextEditingController();
  final TextEditingController _tasksController = TextEditingController();
  final TextEditingController _challengesController = TextEditingController();
  final TextEditingController _solutionsController = TextEditingController();
  final TextEditingController _verifierController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
final TextEditingController _outcomeController = TextEditingController();
final TextEditingController _resourcesController = TextEditingController();

  @override
  void dispose() {
    _targetController.dispose();
    _descController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
      _techNameController.dispose();
    _techCategoryController.dispose();
    _techReasonController.dispose();
    _locationController.dispose();
  _outcomeController.dispose();
    _resourcesController.dispose();
   _sectorController.dispose();
    _tasksController.dispose();
   _challengesController.dispose();
    _solutionsController.dispose();
   _verifierController.dispose();
     super.dispose();
  
}
Future<void> _submitTechnology() async {
  try {
    await FirebaseFirestore.instance.collection('proposed_technologies').add({
      'techName': _techNameController.text,
      'category': _techCategoryController.text,
      'purpose': _techReasonController.text,
      'status': 'Pending',
      'submittedBy': FirebaseAuth.instance.currentUser?.email ?? 'Expert User',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Clear the boxes after clicking submit
    _techNameController.clear();
    _techCategoryController.clear();
    _techReasonController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Technology Proposal Sent to Dean!")),
    );
  } catch (e) {
    print("Firebase Error: $e");
  }
}
  // Logic: Submit Plan to Firestore
  Future<void> _submitPlan() async {
    if (_targetController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in target and description")),
      );
      return;
    }
// i'll come back here 
    try {
      await FirebaseFirestore.instance.collection('expert_plans').add({
        'targetEnterprise': _targetController.text,
        'description': _descController.text,
        'startDate': _startDateController.text,
        'endDate': _endDateController.text,
        'status': 'Pending',
        'submittedBy': 'Expert User', // Replace with Auth user name
        'dept': 'ICT',                // Replace with user's actual department
        'timestamp': FieldValue.serverTimestamp(),
      });

      _targetController.clear();
      _descController.clear();
      _startDateController.clear();
      _endDateController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Plan submitted successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // Logic: Popup to write the final activity report
  void _showReportDialog(String docId, String enterpriseName, String woreda) {
  // Set initial values if they are already known from the plan
  _sectorController.text = "Construction"; // Example default from your image

  showDialog(
    context: context,
     builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("New Submission", textAlign: TextAlign.center, 
        style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportField("Professional Sector", _sectorController, Icons.category, color: Colors.orange),
            _buildReportField("Enterprise Name", TextEditingController(text: enterpriseName), Icons.business, enabled: false),
            _buildReportField("Woreda", TextEditingController(text: woreda), Icons.location_on, enabled: false),
            _buildReportField("Tasks Performed", _tasksController, Icons.checklist_rtl, isMultiline: true),
            _buildReportField("Challenges", _challengesController, Icons.warning_amber_rounded, isMultiline: true, color: Colors.orange),
            _buildReportField("Solutions Provided", _solutionsController, Icons.lightbulb_outline, isMultiline: true, color: Colors.orange),
            _buildReportField("Verified By", _verifierController, Icons.check_circle_outline, color: Colors.orange),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('expert_plans').doc(docId).update({
                'sector': _sectorController.text,
                'tasksPerformed': _tasksController.text,
                'challenges': _challengesController.text,
                'solutionsProvided': _solutionsController.text,
                'verifiedBy': _verifierController.text,
                'status': 'Completed',
                'reportDate': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Support Report Submitted!")));
            },
            child: const Text("SUBMIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}

// Helper to match your UI design
Widget _buildReportField(String label, TextEditingController controller, IconData icon, 
    {bool isMultiline = false, Color color = Colors.grey, bool enabled = true}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextField(
      controller: controller,
      maxLines: isMultiline ? 3 : 1,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        filled: true,
        fillColor: Colors.blueGrey.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          ExpertSidebar(
          currentIndex: _currentIndex,
          onTabSelected: (index) {
          if (index == 6) {
                _handleLogout(); // Use the same _handleLogout logic we wrote for the Dean
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
                      _buildPlanSubmissionForm(),
                      _buildMyReportsTable(),
                      _buildTechSubmissionForm(),
                      const Center(child: Text("My Schedule View")),
                      const Center(child: Text("Account Settings")),
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
Widget _buildTechSubmissionForm() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PART 1: THE INPUT FORM
        _buildTechInputCard(),
        
        const SizedBox(height: 40),
        const Divider(),
        const SizedBox(height: 20),
        
        // PART 2: THE SUBMISSION HISTORY LIST
        const Text("My Technology Proposals", 
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 15),
        _buildTechStatusList(),
      ],
    ),
  );
}

// Separate widget for the Form Card to keep code clean
Widget _buildTechInputCard() {
  return Container(
    constraints: const BoxConstraints(maxWidth: 800),
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.biotech, color: Colors.indigoAccent),
            SizedBox(width: 10),
            Text("Propose New Technology", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 25),
        TextField(
          controller: _techNameController, 
          decoration: const InputDecoration(labelText: "Technology Name", border: OutlineInputBorder())
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _techCategoryController, 
          decoration: const InputDecoration(labelText: "Category (e.g. AI, IoT, Cloud)", border: OutlineInputBorder())
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _techReasonController, 
          maxLines: 3, 
          decoration: const InputDecoration(
            labelText: "Purpose & Benefits", 
            hintText: "How will this help Gofa Industrial College?",
            border: OutlineInputBorder()
          )
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _submitTechnology, 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            child: const Text("Submit Proposal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}

// PART 3: THE LIST OF PREVIOUS ENTRIES
Widget _buildTechStatusList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('proposed_technologies')
        .where('submittedBy', isEqualTo: FirebaseAuth.instance.currentUser?.email ?? 'Expert User')
        .orderBy('timestamp', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Text("Error: ${snapshot.error}");
      if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();

      final docs = snapshot.data?.docs ?? [];
      if (docs.isEmpty) {
        return const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Text("No technologies proposed yet.", style: TextStyle(color: Colors.grey)),
        );
      }

      return ListView.builder(
        shrinkWrap: true, // Crucial because it's inside a SingleChildScrollView
        physics: const NeverScrollableScrollPhysics(), 
        itemCount: docs.length,
        itemBuilder: (context, index) {
          var data = docs[index].data() as Map<String, dynamic>;
          Color statusColor = data['status'] == 'Approved' ? Colors.green : Colors.orange;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              title: Text(data['techName'] ?? "Unnamed Tech", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(data['category'] ?? "General"),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data['status'] ?? "Pending",
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
  Widget _buildHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Text("Instructor Service Portal", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
          const Spacer(),
          const Icon(Icons.notifications_none, color: Colors.grey),
          const SizedBox(width: 20),
          const VerticalDivider(indent: 20, endIndent: 20),
          const SizedBox(width: 20),
          const Text("Expert Mode", 
            style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          const SizedBox(width: 15),
          const CircleAvatar(radius: 16, backgroundColor: Colors.blueAccent, child: Icon(Icons.bolt, size: 18, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('expert_plans').snapshots(),
        builder: (context, snapshot) {
          int total = snapshot.hasData ? snapshot.data!.docs.length : 0;
          int pending = snapshot.hasData 
              ? snapshot.data!.docs.where((d) => d['status'] == 'Pending').length : 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Expert Overview", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  _infoCard("My Plans", "$pending Pending", Icons.assignment, Colors.orange),
                  const SizedBox(width: 20),
                  _infoCard("Activity Reports", "$total Total Submitted", Icons.check_circle, Colors.green),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(subtitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPlanSubmissionForm() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(40),
    child: Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 850),
        padding: const EdgeInsets.all(35),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_add, color: Colors.blueAccent, size: 28),
                SizedBox(width: 12),
                Text("New Service Plan", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 40),

            // ENTERPRISE & LOCATION
            Row(
              children: [
                Expanded(
                  child: _buildFieldLabel("Target Enterprise", _targetController, Icons.business),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildFieldLabel("Specific Location/Woreda", _locationController, Icons.location_on),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // OBJECTIVES
            const Text("Detailed Objectives", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "What specific problems are you solving?",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            const SizedBox(height: 25),

            // EXPECTED OUTCOMES (New Field)
            const Text("Expected Outcomes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _outcomeController,
              decoration: InputDecoration(
                hintText: "e.g., Improved production by 20%, Staff trained on IoT",
                prefixIcon: const Icon(Icons.trending_up, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            const SizedBox(height: 25),

            // RESOURCES NEEDED (New Field)
            const Text("Resources/Tools Required", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _resourcesController,
              decoration: InputDecoration(
                hintText: "e.g., Laptop, GIC Service Vehicle, Measurement Tools",
                prefixIcon: const Icon(Icons.construction, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            const SizedBox(height: 35),
            
            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _submitPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Submit Formal Plan", 
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper widget to keep the code clean
Widget _buildFieldLabel(String label, TextEditingController controller, IconData icon) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ],
  );
}

  Widget _buildMyReportsTable() {
  return Padding(
    padding: const EdgeInsets.all(30),
    child: StreamBuilder<QuerySnapshot>(
      // Listen to all plans submitted by experts
      stream: FirebaseFirestore.instance
          .collection('expert_plans')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No plans submitted yet. Go to 'New Service Plan' to start."));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            
            bool isPending = data['status'] == 'Pending';
            bool isCompleted = data['status'] == 'Completed';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                leading: Icon(
                  isCompleted ? Icons.verified : Icons.pending_actions,
                  color: isCompleted ? Colors.blue : Colors.orange,
                ),
                title: Text(data['targetEnterprise'] ?? "N/A", 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Status: ${data['status']}"),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Objectives: ${data['description']}"),
                        const SizedBox(height: 10),
                        Text("Duration: ${data['startDate']} to ${data['endDate']}"),
                        const Divider(height: 30),
                        
                        // Action Logic
                        if (isPending) 
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                             onPressed: () => _showReportDialog(
                                    doc.id, 
                                      data['targetEnterprise'] ?? "N/A", 
                                        data['location'] ?? "Unknown"
                                          ),
                              icon: const Icon(Icons.edit_document),
                              label: const Text("Write Final Activity Report"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          )
                        else if (isCompleted)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Final Report:", style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text(data['finalReport'] ?? "No report text found."),
                              const SizedBox(height: 10),
                              const Text("Status: Submitted to Dean ✅", 
                                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
  // Add this inside _ExpertDashboardState
  void _handleLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to sign out? Any unsaved changes will be lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
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
      try {
        await FirebaseAuth.instance.signOut();
        // No Navigator needed! AuthGate in main.dart handles the switch.
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Logout failed: $e")),
          );
        }
      }
    }
  }
}