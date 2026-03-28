import 'package:flutter/material.dart';

class ExpertSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const ExpertSidebar({super.key, required this.currentIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF1E293B), 
      child: Column(
        children: [
          const SizedBox(height: 40),
          const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white10,
            child: Icon(Icons.person_pin_rounded, color: Colors.white, size: 35),
          ),
          const SizedBox(height: 15),
          const Text("EXPERT PORTAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const Text("Gofa Industrial College", style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 30),
          const Divider(color: Colors.white10, indent: 20, endIndent: 20),
          
          Expanded(
  child: Column( // Switch the Column inside Expanded to separate top/bottom
    children: [
      // TOP SECTION: Navigation
      _navTile(Icons.dashboard_customize_rounded, "My Overview", 0),
      _navTile(Icons.note_add_rounded, "Submit Plan", 1),
      _navTile(Icons.fact_check_rounded, "Support Reports", 2),
      _navTile(Icons.biotech_rounded, "Propose Tech", 3), 
      _navTile(Icons.calendar_today_rounded, "My Schedule", 4),
      _navTile(Icons.settings_suggest_rounded, "Settings", 5),
      
      const Spacer(), // <--- THIS PUSHES EVERYTHING BELOW IT TO THE BOTTOM
      
      const Divider(color: Colors.white10, height: 1),
      _navTile(Icons.logout_rounded, "Logout Account", 6, isLogout: true),
      
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text("©GIC Expert Portal", style: TextStyle(color: Colors.white24, fontSize: 10)),
      )
    ],
  ),
),
        ],
      ),
    );
  }

  Widget _navTile(IconData icon, String title, int index, {bool isLogout = false}) {
    bool isSelected = currentIndex == index;
    
    Color iconColor = isLogout ? Colors.redAccent : (isSelected ? Colors.cyanAccent : Colors.white60);
    Color textColor = isLogout ? Colors.redAccent : (isSelected ? Colors.white : Colors.white70);

    return ListTile(
      onTap: () => onTabSelected(index),
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(title, style: TextStyle(
        color: textColor, 
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      )),
      selected: isSelected && !isLogout,
    );
  }
}