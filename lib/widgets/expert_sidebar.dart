import 'package:flutter/material.dart';

class ExpertSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const ExpertSidebar(
      {super.key, required this.currentIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 18, offset: Offset(4, 0)),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 36),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF6366F1).withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.person_pin_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 14),
          const Text(
            "EXPERT PORTAL",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.6,
            ),
          ),
          const Text(
            "Gofa Industrial College",
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 26),
          const Divider(color: Colors.white12, indent: 20, endIndent: 20),
          Expanded(
            child: Column(
              children: [
                _navTile(Icons.dashboard_customize_rounded, "My Overview", 0),
                _navTile(Icons.calendar_month_rounded, "Schedule", 1),
                _navTile(Icons.note_add_rounded, "Submit Plan", 2),
                _navTile(Icons.fact_check_rounded, "Support Reports", 3),
                _navTile(Icons.contacts_outlined, "Enterprise Contacts", 4),
                _navTile(Icons.biotech_rounded, "Propose Tech", 5),
                _navTile(Icons.settings_suggest_rounded, "Settings", 6),
                const Spacer(),
                const Divider(color: Colors.white12, height: 1),
                _navTile(Icons.logout_rounded, "Logout Account", 7,
                    isLogout: true),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "©GIC Expert Portal",
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(IconData icon, String title, int index,
      {bool isLogout = false}) {
    final bool isSelected = currentIndex == index;
    final Color accent =
        isLogout ? const Color(0xFFF87171) : const Color(0xFFA5B4FC);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.white.withValues(alpha: 0.14))
              : null,
        ),
        child: ListTile(
          onTap: () => onTabSelected(index),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(
            icon,
            color: isLogout
                ? const Color(0xFFF87171)
                : (isSelected ? accent : Colors.white60),
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isLogout
                  ? const Color(0xFFF87171)
                  : (isSelected ? Colors.white : Colors.white70),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.chevron_right,
                  color: Color(0xFFA5B4FC), size: 16)
              : null,
        ),
      ),
    );
  }
}
