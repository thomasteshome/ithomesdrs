import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryScreen extends StatelessWidget {
  final String expertEmail;
  final Function(Map<String, dynamic>) onDownload;

  const HistoryScreen({
    super.key,
    required this.expertEmail,
    required this.onDownload,
  });

  // Modern Color Palette matching your theme
  final Color primaryDark = const Color(0xFF1A237E);
  final Color bgLight = const Color(0xFFF4F7FA);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgLight, // Consistent background color
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('visits')
            .where('expertEmail', isEqualTo: expertEmail)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildHistoryCard(context, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "No support history yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const Text("Your submitted reports will appear here.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Bar (Blue)
              Container(width: 6, color: primaryDark),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Industry Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryDark.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              data['industryCategory']?.toUpperCase() ?? "GENERAL",
                              style: TextStyle(color: primaryDark, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            data['visitDate'] ?? "",
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data['enterpriseName'] ?? "Unknown Enterprise",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF263238)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            "Woreda: ${data['woreda']}",
                            style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      // Short Preview of Tasks
                      Text(
                        "Tasks: ${data['tasksAccomplished']}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),

              // Right Action Area
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(left: BorderSide(color: Colors.grey.shade100)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                  onPressed: () => onDownload(data),
                  tooltip: "Download PDF",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}