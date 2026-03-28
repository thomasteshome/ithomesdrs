import 'package:flutter/material.dart';

class DeptHeadSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const DeptHeadSidebar({super.key, required this.currentIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF1e1b4b), // Distinct Indigo for Dept Head
      child: Column(
        children: [
          const SizedBox(height: 40),
          const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white24,
            child: Icon(Icons.manage_accounts, color: Colors.white, size: 35),
          ),
          const SizedBox(height: 15),
          const Text("DEPARTMENT HEAD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const Text("Gofa Industrial College", style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 30),
          const Divider(color: Colors.white10, indent: 20, endIndent: 20),
         Expanded(
  child: ListView(
    children: [
      _navTile(Icons.dashboard_outlined, "Overview", 0),
      _navTile(Icons.assignment_outlined, "Review Plans", 1),
      _navTile(Icons.campaign_outlined, "Broadcast Tool", 2),
      _navTile(Icons.people_outline, "Staff Access", 3),
      _navTile(Icons.settings_outlined, "Settings", 4),
      
      // --- ADD THE LOGOUT BUTTON HERE ---
      const Divider(color: Colors.white10, height: 40),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.redAccent),
        title: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
        onTap: () => onTabSelected(5), // Send index 5 to the Dashboard
      ),
    ],
  ),
),
        ],
      ),
    );
  }

  Widget _navTile(IconData icon, String title, int index) {
    bool isSelected = currentIndex == index;
    return ListTile(
      onTap: () => onTabSelected(index),
      leading: Icon(icon, color: isSelected ? Colors.amberAccent : Colors.white60, size: 20),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 13)),
      selected: isSelected,
    );
  }
}