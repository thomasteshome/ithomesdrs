import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart' as ex; 
import 'package:file_saver/file_saver.dart';
import 'widgets/dean_sidebar.dart'; 
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart'; // Optional for sparklines
import 'package:syncfusion_flutter_charts/charts.dart' hide PieSeries; // This is a trick to reset the link
import 'dart:math';

class DeanDashboard extends StatefulWidget {
  const DeanDashboard({super.key});

  @override
  State<DeanDashboard> createState() => _DeanDashboardState();
}

class _DeanDashboardState extends State<DeanDashboard> {
  int _currentIndex = 0;
  double? selectedLat;
  double? selectedLng;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ""; // To store the current search text
  String _activeSettingSubPage = "main"; // "main", "regional", "sectors", etc.
  final TextEditingController _woredaController = TextEditingController();
@override
  void dispose() {
    _searchController.dispose();
    _woredaController.dispose();
    super.dispose();
  }
  // --- 1. EXPORT TO EXCEL LOGIC ---
  Future<void> _exportToExcel() async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheetObject = excel['Enterprise_Report'];
    excel.delete('Sheet1');

    List<ex.CellValue> headers = [
      ex.TextCellValue("LMIS #"), ex.TextCellValue("Enterprise Name"),
      ex.TextCellValue("Representative"), ex.TextCellValue("Phone"),
      ex.TextCellValue("Sector"), ex.TextCellValue("Sub-Sector"),
      ex.TextCellValue("Woreda"), ex.TextCellValue("Male"),
      ex.TextCellValue("Female"), ex.TextCellValue("Total")
    ];
    sheetObject.appendRow(headers);

    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('enterprises').get();

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      sheetObject.appendRow([
        ex.TextCellValue(data['lmis'] ?? ""),
        ex.TextCellValue(data['entName'] ?? ""),
        ex.TextCellValue(data['repName'] ?? ""),
        ex.TextCellValue(data['phone'] ?? ""),
        ex.TextCellValue(data['sector'] ?? ""),
        ex.TextCellValue(data['subSector'] ?? ""),
        ex.TextCellValue(data['woreda'] ?? ""),
        ex.IntCellValue(data['maleCount'] ?? 0),
        ex.IntCellValue(data['femaleCount'] ?? 0),
        ex.IntCellValue(data['totalCount'] ?? 0),
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      await FileSaver.instance.saveFile(
        name: "GIC_Enterprise_Registry",
        bytes: Uint8List.fromList(fileBytes),
        ext: "xlsx",
        mimeType: MimeType.microsoftExcel,
      );
    }
  }

  // --- 2. DETAIL DIALOG (SHOW ALL INFO) ---
  void _showEnterpriseDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(data['entName'] ?? "Enterprise Details"),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _detailRow("LMIS Number", data['lmis']),
                _detailRow("Representative", data['repName']),
                _detailRow("Phone", data['phone']),
                const Divider(),
                _detailRow("Main Sector", data['sector']),
                _detailRow("Sub Sector", data['subSector']),
                _detailRow("Woreda", data['woreda']),
                const Divider(),
                _detailRow("Male Count", data['maleCount']?.toString()),
                _detailRow("Female Count", data['femaleCount']?.toString()),
                _detailRow("Total Operators", data['totalCount']?.toString(), isBold: true),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Widget _detailRow(String label, String? value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey)),
          Text(value ?? "N/A", style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  // --- 3. REGISTRATION FORM ---
  void _showAddEnterpriseForm() {
  final nameController = TextEditingController();
  final lmisController = TextEditingController();
  final sectorController = TextEditingController();
  final subSectorController = TextEditingController();
  final repNameController = TextEditingController();
  final phoneController = TextEditingController();
  final maleCountController = TextEditingController(text: '0');
  final femaleCountController = TextEditingController(text: '0');
  final woredaController = TextEditingController();
  final TextEditingController _woredaController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (context) => StatefulBuilder( // Added to update the "Location Set" text
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 30, right: 30, top: 30),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Official Registration", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _buildField(lmisController, "LMIS #", Icons.tag)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(nameController, "Enterprise Name", Icons.business)),
                ]),
                _buildField(repNameController, "Representative", Icons.person),
                _buildField(phoneController, "Phone", Icons.phone),
                Row(children: [
                  Expanded(child: _buildField(sectorController, "Sector", Icons.category)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(subSectorController, "Sub Sector", Icons.account_tree)),
                ]),
                Row(children: [
                  Expanded(child: _buildField(woredaController, "Woreda", Icons.map)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(maleCountController, "Male", Icons.male, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(femaleCountController, "Female", Icons.female, isNumber: true)),
                ]),
                
                // --- LOCATION PICKER UI ---
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.location_on, color: selectedLat == null ? Colors.grey : Colors.green),
                    title: Text(
                      selectedLat == null 
                        ? "Enterprise Location (Required)" 
                        : "Location Captured: ${selectedLat!.toStringAsFixed(4)}, ${selectedLng!.toStringAsFixed(4)}",
                      style: TextStyle(fontSize: 14, color: selectedLat == null ? Colors.red : Colors.black),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        LatLng? result = await _showMapPickerDialog(context);
                        if (result != null) {
                          setSheetState(() { // Updates the text inside the bottom sheet
                            selectedLat = result.latitude;
                            selectedLng = result.longitude;
                          });
                        }
                      },
                      child: const Text("Pick on Map"),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
                    onPressed: () async {
                      if (_formKey.currentState!.validate() && selectedLat != null) {
                        int m = int.tryParse(maleCountController.text) ?? 0;
                        int f = int.tryParse(femaleCountController.text) ?? 0;
                        
                        await FirebaseFirestore.instance.collection('enterprises').add({
                          'lmis': lmisController.text,
                          'entName': nameController.text,
                          'repName': repNameController.text,
                          'phone': phoneController.text,
                          'sector': sectorController.text,
                          'subSector': subSectorController.text,
                          'woreda': woredaController.text,
                          'maleCount': m,
                          'femaleCount': f,
                          'totalCount': m + f,
                          'lat': selectedLat, // Saving the picked Latitude
                          'lng': selectedLng, // Saving the picked Longitude
                          'isModel': false,
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        // Reset variables for the next registration
                        setState(() {
                          selectedLat = null;
                          selectedLng = null;
                        });
                        
                        Navigator.pop(context);
                      } else if (selectedLat == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please select a location on the map first!")),
                        );
                      }
                    },
                    child: const Text("Save to Database", style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
Future<LatLng?> _showMapPickerDialog(BuildContext context) async {
  LatLng? pickedLocation;
  return showDialog<LatLng>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text("Select Enterprise Location"),
        content: SizedBox(
          width: 500,
          height: 400,
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(6.3275, 37.6611), // Center on Gofa
              zoom: 14,
            ),
            onTap: (pos) {
              setDialogState(() => pickedLocation = pos);
            },
            markers: pickedLocation == null ? {} : {
              Marker(markerId: const MarkerId("picked"), position: pickedLocation!),
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: pickedLocation == null ? null : () => Navigator.pop(context, pickedLocation),
            child: const Text("Confirm Location"),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
      validator: (value) => value!.isEmpty ? "Required" : null,
    );
  }

  // --- 4. MAIN BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          DeanSidebar(
            currentIndex: _currentIndex,
            onTabSelected: (index) {
              if (index == 8) _handleLogout();
              else setState(() => _currentIndex = index);
            },
          ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildOverview(),           // 0: Home
                      _buildEnterpriseDatabase(),      // 1: Registry
                      _buildGISMapView(),               // 2: Map
                      _buildModelEnterpriseView(),     // 3: Model Enterprises
                      _buildStaffManagement(),// 4: Stats
                      _buildSupportReportsView(),      // 5: Reports (REPLACED PLACEHOLDER)
                      _buildPlaceholder("Approvals"),   // 6: Approvals
                      _buildSettingsView(),          // 7: Settings
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          const Text("ESDRS | DEAN PORTAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.file_download, color: Colors.green), onPressed: _exportToExcel, tooltip: "Export to Excel"),
          const SizedBox(width: 20),
          const CircleAvatar(backgroundColor: Color(0xFF0D47A1), child: Icon(Icons.person, color: Colors.white, size: 20)),
        ],
      ),
    );
  }

 Widget _buildEnterpriseDatabase() {
  return Container(
    margin: const EdgeInsets.all(30),
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
    ),
    child: Column(
      children: [
        // --- HEADER & SEARCH BAR ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Enterprise Registry", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search by Name or LMIS...",
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear), 
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        }) 
                    : null,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              ),
            ),

            ElevatedButton.icon(
              onPressed: _showAddEnterpriseForm, 
              icon: const Icon(Icons.add), 
              label: const Text("New Enterprise")
            ),
          ],
        ),
        const SizedBox(height: 20),

        // --- FILTERED DATA TABLE ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('enterprises')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final filteredDocs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['entName'] ?? "").toString().toLowerCase();
                final lmis = (data['lmis'] ?? "").toString().toLowerCase();
                return name.contains(_searchQuery) || lmis.contains(_searchQuery);
              }).toList();

              return Column(
                children: [
                  Expanded(
                    child: filteredDocs.isEmpty 
                      ? Center(child: Text("No enterprises found matching '$_searchQuery'"))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text("LMIS #")),
                                DataColumn(label: Text("Name")),
                                DataColumn(label: Text("Sector")),
                                DataColumn(label: Text("Model?")),
                                DataColumn(label: Text("Actions")),
                              ],
                              rows: filteredDocs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                bool isModel = data['isModel'] ?? false;
                                return DataRow(cells: [
                                  DataCell(Text(data['lmis'] ?? "")),
                                  DataCell(Text(data['entName'] ?? "")),
                                  DataCell(Text(data['sector'] ?? "")),
                                  DataCell(IconButton(
                                    icon: Icon(isModel ? Icons.star : Icons.star_border, color: Colors.amber),
                                    onPressed: () => doc.reference.update({'isModel': !isModel}),
                                  )),
                                  DataCell(Row(children: [
                                    IconButton(icon: const Icon(Icons.visibility, color: Colors.blue), onPressed: () => _showEnterpriseDetails(data)),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => doc.reference.delete()),
                                  ])),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                  ),
                  
                  // --- THE COUNTER FOOTER ---
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _searchQuery.isEmpty 
                            ? "Total Records: ${snapshot.data!.docs.length}"
                            : "Found ${filteredDocs.length} of ${snapshot.data!.docs.length} enterprises",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                        // Quick access to your export logic
                        TextButton.icon(
                          onPressed: _exportToExcel,
                          icon: const Icon(Icons.file_download),
                          label: const Text("Export to Excel"),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
  Widget _buildModelEnterpriseView() {
  return Container(
    margin: const EdgeInsets.all(30),
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.amber.shade200, width: 2),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Model Enterprise Quality Check", 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                Text("Reviewing high-performance status for Gofa Industrial College partners", 
                  style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 25),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('enterprises')
                .where('isModel', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No Model Enterprises designated yet."));
              }

              return ListView.separated(
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.amber,
                        child: Icon(Icons.business, color: Colors.white),
                      ),
                      title: Text(data['entName'] ?? "Unknown", 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("LMIS: ${data['lmis']} | Woreda: ${data['woreda'] ?? 'N/A'}", 
                            style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _statusChip("Male: ${data['maleCount']}", Colors.blue),
                              const SizedBox(width: 8),
                              _statusChip("Female: ${data['femaleCount']}", Colors.pink),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, color: Colors.blueGrey),
                            onPressed: () => _showEnterpriseDetails(data),
                            tooltip: "Full Report",
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            onPressed: () => doc.reference.update({'isModel': false}),
                            tooltip: "Revoke Model Status",
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

// Helper for quick info chips
Widget _statusChip(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}

 void _handleLogout() async {
  bool? confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Confirm Logout"),
      content: const Text("Are you sure you want to sign out of the GIC FOMIS Portal?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Logout", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirm == true) {
    try {
      // This is all you need! 
      // AuthGate will see the change and show LoginScreen automatically.
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logout failed: $e")),
        );
      }
    }
  }
}
Widget _buildSummaryCards() {
  return StreamBuilder<QuerySnapshot>(
    // Stream 1: Fetch Enterprise Registry
    stream: FirebaseFirestore.instance.collection('enterprises').snapshots(),
    builder: (context, entSnapshot) {
      return StreamBuilder<QuerySnapshot>(
        // Stream 2: Fetch Expert Plans/Reports
        stream: FirebaseFirestore.instance.collection('expert_plans').snapshots(),
        builder: (context, planSnapshot) {
          // --- 1. HANDLE LOADING & ERRORS ---
          if (entSnapshot.connectionState == ConnectionState.waiting || 
              planSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LinearProgressIndicator());
          }

          if (!entSnapshot.hasData || !planSnapshot.hasData) {
            return const Text("Data unavailable");
          }

          // --- 2. CALCULATE DYNAMIC VALUES ---
          
          // Total Registered Enterprises
          int totalEnterprises = entSnapshot.data?.docs.length ?? 0;

          // Completed Tech Transfers (Status: 'Completed')
          int techTransfers = planSnapshot.data?.docs
              .where((doc) => doc['status'] == 'Completed')
              .length ?? 0;

          // Staff on Field (Unique experts with 'In Progress' tasks)
          // The '?? 0' at the end is what solves your compilation error!
          int activeStaff = planSnapshot.data?.docs
              .where((doc) => doc['status'] == 'In Progress')
              .map((doc) => doc['expertName'] ?? 'Unknown') 
              .toSet() 
              .length ?? 0;

          // --- 3. RETURN THE UI ---
          return Row(
            children: [
              _kpiCard("Total Enterprises", totalEnterprises.toString(), Icons.business, Colors.blue),
              const SizedBox(width: 20),
              _kpiCard("Tech Transfers", techTransfers.toString(), Icons.bolt, Colors.orange),
              const SizedBox(width: 20),
              _kpiCard("Staff on Field", activeStaff.toString(), Icons.person_pin_circle, Colors.green),
            ],
          );
        },
      );
    },
  );
}
void _deleteStaff(String docId, String name) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Delete Expert?"),
      content: Text("Are you sure you want to remove $name from the system? This cannot be undone."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(docId).delete();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("$name removed successfully")),
            );
          },
          child: const Text("Delete", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
void _editStaff(DocumentSnapshot doc) {
  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  final nameController = TextEditingController(text: data['name']);
  final deptController = TextEditingController(text: data['department'] ?? '');

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Edit Expert Profile"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name")),
          TextField(controller: deptController, decoration: const InputDecoration(labelText: "Department")),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
              'name': nameController.text,
              'department': deptController.text,
            });
            Navigator.pop(context);
          },
          child: const Text("Update"),
        ),
      ],
    ),
  );
}
 Widget _kpiCard(String title, String value, IconData icon, Color color) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 15),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    ),
  );
}

Widget _chartContainer(String title, Widget chart) {
  return Container(
    height: 350,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Expanded(child: chart),
      ],
    ),
  );
}
  Widget _buildWelcomeScreen() {
    return const Center(child: Text("Welcome to GIC EFOMIS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)));
  }

  Widget _buildPlaceholder(String title) {
    return Center(child: Text(title));
  }
Widget _buildSupportReportsView() {
  return Container(
    margin: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Field Support Reports", 
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('expert_plans')
                .where('status', isEqualTo: 'Completed')
                .orderBy('reportDate', descending: true) 
                .snapshots(),
            builder: (context, snapshot) {
              // 1. Loading State
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // 2. Error State
              if (snapshot.hasError) {
                return Center(child: Text("Error loading reports: ${snapshot.error}"));
              }

              // 3. Empty State
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 10),
                      Text("No completed reports available yet.", 
                        style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                );
              }

              // 4. Data List
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 15),
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  
                  // --- FIX: SAFE DATE FORMATTING LOGIC ---
                  String displayDate = "No Date";
                  var rawDate = data['reportDate'];
                  
                  if (rawDate is Timestamp) {
                    DateTime dt = rawDate.toDate();
                    displayDate = "${dt.day}/${dt.month}/${dt.year}";
                  } else if (rawDate is String) {
                    displayDate = rawDate;
                  }
                  // ---------------------------------------

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(15),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.description, color: Colors.blue),
                      ),
                      title: Text(
                        data['targetEnterprise'] ?? "Unknown Enterprise",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text(data['finalReport'] ?? 'No details provided.',
                            style: TextStyle(color: Colors.grey[800], height: 1.4)),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 14, color: Colors.blueGrey),
                              const SizedBox(width: 5),
                              Text("Submitted by: ${data['submittedBy'] ?? 'Unknown'}",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              const Spacer(),
                              const Icon(Icons.calendar_today, size: 14, color: Colors.blueGrey),
                              const SizedBox(width: 5),
                              // --- DISPLAYING THE FIXED DATE STRING ---
                              Text(displayDate, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

Widget _buildOverview() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('enterprises').snapshots(),
    builder: (context, entSnapshot) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('expert_plans').snapshots(),
        builder: (context, planSnapshot) {
          
          if (entSnapshot.connectionState == ConnectionState.waiting || 
              planSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entDocs = entSnapshot.data?.docs ?? [];
          final planDocs = planSnapshot.data?.docs ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("System Overview", 
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),

                // SECTION 1: THE TOP CARDS
                _buildSummaryRow(entDocs, planDocs),

                const SizedBox(height: 30),

                // SECTION 2: THE GRAPHS
                _buildDetailedAnalytics(entDocs, planDocs),
              ],
            ),
          );
        },
      );
    },
  );
}  

Widget _buildSummaryRow(List<QueryDocumentSnapshot> entDocs, List<QueryDocumentSnapshot> planDocs) {
  int totalEnts = entDocs.length;
  int completed = planDocs.where((d) => d['status'] == 'Completed').length;
  int activeStaff = planDocs
      .where((d) => d['status'] == 'In Progress')
      .map((d) => d['expertName'] ?? 'Unknown')
      .toSet()
      .length;

  return Row(
    children: [
      _kpiCard("Total Enterprises", totalEnts.toString(), Icons.business, Colors.blue),
      const SizedBox(width: 20),
      _kpiCard("Tech Transfers", completed.toString(), Icons.bolt, Colors.orange),
      const SizedBox(width: 20),
      _kpiCard("Active Staff", activeStaff.toString(), Icons.person_pin_circle, Colors.green),
    ],
  );
}
Widget _buildDetailedAnalytics(List<QueryDocumentSnapshot> entDocs, List<QueryDocumentSnapshot> planDocs) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Column(
        children: [
          Row(
            children: [
              // Chart 1: Woreda Distribution
              Expanded(child: _chartContainer("Enterprises by Woreda", _buildWoredaBarChart(entDocs))),
              const SizedBox(width: 20),
              // Chart 2: Sector Breakdown
              Expanded(child: _chartContainer("Industry Sectors", _buildSectorPieChart(entDocs))),
            ],
          ),
        ],
      );
    }
  );
}
Widget _buildSectorPieChart(List<QueryDocumentSnapshot> docs) {
  // 1. Group data by Sector
  Map<String, int> sectors = {};
  for (var doc in docs) {
    String sector = doc['sector'] ?? 'Other';
    sectors[sector] = (sectors[sector] ?? 0) + 1;
  }

  // 2. Convert to list
  List<ChartData> data = sectors.entries
      .map((e) => ChartData(e.key, e.value.toDouble()))
      .toList();

  // 3. The Chart
  return SfCircularChart( // <--- TRY CHANGING SfPieChart TO SfCircularChart
    legend: const Legend(isVisible: true),
    series: <CircularSeries>[ 
      PieSeries<ChartData, String>(
        dataSource: data,
        xValueMapper: (ChartData d, _) => d.category,
        yValueMapper: (ChartData d, _) => d.value,
        dataLabelSettings: const DataLabelSettings(isVisible: true),
      )
    ],
  );
}
//staf managment 
Widget _buildStaffManagement() {
  return SingleChildScrollView( // Fixes the overflow
    padding: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Staff & Field Operations", 
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _showAddStaffDialog(context),
              icon: const Icon(Icons.person_add),
              label: const Text("Register New Expert"),
            ),
          ],
        ),
        const SizedBox(height: 25),
        
        const Text("Current Field Activities", style: TextStyle(fontSize: 18, color: Colors.blueGrey)),
        const SizedBox(height: 10),
        _buildLiveActivityList(),
        
        const SizedBox(height: 40),
        
        const Text("Staff Directory", style: TextStyle(fontSize: 18, color: Colors.blueGrey)),
        const SizedBox(height: 10),
        
        // Use a Container with a fixed height or Wrap to prevent overflow
        _buildStaffDirectory(), 
      ],
    ),
  );
}

Widget _buildStaffDirectory() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Expert').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: snapshot.data!.docs.length,
        itemBuilder: (context, index) {
          var userDoc = snapshot.data!.docs[index];
          var user = userDoc.data() as Map<String, dynamic>;
          
          String displayName = user['name'] ?? "Unknown Expert";
          String email = user['email'] ?? "No email provided";
          String dept = user['department'] ?? "General";

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.blue.shade100,
                child: Text(displayName[0].toUpperCase(), 
                  style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
              ),
              title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(email, style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  // Department Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text(dept, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              trailing: Row(
  mainAxisSize: MainAxisSize.min, // Keeps icons from taking full width
  children: [
    // 1. Your Workload Badge (making it dynamic is a great next step!)
    _workloadBadge(3), 
    
    const SizedBox(width: 8), // Small gap
    const VerticalDivider(width: 20, indent: 10, endIndent: 10), // Optional visual separator
    
    // 2. Edit Button
    IconButton(
      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
      onPressed: () => _editStaff(userDoc), 
      tooltip: 'Edit Expert',
    ),
    
    // 3. Delete Button
    IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
      onPressed: () => _deleteStaff(userDoc.id, displayName), 
      tooltip: 'Remove Expert',
    ),
  ],
),
              onTap: () {
                // Future: Show expert's full history and GPS location
              },
            ),
          );
        },
      );
    },
  );
}

// Helper for the "Active Task" badge
Widget _workloadBadge(int count) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
      const Text("Tasks", style: TextStyle(fontSize: 10, color: Colors.grey)),
    ],
  );
}
 Widget _buildRegionalDataView() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: () => setState(() => _activeSettingSubPage = "main"),
        icon: const Icon(Icons.arrow_back_ios, size: 16),
        label: const Text("Back to Settings"),
      ),
      const SizedBox(height: 20),
      const Text("Manage Regional Woredas", 
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      const Text("Add or remove Woredas for Gofa Industrial College operations.", 
        style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 25),
      
      // Interface to add a new Woreda
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _woredaController, // Connect the controller
              decoration: const InputDecoration(
                hintText: "Enter new Woreda name (e.g., Gofa Zuria)",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (_woredaController.text.isNotEmpty) {
                // SAVE TO FIRESTORE
                await FirebaseFirestore.instance
                    .collection('settings')
                    .doc('regions')
                    .collection('woredas')
                    .add({
                  'name': _woredaController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                _woredaController.clear(); // Clear input after adding
              }
            },
            icon: const Icon(Icons.add),
            label: const Text("Add Woreda"),
          ),
        ],
      ),
      const SizedBox(height: 30),
      
      // List of existing Woredas from Firestore
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('settings')
              .doc('regions')
              .collection('woredas')
              .orderBy('name') // Keep them alphabetical
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No Woredas added yet."));
            }

            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Color(0xFF0D47A1)),
                    title: Text(doc['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => doc.reference.delete(),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

Widget _buildLiveActivityList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('expert_plans')
        .where('status', isEqualTo: 'In Progress')
        .limit(5).snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const LinearProgressIndicator();
      
      return SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            return Container(
              width: 250,
              margin: const EdgeInsets.only(right: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc['expertName'] ?? 'Expert', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("At: ${doc['enterpriseName'] ?? 'Enterprise'}", style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  const Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.red),
                      Text(" Active in Gofa", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  )
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
void _showAddStaffDialog(BuildContext context) {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final roleController = TextEditingController(text: 'Expert');

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Register Field Expert"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name")),
          TextField(controller: emailController, decoration: const InputDecoration(labelText: "College Email")),
          DropdownButtonFormField(
            value: 'Expert',
            items: ['Expert', 'Department Head'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) {},
            decoration: const InputDecoration(labelText: "Role"),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            // Logic to save to 'users' collection
            await FirebaseFirestore.instance.collection('users').add({
              'name': nameController.text,
              'email': emailController.text,
              'role': 'Expert',
              'createdAt': Timestamp.now(),
            });
            Navigator.pop(context);
          }, 
          child: const Text("Save Expert")
        ),
      ],
    ),
  );
}
Widget _staffRow(String name, int active, int done) {
  double progress = (active + done) == 0 ? 0 : done / (active + done);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
    child: Row(
      children: [
        Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Chip(label: Text("$active Active"), backgroundColor: Colors.orange.shade50)),
        Expanded(child: Text("$done Tasks")),
        Expanded(
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            color: Colors.green,
          ),
        ),
        ElevatedButton(
          onPressed: () { /* TODO: Navigate to detail view */ },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
          child: const Text("Details"),
        ),
      ],
    ),
  );
}
Widget _buildSettingsView() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("System Configuration", 
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const Text("Manage college-wide parameters and data standards", 
          style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 30),

        // Settings Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, // Two cards per row
          childAspectRatio: 2.5,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _settingsTile(
              title: "Regional Data",
              subtitle: "Edit Woredas & Kebeles",
              icon: Icons.map_rounded,
              color: Colors.blue,
              onTap: () => setState(() => _activeSettingSubPage = "regional"),
            ),
            _settingsTile(
              title: "Sector Categories",
              subtitle: "Automotive, Textile, etc.",
              icon: Icons.category_rounded,
              color: Colors.orange,
              onTap: () => _showComingSoon("Sector Management"),
            ),
            _settingsTile(
              title: "Backup & Export",
              subtitle: "Download CSV/Excel Reports",
              icon: Icons.cloud_download_rounded,
              color: Colors.green,
              onTap: () => _showComingSoon("Data Export"),
            ),
            _settingsTile(
              title: "Admin Profile",
              subtitle: "Update Dean Credentials",
              icon: Icons.admin_panel_settings_rounded,
              color: Colors.purple,
              onTap: () => _showComingSoon("Profile Settings"),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _settingsTile({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Helper for unfinished features
void _showComingSoon(String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("$feature module is being finalized for GIC.")),
  );
}

Widget _settingsCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 15),
    child: ListTile(
      leading: Icon(icon, color: Colors.blue.shade800),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
Widget _buildWoredaBarChart(List<QueryDocumentSnapshot> docs) {
  // 1. Group data by Woreda
  Map<String, int> counts = {};
  for (var doc in docs) {
    // Make sure 'woreda' matches the field name in your Firestore
    String woreda = doc['woreda'] ?? 'Unknown'; 
    counts[woreda] = (counts[woreda] ?? 0) + 1;
  }

  // 2. Convert to list for Syncfusion
  List<ChartData> data = counts.entries
      .map((e) => ChartData(e.key, e.value.toDouble()))
      .toList();

  return SfCartesianChart(
    primaryXAxis: CategoryAxis(),
    tooltipBehavior: TooltipBehavior(enable: true),
    series: <CartesianSeries>[
      ColumnSeries<ChartData, String>(
        dataSource: data,
        xValueMapper: (ChartData d, _) => d.category,
        yValueMapper: (ChartData d, _) => d.value,
        color: Colors.blueAccent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        dataLabelSettings: const DataLabelSettings(isVisible: true),
      )
    ],
  );
}
Widget _buildStatusBadge(String status, DocumentSnapshot doc) {
    Color color;
    switch (status) {
      case 'Resolved': color = Colors.green; break;
      case 'In Progress': color = Colors.orange; break;
      default: color = Colors.blueGrey;
    }

    return PopupMenuButton<String>(
      onSelected: (value) => doc.reference.update({'status': value}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'In Progress', child: Text("Mark In Progress")),
        const PopupMenuItem(value: 'Resolved', child: Text("Mark Resolved")),
        const PopupMenuItem(value: 'Dismissed', child: Text("Dismiss")),
      ],
    );
  }

Widget _buildGISMapView() {
  return Container(
    margin: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.blueGrey.shade100),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('enterprises').snapshots(),
        builder: (context, snapshot) {
          // 1. Initial Loading State: Prevents the "No Data" flash
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Loading GIS Data...", style: TextStyle(color: Colors.blueGrey)),
                ],
              ),
            );
          }

          // 2. Error Handling: Always good for network-dependent maps
          if (snapshot.hasError) {
            return Center(child: Text("Error loading map: ${snapshot.error}"));
          }

          // 3. Verification of Data: Only show "No Data" message if fully loaded and empty
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No Enterprise locations found in the database."),
            );
          }

          // 4. Marker Generation
          Set<Marker> markers = {};
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            if (data['lat'] != null && data['lng'] != null) {
              // Extract coordinates safely
              double lat = (data['lat'] as num).toDouble();
              double lng = (data['lng'] as num).toDouble();
              bool isModel = data['isModel'] ?? false;

              markers.add(
                Marker(
                  markerId: MarkerId(doc.id),
                  position: LatLng(lat, lng),
                  onTap: () => _showEnterpriseDetails(data), // Reuse your existing detail dialog
                  infoWindow: InfoWindow(
                    title: data['entName'] ?? "Enterprise",
                    snippet: "Sector: ${data['sector']}",
                  ),
                  // Visual Cue: Use gold for Model Enterprises, Azure for standard
                  icon: BitmapDescriptor.defaultMarkerWithHue(
            isModel ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueAzure,
                      
                  ),
                ),
              );
            }
          }

          return GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(6.3275, 37.6611), // Gofa Region
              zoom: 12,
            ),
            markers: markers,
            mapType: MapType.normal,
            myLocationEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true, // Allows users to open coordinates in Google Maps
          );
        },
      ),
    ),
  );
}

} // End of Class

class ChartData {
  ChartData(this.category, this.value);
  final String category;
  final double value;
}
