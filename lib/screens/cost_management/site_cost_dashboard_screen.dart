import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../providers/cost_management_provider.dart';
import '../../providers/sites_provider.dart';
import '../../providers/closing_report_provider.dart';
import 'material_management_screen.dart';
import 'supplier_management_screen.dart';
import '../../core/theme/app_colors.dart';

class SiteCostDashboardScreen extends StatefulWidget {
  const SiteCostDashboardScreen({super.key});

  @override
  State<SiteCostDashboardScreen> createState() => _SiteCostDashboardScreenState();
}

class _SiteCostDashboardScreenState extends State<SiteCostDashboardScreen> {
  String? _selectedSiteId;
  String _timeFilter = 'Monthly'; // Daily, Weekly, Monthly

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sitesProv = context.read<SitesProvider>();
      sitesProv.load().then((_) {
        if (sitesProv.sites.isNotEmpty) {
          setState(() {
            _selectedSiteId = sitesProv.sites.first.id;
          });
          _loadData();
        }
      });
    });
  }

  Future<void> _loadData() async {
    if (_selectedSiteId == null) return;
    final costProv = context.read<CostManagementProvider>();
    await costProv.loadDashboardData(siteId: _selectedSiteId);
    
    // Also load closing reports for the site to get Labour Cost
    final reportProv = context.read<ClosingReportProvider>();
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    String startDate = '';
    if (_timeFilter == 'Daily') {
      startDate = formatter.format(now);
    } else if (_timeFilter == 'Weekly') {
      startDate = formatter.format(now.subtract(const Duration(days: 7)));
    } else {
      startDate = formatter.format(DateTime(now.year, now.month, 1));
    }
    await reportProv.loadHistory(
      siteId: _selectedSiteId, 
      startDate: startDate,
      endDate: formatter.format(now),
    );
  }

  @override
  Widget build(BuildContext context) {
    final costProv = context.watch<CostManagementProvider>();
    final reportProv = context.watch<ClosingReportProvider>();
    final sitesProv = context.watch<SitesProvider>();

    // Calculate Labour Cost from Daily Closing Reports
    double totalLabourCost = 0;
    for (var r in reportProv.savedReports) {
      totalLabourCost += r.totalExpense;
    }

    final totalMaterial = costProv.totalMaterialCost;
    final totalMachinery = costProv.totalMachineryCost;
    final totalTransport = costProv.totalTransportCost;
    final totalMisc = costProv.totalMiscCost;
    
    final grandTotal = totalLabourCost + totalMaterial + totalMachinery + totalTransport + totalMisc;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.navy, // Deep navy
      appBar: AppBar(
        title: const Text('Site Cost Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navyLight,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt, color: AppColors.gold),
            tooltip: 'Suppliers',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierManagementScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.inventory, color: AppColors.gold),
            tooltip: 'Materials',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MaterialManagementScreen(siteId: _selectedSiteId)));
            },
          ),
        ],
      ),
      body: (costProv.isLoading || reportProv.isLoading) && costProv.materialPurchases.isEmpty && costProv.siteExpenses.isEmpty && reportProv.savedReports.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.gold,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // Site and Time Filter row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildDropdown(
                          value: _selectedSiteId,
                          items: sitesProv.sites.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                          onChanged: (val) {
                            setState(() => _selectedSiteId = val as String);
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildDropdown(
                          value: _timeFilter,
                          items: ['Daily', 'Weekly', 'Monthly'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) {
                            setState(() => _timeFilter = val as String);
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Grand Total Card (Fintech Style)
                  Center(
                    child: Column(
                      children: [
                        Text('$_timeFilter Cost'.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Text(currency.format(grandTotal), style: const TextStyle(color: AppColors.gold, fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_upward_rounded, color: Colors.green, size: 14),
                              SizedBox(width: 4),
                              Text('12% from yesterday', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Analytics List
                  const Text('COST BREAKDOWN', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.navyLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildListTile('Labour', totalLabourCost, Icons.engineering, const Color(0xFF22C55E)),
                        const Divider(height: 1, color: AppColors.border, indent: 56),
                        _buildListTile('Materials', totalMaterial, Icons.foundation, const Color(0xFF3B82F6)),
                        const Divider(height: 1, color: AppColors.border, indent: 56),
                        _buildListTile('Machinery', totalMachinery, Icons.precision_manufacturing, const Color(0xFFF59E0B)),
                        const Divider(height: 1, color: AppColors.border, indent: 56),
                        _buildListTile('Transport', totalTransport, Icons.local_shipping, const Color(0xFF8B5CF6)),
                        if (totalMisc > 0) ...[
                          const Divider(height: 1, color: AppColors.border, indent: 56),
                          _buildListTile('Misc', totalMisc, Icons.receipt_long, Colors.grey),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Top Purchased Materials
                  if (costProv.materialPurchases.isNotEmpty) ...[
                    const Text('TOP PURCHASED MATERIALS', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    _buildTopMaterials(costProv.materialPurchases),
                    const SizedBox(height: 32),
                  ],



                  // Expense Chart
                  if (grandTotal > 0)
                    Container(
                      height: 250,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.navyLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Expense Distribution', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: [
                                  if (totalLabourCost > 0) _pieSection(totalLabourCost, grandTotal, const Color(0xFF22C55E), 'Labour'),
                                  if (totalMaterial > 0) _pieSection(totalMaterial, grandTotal, const Color(0xFF3B82F6), 'Mat'),
                                  if (totalMachinery > 0) _pieSection(totalMachinery, grandTotal, const Color(0xFFF59E0B), 'Mach'),
                                  if (totalTransport > 0) _pieSection(totalTransport, grandTotal, const Color(0xFF8B5CF6), 'Trans'),
                                  if (totalMisc > 0) _pieSection(totalMisc, grandTotal, Colors.grey, 'Misc'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildDropdown({required String? value, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.navyLight,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.gold),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildListTile(String title, double amount, IconData icon, Color color) {
    final currency = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
          Text(currency.format(amount), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTopMaterials(List<dynamic> purchases) {
    final Map<String, double> materialTotals = {};
    for (var p in purchases) {
      materialTotals[p.materialName] = (materialTotals[p.materialName] ?? 0) + p.totalAmount;
    }
    final topMaterials = materialTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final displayList = topMaterials.take(4).toList();
    final currency = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: displayList.asMap().entries.map((entry) {
          final idx = entry.key;
          final mat = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text(mat.key.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(mat.key, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                    Text(currency.format(mat.value), style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (idx < displayList.length - 1) const Divider(height: 1, color: AppColors.border, indent: 72),
            ],
          );
        }).toList(),
      ),
    );
  }

  PieChartSectionData _pieSection(double value, double total, Color color, String title) {
    final percentage = (value / total * 100).toStringAsFixed(0);
    return PieChartSectionData(
      color: color,
      value: value,
      title: '$percentage%',
      radius: 50,
      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }
}
