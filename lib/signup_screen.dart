import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'validators.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _selectedRole = 'expert'; 
  String _selectedDept = 'ICT'; 
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final Color primaryDark = const Color(0xFF0D47A1);
  final Color accentBlue = const Color(0xFF1976D2);

  final List<String> _departments = [
    "Textile", "Construction", "Automotive", "Manufacturing", "ICT"
  ];

  Future<void> _handleSignup() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showMessage("Please fill all fields", isError: true);
      return;
    }
    final emailError = emailField(_emailController.text);
    if (emailError != null) {
      _showMessage(emailError, isError: true);
      return;
    }
    if (_passwordController.text.length < 6) {
      _showMessage("Password must be at least 6 characters", isError: true);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage("Passwords do not match", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'department': _selectedRole == 'dean' ? 'College Administration' : _selectedDept,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showMessage("Registration Successful!");
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? "An error occurred", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryDark, accentBlue, const Color(0xFF42A5F5)],
              ),
            ),
          ),
          // Decorative Blurred Shapes
          Positioned(top: -100, left: -50, child: _circle(250, Colors.white12)),
          Positioned(bottom: -50, right: -50, child: _circle(200, Colors.white10)),

          // 2. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 30),
                    
                    // 3. Glass Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _inputField(_nameController, "Full Name", Icons.person_outline),
                              const SizedBox(height: 15),
                              _inputField(_emailController, "Email Address", Icons.email_outlined),
                              const SizedBox(height: 15),
                              _inputField(_passwordController, "Password", Icons.lock_outline, isPass: true),
                              const SizedBox(height: 15),
                              _inputField(_confirmPasswordController, "Confirm Password", Icons.lock_reset, isPass: true),
                              const SizedBox(height: 20),
                              
                              _sectionLabel("Access Level"),
                              _buildDropdown(
                                value: _selectedRole,
                                items: const {
                                  'expert': 'Expert / Teacher',
                                  'deptHead': 'Department Head',
                                  'dean': 'College Dean'
                                },
                                icon: Icons.admin_panel_settings,
                                onChanged: (v) => setState(() => _selectedRole = v!),
                              ),
                              
                              if (_selectedRole != 'dean') ...[
                                const SizedBox(height: 15),
                                _sectionLabel("Department"),
                                _buildDropdown(
                                  value: _selectedDept,
                                  items: {for (var d in _departments) d: d},
                                  icon: Icons.account_tree_outlined,
                                  onChanged: (v) => setState(() => _selectedDept = v!),
                                ),
                              ],
                              
                              const SizedBox(height: 30),
                              _signupButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _loginLink(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _buildHeader() {
    return Column(
      children: [
        // FIXED ICON HERE
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const Icon(Icons.person_add_rounded, size: 60, color: Colors.white),
        ),
        const SizedBox(height: 15),
        const Text("CREATE ACCOUNT", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
        Text("Join the GIC Portal", style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w300)),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 5, bottom: 8),
    child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
  );

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {bool isPass = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass ? !_isPasswordVisible : false,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: isPass ? IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white70, size: 20),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ) : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white70)),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }

  Widget _buildDropdown({required String value, required Map<String, String> items, required IconData icon, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: primaryDark,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Row(
            children: [Icon(icon, size: 18, color: Colors.white70), const SizedBox(width: 10), Text(e.value)],
          ))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _signupButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(colors: [Colors.white, Color(0xFFBBDEFB)]),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignup,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading 
          ? CircularProgressIndicator(color: primaryDark) 
          : Text("SIGN UP NOW", style: TextStyle(color: primaryDark, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    );
  }

  Widget _loginLink() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: RichText(
        text: const TextSpan(
          text: "Already registered? ",
          style: TextStyle(color: Colors.white70),
          children: [
            TextSpan(text: "Login here", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
          ],
        ),
      ),
    );
  }
}