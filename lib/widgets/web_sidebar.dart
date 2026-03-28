import 'package:flutter/material.dart';

class WebSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const WebSidebar({super.key, required this.currentIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF0F172A), // Deep Navy for Gofa College Web
      child: Column(
        children: [
          // College Logo & Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Icon(Icons.school, size: 40)),
                const SizedBox(height: 12),
                const Text("GOFA INDUSTRIAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text("COLLEGE", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          // Scrollable Menu Items from your dashboard.docx
          Expanded(
            child: ListView(
              children: [
                _drawerItem(Icons.dashboard, "Dashboard", 0),
                _drawerItem(Icons.assignment, "Expert Plan", 1),
                _drawerItem(Icons.business, "Enterprise List", 2),
                _drawerItem(Icons.location_on, "Enterprise Location", 3),
                _drawerItem(Icons.star, "Model Enterprise", 4),
                _drawerItem(Icons.event_note, "Schedule", 5),
                _drawerItem(Icons.biotech, "Technology", 6),
                _drawerItem(Icons.assessment, "Support Report", 7),
                _drawerItem(Icons.settings, "User Setting", 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int index) {
    bool selected = currentIndex == index;
    return ListTile(
      selected: selected,
      leading: Icon(icon, color: selected ? Colors.blueAccent : Colors.white60),
      title: Text(title, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      onTap: () => onTabSelected(index),
      hoverColor: Colors.white10,
    );
  }
}