import 'package:flutter/material.dart';

class DeptHeadSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const DeptHeadSidebar({super.key, required this.currentIndex, required this.onTabSelected});

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
          BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(4, 0)),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 36),
          // Brand mark
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
                  color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.manage_accounts, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 14),
          const Text(
            "DEPARTMENT HEAD",
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
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _navTile(Icons.dashboard_outlined, "Overview", 0),
                _navTile(Icons.fact_check_outlined, "Plans & Reports", 1),
                _navTile(Icons.contacts_outlined, "Enterprise Contacts", 2),
                _navTile(Icons.campaign_outlined, "Broadcast Tool", 3),
                _navTile(Icons.manage_accounts_outlined, "User Management", 4),
                _navTile(Icons.calendar_month_rounded, "Schedule", 5),
                _navTile(Icons.biotech_outlined, "Tech & Feedback", 6),
                _navTile(Icons.settings_outlined, "Settings", 7),

                const Divider(color: Colors.white12, height: 40),
                _navTile(Icons.logout_rounded, "Logout", 8, isLogout: true),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              "©GIC Portal",
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(IconData icon, String title, int index, {bool isLogout = false}) {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              ? const Icon(Icons.chevron_right, color: Color(0xFFA5B4FC), size: 16)
              : null,
        ),
      ),
    );
  }
}
