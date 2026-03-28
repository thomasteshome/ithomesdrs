import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TechSubmissionForm extends StatefulWidget {
  const TechSubmissionForm({super.key});

  @override
  State<TechSubmissionForm> createState() => _TechSubmissionFormState();
}

class _TechSubmissionFormState extends State<TechSubmissionForm> {
  final _formKey = GlobalKey<FormState>();
  final Color primaryBlue = const Color(0xFF0D47A1);
  final Color accentGold = const Color(0xFFFFB300);

  // Controllers for Enterprise Info
  final TextEditingController _enterpriseController = TextEditingController();
  final TextEditingController _woredaController = TextEditingController();

  // Controllers for Technology Info
  final TextEditingController _techNameController = TextEditingController();
  final TextEditingController _techScopeController = TextEditingController();
  final TextEditingController _techDescController = TextEditingController();

  bool _isSubmitting = false;

  Future<void> _submitTechReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      // Fetching the expert's department to tag the report automatically
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final department = userDoc.data()?['assignedCategory'] ?? 'General';

      await FirebaseFirestore.instance.collection('visits').add({
        'expertEmail': user.email,
        'expertUid': user.uid,
        'industryCategory': department,
        'enterpriseName': _enterpriseController.text.trim(),
        'woreda': _woredaController.text.trim(),
        
        // Specific Technology Fields
        'technologyName': _techNameController.text.trim(),
        'technologyScope': _techScopeController.text.trim(),
        'technologyDescription': _techDescController.text.trim(),
        
        'isTechnologyProject': true, // Flag to differentiate from basic support
        'visitDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Technology Report Submitted Successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submission Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Technology Transfer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(Icons.business, "Enterprise Details"),
              const SizedBox(height: 15),
              _buildTextField(_enterpriseController, "Enterprise Name", "Enter company name"),
              const SizedBox(height: 15),
              _buildTextField(_woredaController, "Woreda / Location", "e.g. Woreda 03"),
              
              const SizedBox(height: 30),
              _sectionHeader(Icons.precision_manufacturing, "Technology Specifications"),
              const SizedBox(height: 15),
              _buildTextField(_techNameController, "Technology Name", "e.g. Solar Irrigation Pump"),
              const SizedBox(height: 15),
              _buildTextField(_techScopeController, "Technology Scope", "e.g. Prototype Development / Training"),
              const SizedBox(height: 15),
              _buildTextField(
                _techDescController, 
                "Full Description", 
                "Detail the technical specs and transfer process...", 
                maxLines: 4
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTechReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SUBMIT TECHNOLOGY REPORT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: accentGold, size: 28),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue)),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentGold, width: 2)),
      ),
      validator: (value) => value == null || value.isEmpty ? "This field is required" : null,
    );
  }
}