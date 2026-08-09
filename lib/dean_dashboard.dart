import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as ex; 
import 'package:file_saver/file_saver.dart';
import 'widgets/dean_sidebar.dart';
import 'widgets/app_ui.dart';
import 'widgets/notification_bell.dart';
import 'notification_service.dart';
import 'validators.dart';
import 'firestore_safe.dart';
import 'change_password.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart'; // Optional for sparklines
import 'package:syncfusion_flutter_charts/charts.dart' hide PieSeries; // This is a trick to reset the link
import 'dart:math';

/// Departments managed at GIC — used by the Dean's user-creation and
/// broadcast-targeting forms.
const List<String> _collegeDepartments = [
  'Construction', 'ICT', 'Electrical', 'Mechanical',
  'Textile', 'Automotive', 'Manufacturing', 'Civil Engineering', 'Other',
];

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
  String _planStatusFilter = 'Pending Dean Review'; // Filter for the Dean's Plan Review tab
  String _scheduleDeptFilter = 'All'; // Filters for the read-only Schedule Overview
  String _scheduleExpertFilter = 'All';
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
      final data = doc.data() as Map<String, dynamic>? ?? const <String, dynamic>{};
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
                const Divider(),
                _detailRow("Initial Capital", formatInitialCapital(data['initialCapital']), isBold: true),
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
  final initialCapitalController = TextEditingController();
  final woredaController = TextEditingController();
  final TextEditingController _woredaController = TextEditingController();
  String entDepartment = 'ICT';

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
                _buildField(phoneController, "Phone", Icons.phone, isPhone: true),
                Row(children: [
                  Expanded(child: _buildField(sectorController, "Sector", Icons.category)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(subSectorController, "Sub Sector", Icons.account_tree)),
                ]),
                Row(children: [
                  Expanded(child: _buildField(initialCapitalController, "Initial Capital (ETB)", Icons.payments_outlined, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(woredaController, "Woreda", Icons.map)),
                ]),
                Row(children: [
                  Expanded(child: _buildField(maleCountController, "Male", Icons.male, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(femaleCountController, "Female", Icons.female, isNumber: true)),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: entDepartment,
                  decoration: const InputDecoration(
                    labelText: "Owning Department",
                    prefixIcon: Icon(Icons.account_tree_outlined, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Textile', child: Text("Textile")),
                    DropdownMenuItem(value: 'Construction', child: Text("Construction")),
                    DropdownMenuItem(value: 'Automotive', child: Text("Automotive")),
                    DropdownMenuItem(value: 'Manufacturing', child: Text("Manufacturing")),
                    DropdownMenuItem(value: 'ICT', child: Text("ICT")),
                  ],
                  onChanged: (v) => setSheetState(() => entDepartment = v ?? 'ICT'),
                ),
                
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
                  child: GradientButton(
                    label: "Save to Database",
                    icon: Icons.save_rounded,
                    height: 50,
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
                          'initialCapital': double.tryParse(initialCapitalController.text.trim()) ?? 0.0,
                          'maleCount': m,
                          'femaleCount': f,
                          'totalCount': m + f,
                          'lat': selectedLat, // Saving the picked Latitude
                          'lng': selectedLng, // Saving the picked Longitude
                          'isModel': false,
                          'department': entDepartment, // For department-scoped visibility
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
              target: LatLng(8.9599, 38.7115), // Center on Jemo, Addis Ababa
              zoom: 14.5,
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
  Widget _buildField(TextEditingController controller, String label, IconData icon,
      {bool isNumber = false, bool isPhone = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber
          ? TextInputType.number
          : (isPhone ? TextInputType.phone : TextInputType.text),
      decoration: appInputDecoration(label: label, icon: icon),
      validator: isPhone ? phoneField : (value) => requiredField(value),
    );
  }

  // --- 4. MAIN BUILDER ---
  @override
  Widget build(BuildContext context) {
    final bool isWide =
        MediaQuery.of(context).size.width >= AppPalette.desktopBreakpoint;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // On narrow screens the fixed 280px sidebar would crush the content, so
      // it collapses into a hamburger drawer instead of a side rail.
      drawer: isWide
          ? null
          : Drawer(
              width: 280,
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: DeanSidebar(
                currentIndex: _currentIndex,
                onTabSelected: (index) {
                  Navigator.of(context).pop();
                  if (index == 9) {
                    _handleLogout();
                  } else {
                    setState(() => _currentIndex = index);
                  }
                },
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            DeanSidebar(
              currentIndex: _currentIndex,
              onTabSelected: (index) {
                if (index == 9) {
                  _handleLogout();
                } else {
                  setState(() => _currentIndex = index);
                }
              },
            ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(isWide: isWide),
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
                      _buildPlanReviewView(),   // 6: Plan Approvals (Dean Review)
                      _buildScheduleOverviewView(), // 7: Schedules (read-only)
                      _buildSettingsView(),          // 8: Settings
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

  Widget _buildHeader({required bool isWide}) {
    return Container(
      height: 74,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 30 : 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppPalette.border)),
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppPalette.primary),
                tooltip: "Menu",
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          if (isWide) ...[
            const Icon(Icons.account_balance_rounded, color: AppPalette.primary, size: 26),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Text(
              "Dean Portal · GIC",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppPalette.textPrimary),
            ),
          ),
          if (isWide)
            GradientButton(
              label: "Broadcast",
              icon: Icons.campaign_rounded,
              width: 130,
              height: 40,
              fontSize: 13,
              onPressed: _showBroadcastDialog,
            )
          else
            IconButton(
              icon: const Icon(Icons.campaign_rounded, color: AppPalette.primary),
              tooltip: "Broadcast",
              onPressed: _showBroadcastDialog,
            ),
          const SizedBox(width: 14),
          const NotificationBell(scope: NotificationScope(role: 'dean')),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.file_download, color: AppPalette.primary),
            onPressed: _exportToExcel,
            tooltip: "Export to Excel",
          ),
          if (isWide) ...[
            const SizedBox(width: 10),
            Container(width: 1, height: 30, color: AppPalette.border),
          ],
          const SizedBox(width: 14),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppPalette.primary,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
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
        Wrap(
          spacing: 12,
          runSpacing: 14,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
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

            GradientButton(
              label: "New Enterprise",
              icon: Icons.add,
              width: 180,
              height: 46,
              fontSize: 13,
              onPressed: _showAddEnterpriseForm,
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
                        Expanded(
                          child: Text(
                          _searchQuery.isEmpty 
                            ? "Total Records: ${snapshot.data!.docs.length}"
                            : "Found ${filteredDocs.length} of ${snapshot.data!.docs.length} enterprises",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          ),
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
                          const SizedBox(height: 4),
                          Text("Initial Capital: ${formatInitialCapital(data['initialCapital'])}",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
              .where((doc) => docStr(doc, 'status') == 'Completed')
              .length ?? 0;

          // Staff on Field (Unique experts with 'In Progress' tasks)
          // The '?? 0' at the end is what solves your compilation error!
          int activeStaff = planSnapshot.data?.docs
              .where((doc) => docStr(doc, 'status') == 'In Progress')
              .map((doc) => (doc.data() as Map<String, dynamic>?)?['expertName'] ?? 'Unknown')
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text("Delete Expert?", textAlign: TextAlign.center),
      content: Text("Are you sure you want to remove $name from the system? This cannot be undone."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: AppPalette.textMuted))),
        GradientButton(
          label: "Delete",
          icon: Icons.delete_forever_rounded,
          width: 130,
          height: 44,
          fontSize: 13,
          colors: const [Color(0xFFF87171), Color(0xFFDC2626)],
          onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(docId).delete();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("$name removed successfully")),
            );
          },
        ),
      ],
    ),
  );
}
void _editStaff(DocumentSnapshot doc) {
  // Use safe helpers so missing fields on legacy docs never throw
  // 'Bad state: field does not exist'.
  final nameController = TextEditingController(text: docStr(doc, 'name'));
  final deptController = TextEditingController(text: docStr(doc, 'department'));

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Edit Expert Profile", textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameController, decoration: appInputDecoration(label: "Full Name", icon: Icons.person_outline)),
          const SizedBox(height: 12),
          TextField(controller: deptController, decoration: appInputDecoration(label: "Department", icon: Icons.account_tree_outlined)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: AppPalette.textMuted))),
        GradientButton(
          label: "Update",
          icon: Icons.save_rounded,
          width: 150,
          height: 44,
          fontSize: 13,
          onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
              'name': nameController.text,
              'department': deptController.text,
            });
            Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}
 Widget _kpiCard(String title, String value, IconData icon, Color color) {
  return Expanded(
    child: MetricCard(
      title: title,
      value: value,
      subtitle: '',
      icon: icon,
      color: color,
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
Widget _buildSupportReportsView() {
  return Container(
    margin: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          icon: Icons.summarize_outlined,
          title: "Field Support Reports",
          subtitle: "Completed visit reports submitted by field experts.",
        ),
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

                  return HoverCard(
                    padding: EdgeInsets.zero,
                    radius: 12,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(15),
                      leading: IconBubble(icon: Icons.description, color: AppPalette.primary, size: 42),
                      title: Text(
                        data['targetEnterprise'] ?? "Unknown Enterprise",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          if ((data['reportTemplate'] ?? '').toString().isNotEmpty)
                            Text("Format: ${data['reportTemplate']}",
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                          if (!_deanTemplateSectionsEmpty(data))
                            ..._deanTemplateSections(data)
                          else
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

// ==================== EXPERT VISIT PLAN REVIEW (DEAN APPROVAL WORKFLOW) ====================
Widget _buildPlanReviewView() {
  return Container(
    margin: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.fact_check_outlined, color: Color(0xFF0D47A1), size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Expert Visit Plan Review",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                Text("Review and approve enterprise visit plans submitted by experts",
                    style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Status-filtered list (filters client-side to avoid composite index requirements)
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('expert_plans')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error loading plans: ${snapshot.error}"));
              }

              final allDocs = snapshot.data?.docs ?? [];

              // Count plans per status for the filter chips
              int countFor(String status) {
                if (status == 'All') return allDocs.length;
                if (status == 'Pending Dean Review') {
                  return allDocs
                      .where((d) =>
                          docStr(d, 'status') == 'Pending Dean Review' ||
                          docStr(d, 'status') == 'Pending' ||
                          docStr(d, 'status') == 'Approved by Dept Head')
                      .length;
                }
                return allDocs.where((d) => docStr(d, 'status') == status).length;
              }

              // Apply the selected filter
              final filtered = allDocs.where((doc) {
                final s = (doc.data() as Map<String, dynamic>?)?['status'] ?? '';
                if (_planStatusFilter == 'All') return true;
                if (_planStatusFilter == 'Pending Dean Review') {
                  return s == 'Pending Dean Review' ||
                      s == 'Pending' ||
                      s == 'Approved by Dept Head';
                }
                return s == _planStatusFilter;
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _planFilterChip('All', countFor('All')),
                      _planFilterChip('Pending Dean Review', countFor('Pending Dean Review')),
                      _planFilterChip('Approved by Dept Head', countFor('Approved by Dept Head')),
                      _planFilterChip('Approved', countFor('Approved')),
                      _planFilterChip('Needs Revision', countFor('Needs Revision')),
                      _planFilterChip('Revision Requested', countFor('Revision Requested')),
                      _planFilterChip('Rejected', countFor('Rejected')),
                      _planFilterChip('Completed', countFor('Completed')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text("No plans with status '$_planStatusFilter'.",
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final data = doc.data() as Map<String, dynamic>;
                              return _buildPlanReviewCard(doc, data);
                            },
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

// Filter chip for the plan review tabs
Widget _planFilterChip(String label, int count) {
  final bool selected = _planStatusFilter == label;
  return ChoiceChip(
    label: Text("$label ($count)"),
    selected: selected,
    onSelected: (_) => setState(() => _planStatusFilter = label),
    selectedColor: AppPalette.primary,
    labelStyle: TextStyle(
      color: selected ? Colors.white : Colors.blueGrey,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
    backgroundColor: Colors.white,
    side: BorderSide(color: selected ? AppPalette.primary : Colors.grey.shade300),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    showCheckmark: false,
  );
}

// One plan card in the dean review list
Widget _buildPlanReviewCard(DocumentSnapshot doc, Map<String, dynamic> data) {
  final String status = data['status'] ?? 'Pending Dean Review';
  final Color statusColor = _planStatusColor(status);
  final bool reviewable = status == 'Pending Dean Review' ||
      status == 'Pending' ||
      status == 'Approved by Dept Head' ||
      status == 'Revision Requested';
  final deptComments = data['deptHeadComments'];
  final planTasks = _parsePlanTasks(data['tasks'] ?? data['description']);

  // Safe submitted-date formatting
  String displayDate = "—";
  final rawDate = data['timestamp'];
  if (rawDate is Timestamp) {
    final dt = rawDate.toDate();
    displayDate = "${dt.day}/${dt.month}/${dt.year}";
  } else if (rawDate is String) {
    displayDate = rawDate;
  }

  return HoverCard(
    padding: const EdgeInsets.all(20),
    radius: 14,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: enterprise + expert + status badge
        Row(
          children: [              IconBubble(icon: Icons.business, color: AppPalette.primary, size: 44),
              const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['targetEnterprise'] ?? 'Unknown Enterprise',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    "${data['expertName'] ?? data['submittedBy'] ?? 'Expert'}${data['department'] != null ? ' · ${data['department']}' : ''}",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            _planStatusBadge(status, statusColor),
          ],
        ),
        const Divider(height: 24),

        // Key details
        _planInfoRow(Icons.location_on_outlined, "Target Location", data['location'] ?? 'N/A'),
        _planInfoRow(Icons.calendar_month_outlined, "Visit Dates",
            "${data['startDate'] ?? 'N/A'}  →  ${data['endDate'] ?? 'N/A'}"),
        const SizedBox(height: 12),

        // Planned tasks / objectives list
        const Text("Planned Tasks / Objectives",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        if (planTasks.isEmpty)
          const Text("No tasks listed.",
              style: TextStyle(fontSize: 13, color: Colors.blueGrey))
        else
          ...planTasks.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Expected outcomes
        if ((data['expectedOutcomes'] ?? '').toString().isNotEmpty) ...[
          const Text("Expected Outcomes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text(data['expectedOutcomes'].toString(),
              style: TextStyle(color: Colors.green.shade800, fontSize: 13)),
          const SizedBox(height: 12),
        ],

        // Show prior dean feedback if the plan was sent back
        if ((data['revisionFeedback'] ?? '').toString().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.feedback_outlined, size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("Previous feedback: ${data['revisionFeedback']}",
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Show the Department Head's decision/comment (approve / revision / reject)
        if ((data['deptHeadFeedback'] ?? '').toString().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: status == 'Rejected'
                  ? Colors.red.shade50
                  : status == 'Needs Revision'
                      ? Colors.orange.shade50
                      : Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: status == 'Rejected'
                    ? Colors.red.shade200
                    : status == 'Needs Revision'
                        ? Colors.orange.shade200
                        : Colors.teal.shade200,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  status == 'Rejected'
                      ? Icons.block
                      : status == 'Needs Revision'
                          ? Icons.edit_note
                          : Icons.verified_user_outlined,
                  size: 18,
                  color: status == 'Rejected'
                      ? Colors.red.shade800
                      : status == 'Needs Revision'
                          ? Colors.orange.shade800
                          : Colors.teal.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status == 'Approved by Dept Head'
                        ? "Department Head approved: ${data['deptHeadFeedback']}"
                        : "Department Head: ${data['deptHeadFeedback']}",
                    style: TextStyle(
                        color: status == 'Rejected'
                            ? Colors.red.shade900
                            : status == 'Needs Revision'
                                ? Colors.orange.shade900
                                : Colors.teal.shade900,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Department Head feedback/comments on the plan
        if (deptComments is List && deptComments.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text("Department Head Feedback",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          ...deptComments.map<Widget>((raw) {
            final c = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.comment_outlined, size: 16, color: Color(0xFF3730A3)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${c['byName'] ?? c['by'] ?? 'Department Head'}: ${c['text'] ?? ''}",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // On-site task progress for in-progress visits
        if (status == 'In Progress') ...[
          const SizedBox(height: 12),
          ..._deanTaskProgress(data),
        ],

        // Completed report summary
        if (status == 'Completed') ...[
          const SizedBox(height: 12),
          if ((data['reportTemplate'] ?? '').toString().isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 16, color: Color(0xFF0D47A1)),
                const SizedBox(width: 6),
                Text(
                  "Format: ${data['reportTemplate']}",
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const Text("Final Report Summary",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          if (!_deanTemplateSectionsEmpty(data))
            ..._deanTemplateSections(data)
          else if ((data['finalReport'] ?? '').toString().isNotEmpty)
            Text(data['finalReport'].toString(),
                style: const TextStyle(fontSize: 13, height: 1.4))
          else ...[
            if ((data['tasksPerformed'] ?? '').toString().isNotEmpty)
              Text("Tasks performed: ${data['tasksPerformed']}",
                  style: const TextStyle(fontSize: 13)),
            if ((data['challenges'] ?? '').toString().isNotEmpty)
              Text("Challenges: ${data['challenges']}", style: const TextStyle(fontSize: 13)),
            if ((data['solutionsProvided'] ?? '').toString().isNotEmpty)
              Text("Solutions: ${data['solutionsProvided']}", style: const TextStyle(fontSize: 13)),
          ],
        ],

        // Footer: submitted date
        Row(
          children: [
            const Icon(Icons.schedule, size: 14, color: Colors.blueGrey),
            const SizedBox(width: 5),
            Text("Submitted: $displayDate",
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          ],
        ),
        const SizedBox(height: 16),

        // Action buttons (only for plans that still need a decision)
        if (reviewable)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _requestPlanRevision(doc, data),
                  icon: const Icon(Icons.edit_note),
                  label: const Text("Request Revision"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  label: "Approve Plan",
                  icon: Icons.thumb_up_alt_outlined,
                  height: 48,
                  fontSize: 13,
                  colors: AppPalette.successGradient,
                  onPressed: () => _approvePlan(doc),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

// Approve a plan — updates the status in Firestore so the expert sees it immediately
Future<void> _approvePlan(DocumentSnapshot doc) async {
  try {
    await doc.reference.update({
      'status': 'Approved',
      'reviewedBy': FirebaseAuth.instance.currentUser?.email ?? 'Dean',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    final planData = doc.data() as Map<String, dynamic>?;
    final expert = (planData?['submittedBy'] ?? '').toString();
    if (expert.isNotEmpty) {
      await pushNotification(
        title: 'Visit Plan Approved',
        message:
            'Your visit plan for ${planData?['targetEnterprise'] ?? 'the enterprise'} has been approved. You can start the visit.',
        userId: expert,
        type: 'plan_approved',
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Plan approved! The expert can now begin the visit.")),
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Approval failed: $e")),
      );
    }
  }
}

// Request revision — optional feedback is saved with the plan
void _requestPlanRevision(DocumentSnapshot doc, Map<String, dynamic> data) {
  final feedbackController = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Request Revision", textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Send this plan back to ${data['expertName'] ?? 'the expert'} for changes.",
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 15),
          TextField(
            controller: feedbackController,
            maxLines: 3,
            decoration: appInputDecoration(
              label: "Feedback (optional)",
              hint: "e.g., Please add more detail on the expected outcomes",
              icon: Icons.feedback_outlined,
              alignLabel: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        GradientButton(
          label: "Send Revision Request",
          icon: Icons.edit_note,
          width: 210,
          height: 46,
          fontSize: 13,
          colors: const [Color(0xFFF97316), Color(0xFFEA580C)],
          onPressed: () async {
            final feedback = feedbackController.text.trim();
            await doc.reference.update({
              'status': 'Revision Requested',
              'revisionFeedback': feedback.isEmpty ? FieldValue.delete() : feedback,
              'reviewedBy': FirebaseAuth.instance.currentUser?.email ?? 'Dean',
              'reviewedAt': FieldValue.serverTimestamp(),
            });
            final expert = (data['submittedBy'] ?? '').toString();
            if (expert.isNotEmpty) {
              await pushNotification(
                title: 'Revision Requested',
                message:
                    'Your visit plan for ${data['targetEnterprise'] ?? 'the enterprise'} needs revision. Please update and resubmit.',
                userId: expert,
                type: 'revision',
              );
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Revision requested. The expert can see it in their dashboard.")),
            );
          },
        ),
      ],
    ),
  );
}

// Small labeled detail row used inside plan review cards
Widget _planInfoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text("$label:  ", style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    ),
  );
}

// Status badge pill
Widget _planStatusBadge(String status, Color color) {
  return StatusChip(status, color: color);
}

// Status → color mapping for the review workflow
Color _planStatusColor(String status) {
  switch (status) {
    case 'Approved':
      return Colors.green;
    case 'Approved by Dept Head':
      return Colors.teal;
    case 'Needs Revision':
      return Colors.orange;
    case 'Revision Requested':
      return Colors.redAccent;
    case 'Rejected':
      return Colors.redAccent;
    case 'Completed':
      return Colors.blue;
    case 'In Progress':
      return Colors.orange;
    default:
      return Colors.orange; // Pending Dean Review / legacy Pending
  }
}

// Split the tasks field into a readable list (newline first, then commas)
List<String> _parsePlanTasks(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  final lines = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (lines.length > 1) return lines;
  return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

// On-site task checklist progress shown to the Dean for in-progress visits
List<Widget> _deanTaskProgress(Map<String, dynamic> data) {
  final tasks = _parsePlanTasks(data['tasks'] ?? data['description'] ?? '');
  final checklistRaw = data['taskChecklist'];
  final checklist =
      checklistRaw is Map ? Map<String, dynamic>.from(checklistRaw) : <String, dynamic>{};
  int done = checklist.values.where((v) => v == true).length;
  return [
    const Text("On-Site Task Checklist",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    const SizedBox(height: 6),
    if (tasks.isEmpty)
      const Text("No tasks on this plan yet.",
          style: TextStyle(fontSize: 12, color: Colors.blueGrey))
    else ...[
      Row(
        children: [
          Text("$done of ${tasks.length} tasks completed",
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        ],
      ),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: done / tasks.length,
        backgroundColor: Colors.grey.shade200,
        color: Colors.green,
      ),
      const SizedBox(height: 8),
      for (int i = 0; i < tasks.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                checklist['$i'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: checklist['$i'] == true ? Colors.green : Colors.blueGrey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tasks[i],
                  style: TextStyle(
                    fontSize: 13,
                    decoration: checklist['$i'] == true ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  ];
}

// Render structured template sections with formatted headers (new reports)
List<Widget> _deanTemplateSections(Map<String, dynamic> data) {
  final raw = data['templateSections'];
  if (raw is! Map || raw.isEmpty) return const [];
  final entries = raw.entries
      .where((e) => (e.value ?? '').toString().trim().isNotEmpty)
      .toList();
  if (entries.isEmpty) return const [];
  return [
    for (final e in entries)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.key,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            const SizedBox(height: 4),
            Text((e.value ?? '').toString().trim(),
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ],
        ),
      ),
  ];
}

// True when the report has no structured template sections (legacy report)
bool _deanTemplateSectionsEmpty(Map<String, dynamic> data) {
  final raw = data['templateSections'];
  return raw is! Map || raw.isEmpty;
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

                const SizedBox(height: 30),

                // SECTION 3: PLAN STATUS + DEPARTMENT ANALYTICS
                _buildPlanStatusAnalytics(entDocs, planDocs),
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
  int completed = planDocs.where((d) => docStr(d, 'status') == 'Completed').length;
  int activeStaff = planDocs
      .where((d) => docStr(d, 'status') == 'In Progress')
      .map((d) => (d.data() as Map<String, dynamic>?)?['expertName'] ?? 'Unknown')
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

// Plan Status donut + Enterprise-by-department bar chart (live overview)
Widget _buildPlanStatusAnalytics(List<QueryDocumentSnapshot> entDocs, List<QueryDocumentSnapshot> planDocs) {
  // 1. Group plan statuses into the workflow buckets shown to stakeholders
  final buckets = <String, int>{
    'Approved': 0,
    'Pending Review': 0,
    'Revisions': 0,
    'In Progress': 0,
    'Completed': 0,
    'Rejected': 0,
  };
  for (final d in planDocs) {
    final s = docStr(d, 'status');
    if (s == 'Approved') {
      buckets['Approved'] = buckets['Approved']! + 1;
    } else if (s == 'Approved by Dept Head' ||
        s == 'Pending Dean Review' ||
        s == 'Pending') {
      buckets['Pending Review'] = buckets['Pending Review']! + 1;
    } else if (s == 'Needs Revision' || s == 'Revision Requested') {
      buckets['Revisions'] = buckets['Revisions']! + 1;
    } else if (s == 'In Progress') {
      buckets['In Progress'] = buckets['In Progress']! + 1;
    } else if (s == 'Completed') {
      buckets['Completed'] = buckets['Completed']! + 1;
    } else if (s == 'Rejected') {
      buckets['Rejected'] = buckets['Rejected']! + 1;
    }
  }
  final donutData = buckets.entries
      .where((e) => e.value > 0)
      .map((e) => ChartData(e.key, e.value.toDouble()))
      .toList();

  // 2. Group enterprises by owning department
  final deptCounts = <String, int>{};
  for (final d in entDocs) {
    final dept = normDept(docStr(d, 'department'));
    final key = dept.isEmpty ? 'Other' : dept;
    deptCounts[key] = (deptCounts[key] ?? 0) + 1;
  }
  final barData = deptCounts.entries
      .map((e) => ChartData(e.key, e.value.toDouble()))
      .toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("Plan Status & Department Analytics",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppPalette.textPrimary)),
      const SizedBox(height: 15),
      Row(
        children: [
          Expanded(
              child: _chartContainer("Plan Statuses", _buildPlanStatusDonut(donutData))),
          const SizedBox(width: 20),
          Expanded(
              child: _chartContainer("Enterprises by Department", _buildDepartmentBarChart(barData))),
        ],
      ),
    ],
  );
}

Widget _buildPlanStatusDonut(List<ChartData> data) {
  const colors = <String, Color>{
    'Approved': Color(0xFF16A34A),
    'Pending Review': Color(0xFFD97706),
    'Revisions': Color(0xFFEA580C),
    'In Progress': Color(0xFF2563EB),
    'Completed': Color(0xFF7C3AED),
    'Rejected': Color(0xFFDC2626),
  };
  return SfCircularChart(
    legend: const Legend(isVisible: true, position: LegendPosition.bottom),
    tooltipBehavior: TooltipBehavior(enable: true),
    series: <CircularSeries>[
      DoughnutSeries<ChartData, String>(
        dataSource: data,
        xValueMapper: (ChartData d, _) => d.category,
        yValueMapper: (ChartData d, _) => d.value,
        pointColorMapper: (ChartData d, _) =>
            colors[d.category] ?? const Color(0xFF64748B),
        dataLabelSettings: const DataLabelSettings(isVisible: true),
        radius: '80%',
        innerRadius: '58%',
      ),
    ],
  );
}

Widget _buildDepartmentBarChart(List<ChartData> data) {
  return SfCartesianChart(
    primaryXAxis: const CategoryAxis(),
    tooltipBehavior: TooltipBehavior(enable: true),
    series: <CartesianSeries>[
      ColumnSeries<ChartData, String>(
        dataSource: data,
        xValueMapper: (ChartData d, _) => d.category,
        yValueMapper: (ChartData d, _) => d.value,
        color: AppPalette.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        dataLabelSettings: const DataLabelSettings(isVisible: true),
      ),
    ],
  );
}

Widget _buildSectorPieChart(List<QueryDocumentSnapshot> docs) {
  // 1. Group data by Sector
  Map<String, int> sectors = {};
  for (var doc in docs) {
    String sector = (doc.data() as Map<String, dynamic>?)?['sector']?.toString() ?? 'Other';
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
        Wrap(
          spacing: 12,
          runSpacing: 14,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text("Staff & Field Operations", 
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            GradientButton(
              label: "Add New Staff / User",
              icon: Icons.person_add_alt_1_rounded,
              width: 210,
              height: 46,
              fontSize: 13,
              onPressed: () => _showAddStaffDialog(context),
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
    stream: FirebaseFirestore.instance
        .collection('users')
        // Legacy accounts store 'Expert'; new accounts use lowercase roles.
        .where('role', whereIn: [
          'expert', 'Expert', 'deptHead', 'Department Head', 'dean', 'Dean'
        ])
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

      // Bounds validation: guard against an empty user list so we never
      // index past the end (RangeError) or render a blank ListView.
      final users = snapshot.data!.docs;
      if (users.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 44),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.border),
          ),
          child: Column(
            children: [
              Icon(Icons.group_off_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                "No staff members found in this category",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: users.length,
        itemBuilder: (context, index) {
          var userDoc = users[index];
          // Null-safe map read: legacy user docs may lack fields entirely.
          final user = userDoc.data() as Map<String, dynamic>?;
          
          String displayName = (user?['name'] ?? "Unknown Expert").toString();
          String email = (user?['email'] ?? "No email provided").toString();
          String dept = (user?['department'] ?? "General").toString();
          final role = (user?['role'] ?? 'expert').toString();
          final isDeptHead = role == 'deptHead' || role == 'Department Head';
          final isDean = role == 'dean' || role == 'Dean';
          final roleLabel = isDean ? 'Dean' : (isDeptHead ? 'Dept Head' : 'Expert');
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: AppPalette.primary.withValues(alpha: 0.12),
              child: Text(
                // Null-safe initials: an empty name must not be indexed ([0]
                // would throw RangeError), so fall back to '?' instead.
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: TextStyle(color: AppPalette.primary, fontWeight: FontWeight.bold),
              ),
              ),
              title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(email, style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  // Role + Department Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusChip(
                        roleLabel,
                        color: isDean
                            ? const Color(0xFF7C3AED)
                            : (isDeptHead ? const Color(0xFF0D9488) : AppPalette.primary),
                      ),
                      StatusChip(dept, color: AppPalette.primary),
                    ],
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
                    title: Text((doc.data() as Map<String, dynamic>?)?['name']?.toString() ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
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
                  Text((doc.data() as Map<String, dynamic>?)?['expertName'] ?? 'Expert',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("At: ${(doc.data() as Map<String, dynamic>?)?['targetEnterprise'] ?? 'Enterprise'}",
                      style: const TextStyle(fontSize: 12)),
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
// Create a brand-new login account for a staff member (Expert, Dept Head or Dean)
void _showAddStaffDialog(BuildContext context) {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String role = 'expert';
  String department = 'ICT';
  bool saving = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Column(
          children: [
            IconBubble(icon: Icons.person_add_alt_1_rounded, color: AppPalette.primary, size: 52),
            const SizedBox(height: 12),
            const Text("Add New Staff / User", textAlign: TextAlign.center),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: appInputDecoration(label: "Full Name", icon: Icons.person_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: appInputDecoration(label: "Email Address", icon: Icons.email_outlined),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: appInputDecoration(label: "Initial Password", icon: Icons.lock_outline),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'expert', child: Text("Expert")),
                    DropdownMenuItem(value: 'deptHead', child: Text("Department Head")),
                    DropdownMenuItem(value: 'dean', child: Text("Dean")),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'expert'),
                  decoration: appInputDecoration(label: "Role", icon: Icons.admin_panel_settings_outlined),
                ),
                if (role != 'dean') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: department,
                    items: _collegeDepartments
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => department = v ?? 'ICT'),
                    decoration: appInputDecoration(label: "Department", icon: Icons.account_tree_outlined),
                  ),
                ],
                if (role == 'dean') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppPalette.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.school_outlined, size: 18, color: AppPalette.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Dean accounts are college-wide (College Administration) and won't appear in a department list.",
                            style: TextStyle(fontSize: 12.5, color: AppPalette.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: AppPalette.textMuted)),
          ),
          GradientButton(
            label: saving ? "Creating…" : "Create User",
            icon: Icons.person_add_alt_1_rounded,
            width: 170,
            height: 46,
            fontSize: 13,
            onPressed: saving
                ? null
                : () async {
                    if (nameController.text.trim().isEmpty ||
                        emailController.text.trim().isEmpty ||
                        passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text("Please fill in all fields")),
                      );
                      return;
                    }
                    final emailError = emailField(emailController.text);
                    if (emailError != null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(emailError)),
                      );
                      return;
                    }
                    if (passwordController.text.length < 6) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                            content: Text("Password must be at least 6 characters")),
                      );
                      return;
                    }
                    setDialogState(() => saving = true);
                    UserCredential? cred;
                    try {
                      // 1. Create the Firebase Auth login account so the user can sign in.
                      cred = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                      );
                      // 2. Create the profile — Deans are college-wide, everyone
                      //    else belongs to their chosen department.
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(cred.user!.uid)
                          .set({
                        'uid': cred.user!.uid,
                        'fullName': nameController.text.trim(),
                        'name': nameController.text.trim(), // legacy display alias
                        'email': emailController.text.trim(),
                        'role': role,
                        'department': role == 'dean' ? 'College Administration' : department,
                        'createdBy': FirebaseAuth.instance.currentUser?.uid,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (!mounted) return;
                      final roleLabel =
                          role == 'dean'
                              ? 'Dean'
                              : (role == 'deptHead' ? 'Department Head' : 'Expert');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                "$roleLabel account created — they can sign in now.")),
                      );
                    } on FirebaseAuthException catch (e) {
                      if (!dialogContext.mounted) return;
                      setDialogState(() => saving = false);
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(e.message ?? "Could not create user")),
                      );
                    } catch (e) {
                      // Roll back the auth account if the profile write failed,
                      // so the new user can't get stuck without a users doc.
                      if (cred != null) {
                        try {
                          await cred.user?.delete();
                        } catch (_) {}
                      }
                      if (!dialogContext.mounted) return;
                      setDialogState(() => saving = false);
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    }
                  },
          ),
        ],
      ),
    ),
  );
}
// ==================== BROADCAST TOOL (COLLEGE-WIDE / DEPT / ROLE) ====================
void _showBroadcastDialog() {
  final subjectController = TextEditingController();
  final messageController = TextEditingController();
  String audience = 'all'; // 'all' | 'department' | 'role'
  String department = 'ICT';
  String roleTarget = 'expert';
  String priority = 'Normal';
  bool sending = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Column(
          children: [
            IconBubble(icon: Icons.campaign_rounded, color: AppPalette.primary, size: 52),
            const SizedBox(height: 12),
            const Text("Broadcast Message", textAlign: TextAlign.center),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: appInputDecoration(label: "Subject / Title", icon: Icons.title),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: appInputDecoration(
                    label: "Message Body",
                    icon: Icons.message_outlined,
                    alignLabel: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: audience,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text("College-Wide (All Staff)")),
                    DropdownMenuItem(value: 'department', child: Text("Specific Department")),
                    DropdownMenuItem(value: 'role', child: Text("Specific Role")),
                  ],
                  onChanged: (v) => setDialogState(() => audience = v ?? 'all'),
                  decoration: appInputDecoration(
                      label: "Target Audience", icon: Icons.people_alt_outlined),
                ),
                if (audience == 'department') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: department,
                    items: _collegeDepartments
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => department = v ?? 'ICT'),
                    decoration: appInputDecoration(label: "Department", icon: Icons.account_tree_outlined),
                  ),
                ],
                if (audience == 'role') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: roleTarget,
                    items: const [
                      DropdownMenuItem(value: 'expert', child: Text("All Experts")),
                      DropdownMenuItem(value: 'deptHead', child: Text("All Department Heads")),
                      DropdownMenuItem(value: 'dean', child: Text("All Deans")),
                    ],
                    onChanged: (v) => setDialogState(() => roleTarget = v ?? 'expert'),
                    decoration: appInputDecoration(label: "Role", icon: Icons.badge_outlined),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: priority,
                  items: ['High', 'Normal', 'Low']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => priority = v ?? 'Normal'),
                  decoration: appInputDecoration(label: "Priority", icon: Icons.priority_high_rounded),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppPalette.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, size: 18, color: AppPalette.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _broadcastAudienceLabel(audience, department, roleTarget),
                          style: TextStyle(fontSize: 12.5, color: AppPalette.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: AppPalette.textMuted)),
          ),
          GradientButton(
            label: sending ? "Sending…" : "Send Broadcast",
            icon: Icons.send_rounded,
            width: 180,
            height: 46,
            fontSize: 13,
            onPressed: sending
                ? null
                : () async {
                    if (subjectController.text.trim().isEmpty ||
                        messageController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                            content: Text("Please fill in subject and message")),
                      );
                      return;
                    }
                    setDialogState(() => sending = true);
                    final ok = await _sendBroadcast(
                      title: subjectController.text.trim(),
                      message: messageController.text.trim(),
                      audience: audience,
                      department: department,
                      roleTarget: roleTarget,
                      priority: priority,
                    );
                    if (!dialogContext.mounted) return;
                    if (ok) {
                      Navigator.pop(dialogContext);
                    } else {
                      setDialogState(() => sending = false);
                    }
                  },
          ),
        ],
      ),
    ),
  );
}

// Human-readable summary of who will receive the broadcast.
String _broadcastAudienceLabel(String audience, String department, String roleTarget) {
  switch (audience) {
    case 'department':
      return "Will be delivered to every staff member in $department.";
    case 'role':
      final label = roleTarget == 'expert'
          ? 'All Experts'
          : (roleTarget == 'deptHead' ? 'All Department Heads' : 'All Deans');
      return "Will be delivered to $label.";
    default:
      return "Will be delivered to all staff college-wide.";
  }
}

// Publish the broadcast to the 'notifications' collection — every dashboard's
// NotificationBell reads this collection and filters by audience/department/roles.
Future<bool> _sendBroadcast({
  required String title,
  required String message,
  required String audience,
  required String department,
  required String roleTarget,
  required String priority,
}) async {
  try {
    switch (audience) {
      case 'department':
        await pushNotification(
          title: title,
          message: message,
          audience: 'department',
          department: department,
          priority: priority,
          type: 'announcement',
        );
      case 'role':
        await pushNotification(
          title: title,
          message: message,
          audience: 'all',
          roles: [roleTarget],
          priority: priority,
          type: 'announcement',
        );
      default:
        await pushNotification(
          title: title,
          message: message,
          audience: 'all',
          priority: priority,
          type: 'announcement',
        );
    }
    if (!mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              "Broadcast sent — staff will see it in their notification bell.")),
    );
    return true;
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Broadcast failed: $e")),
      );
    }
    return false;
  }
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

// ==================== SCHEDULE OVERVIEW (read-only — Dean) ====================
Widget _buildScheduleOverviewView() {
  return Container(
    margin: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: Color(0xFF0D47A1), size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("College Schedule Overview",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  Text("Read-only view of all weekly visit schedules across departments",
                      style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('expert_schedules')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error loading schedules: ${snapshot.error}"));
              }
              final all = snapshot.data?.docs ?? [];

              // Build filter options from the loaded schedules.
              final departments = <String>{};
              final experts = <String>{};
              for (final d in all) {
                final m = d.data() as Map<String, dynamic>;
                final dept = (m['department'] ?? '').toString();
                if (dept.isNotEmpty) departments.add(dept);
                final name = (m['expertName'] ?? '').toString();
                if (name.isNotEmpty) experts.add(name);
              }
              final deptList = <String>['All', ...departments]..sort();
              final expertList = <String>['All', ...experts]..sort();
              final deptFilter = deptList.contains(_scheduleDeptFilter)
                  ? _scheduleDeptFilter
                  : 'All';
              final expertFilter = expertList.contains(_scheduleExpertFilter)
                  ? _scheduleExpertFilter
                  : 'All';

              final filtered = all.where((d) {
                final m = d.data() as Map<String, dynamic>;
                final dept = (m['department'] ?? '').toString();
                final name = (m['expertName'] ?? '').toString();
                if (deptFilter != 'All' && dept != deptFilter) return false;
                if (expertFilter != 'All' && name != expertFilter) return false;
                return true;
              }).toList();

              return Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 230,
                        child: DropdownButtonFormField<String>(
                          value: deptFilter,
                          items: deptList
                              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _scheduleDeptFilter = v ?? 'All'),
                          decoration: appInputDecoration(
                              label: "Department", icon: Icons.account_tree_outlined),
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 230,
                        child: DropdownButtonFormField<String>(
                          value: expertFilter,
                          items: expertList
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _scheduleExpertFilter = v ?? 'All'),
                          decoration: appInputDecoration(
                              label: "Expert", icon: Icons.person_outline),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${filtered.length} schedule${filtered.length == 1 ? '' : 's'}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy_outlined, size: 60, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text("No schedules match the selected filters.",
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text("Expert")),
                                DataColumn(label: Text("Department")),
                                DataColumn(label: Text("Enterprise")),
                                DataColumn(label: Text("Days")),
                                DataColumn(label: Text("Week")),
                                DataColumn(label: Text("Objectives")),
                              ],
                              rows: filtered.map((d) {
                                final m = d.data() as Map<String, dynamic>;
                                final days = m['days'];
                                final dayList = days is List ? days.join(', ') : '—';
                                return DataRow(cells: [
                                  DataCell(Text((m['expertName'] ?? '—').toString())),
                                  DataCell(Text((m['department'] ?? '—').toString())),
                                  DataCell(Text((m['enterpriseName'] ?? '—').toString())),
                                  DataCell(Text(dayList)),
                                  DataCell(Text(
                                      "${_fmtSchedDate(m['startDate'])} → ${_fmtSchedDate(m['endDate'])}")),
                                  DataCell(SizedBox(
                                    width: 260,
                                    child: Text(
                                      (m['objectives'] ?? '').toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                                ]);
                              }).toList(),
                            ),
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

String _fmtSchedDate(Object? raw) {
  if (raw == null) return '—';
  final s = raw.toString();
  if (s.isEmpty) return '—';
  try {
    return DateFormat('dd MMM yyyy').format(DateTime.parse(s));
  } catch (_) {
    return s;
  }
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
              title: "Change Password",
              subtitle: "Update your sign-in credentials",
              icon: Icons.password_rounded,
              color: Colors.purple,
              onTap: () async {
                final changed = await showChangePasswordDialog(context);
                if (changed && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Password updated successfully.")),
                  );
                }
              },
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
    String woreda = (doc.data() as Map<String, dynamic>?)?['woreda']?.toString() ?? 'Unknown';
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
              target: LatLng(8.9599, 38.7115), // Center on Jemo, Addis Ababa
              zoom: 14.5,
            ),
            markers: markers,
            mapType: MapType.normal,
            myLocationEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true, // Allows users to open coordinates in Google Maps
            // Keep the map fully interactive: standard scroll, drag,
            // pinch-zoom and rotate gestures all enabled (this matches the
            // plugin's gestureScaleByMapCenter: false default), so users can
            // freely pan and re-center anywhere across Addis Ababa.
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
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
