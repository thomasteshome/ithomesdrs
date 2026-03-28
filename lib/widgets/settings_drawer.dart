import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  Future<void> _changePassword(BuildContext context, String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset link sent to your email!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Color gofaBlue = const Color(0xFF1A237E);

    return Drawer(
      child: Column(
        children: [
          // User Header
          UserAccountsDrawerHeader(
            backgroundColor: gofaBlue,
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Color(0xFF1A237E)),
            ),
            accountName: const Text("Gofa College User"), // You can fetch fullName from Firestore here
            accountEmail: Text(user?.email ?? "No Email"),
          ),

          // Change Password Option
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text("Change Password"),
            subtitle: const Text("Send reset link to email"),
            onTap: () => _changePassword(context, user!.email!),
          ),

          const Divider(),

          // Logout Option
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Logout"),
                  content: const Text("Are you sure you want to sign out?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                    TextButton(
                      onPressed: () {
                        FirebaseAuth.instance.signOut();
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      }, 
                      child: const Text("Logout", style: TextStyle(color: Colors.red))
                    ),
                  ],
                ),
              );
            },
          ),
          
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("FOMIS v1.0", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}