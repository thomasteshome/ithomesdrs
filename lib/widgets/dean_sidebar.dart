import 'package:flutter/material.dart';

class DeanSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const DeanSidebar({super.key, required this.currentIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF0F172A), 
      child: Column(
        children: [
          const SizedBox(height: 50),
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(Icons.account_balance_rounded, color: Color(0xFF0F172A), size: 40),
          ),
          const SizedBox(height: 15),
          const Text("GOFA INDUSTRIAL COLLEGE", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const Text("OFFICE OF THE DEAN", 
            style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.2)),
          const SizedBox(height: 40),
          const Divider(color: Colors.white10, indent: 20, endIndent: 20),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _navTile(Icons.analytics_outlined, "System Overview", 0),
                _navTile(Icons.business_center_outlined, "Enterprise Database", 1),
                _navTile(Icons.map_outlined, "Location Tracking", 2),
                _navTile(Icons.verified_user_outlined, "Model Enterprises", 3),
                _navTile(Icons.people_alt_outlined, "Staff Management", 4),
                _navTile(Icons.summarize_outlined, "Support Reports", 5),
                _navTile(Icons.biotech_outlined, "Technology Transfer", 6),
                _navTile(Icons.settings_suggest_outlined, "System Settings", 7),
                
                // --- ADDED LOGOUT TILE ---
                const Divider(color: Colors.white10, height: 40),
                _navTile(Icons.logout_rounded, "Logout Account", 8, isLogout: true),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(20),
            child: Text("©Gofa Industrial College", style: TextStyle(color: Colors.white24, fontSize: 10)),
          )
        ],
      ),
    );
  }

  // Modified helper to handle the logout style
  Widget _navTile(IconData icon, String title, int index, {bool isLogout = false}) {
    bool isSelected = currentIndex == index;
    
    // Use red for logout, blue for selected, white60 for others
    Color iconColor = isLogout ? Colors.redAccent : (isSelected ? Colors.blueAccent : Colors.white60);
    Color textColor = isLogout ? Colors.redAccent : (isSelected ? Colors.white : Colors.white70);

    return ListTile(
      onTap: () => onTabSelected(index),
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(title, style: TextStyle(
        color: textColor, 
        fontSize: 13, 
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      )),
      selected: isSelected && !isLogout, // Don't highlight logout as "selected"
      selectedTileColor: Colors.white.withOpacity(0.05),
    );
  }
}