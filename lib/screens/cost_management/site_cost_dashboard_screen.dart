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
    
    final endDate = formatter.format(now);

    final costProv = context.read<CostManagementProvider>();
    await costProv.loadDashboardData(
      siteId: _selectedSiteId,
      startDate: startDate,
      endDate: endDate,
    );
    
    // Also load closing reports for the site to get Labour Cost
    final reportProv = context.read<ClosingReportProvider>();
    await reportProv.loadHistory(
      siteId: _selectedSiteId, 
      startDate: startDate,
      endDate: endDate,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        title: Text('Site Cost Management', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surfaceElevatedColor(context),
        iconTheme: IconThemeData(color: AppColors.textPrimaryColor(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.people_alt, color: AppColors.primaryColor(context)),
            tooltip: 'Suppliers',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierManagementScreen()));
            },
          ),
          IconButton(
            icon: Icon(Icons.inventory, color: AppColors.primaryColor(context)),
            tooltip: 'Materials',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MaterialManagementScreen(siteId: _selectedSiteId)));
            },
          ),
        ],
      ),
      body: (costProv.isLoading || reportProv.isLoading) && costProv.materialPurchases.isEmpty && costProv.siteExpenses.isEmpty && reportProv.savedReports.isEmpty
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor(context)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryColor(context),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // Site and Time Filter row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildDropdown(
                          context: context,
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
                          context: context,
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
                        Text('$_timeFilter Cost'.toUpperCase(), style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Text(currency.format(grandTotal), style: TextStyle(color: AppColors.primaryColor(context), fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.successColor(context).withValues(alpha: 0.15) : const Color(0xFFDDF7EF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_upward_rounded, color: isDark ? AppColors.successColor(context) : const Color(0xFF00A878), size: 14),
                              const SizedBox(width: 4),
                              Text('12% from yesterday', style: TextStyle(color: isDark ? AppColors.successColor(context) : const Color(0xFF00A878), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Analytics List
                  Text('COST BREAKDOWN', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevatedColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderColor(context)),
                    ),
                    child: Column(
                      children: [
                        _buildListTile(context, 'Labour', totalLabourCost, Icons.engineering, isDark ? AppColors.successColor(context) : const Color(0xFF00A878), isDark ? AppColors.successColor(context).withValues(alpha: 0.15) : const Color(0xFFDDF7EF)),
                        Divider(height: 1, color: AppColors.borderColor(context), indent: 56),
                        _buildListTile(context, 'Materials', totalMaterial, Icons.foundation, isDark ? AppColors.infoColor(context) : const Color(0xFF3B82F6), isDark ? AppColors.infoColor(context).withValues(alpha: 0.15) : const Color(0xFFEAF2FF)),
                        Divider(height: 1, color: AppColors.borderColor(context), indent: 56),
                        _buildListTile(context, 'Machinery', totalMachinery, Icons.precision_manufacturing, isDark ? AppColors.warningColor(context) : const Color(0xFFD88A00), isDark ? AppColors.warningColor(context).withValues(alpha: 0.15) : const Color(0xFFFFF5D9)),
                        Divider(height: 1, color: AppColors.borderColor(context), indent: 56),
                        _buildListTile(context, 'Transport', totalTransport, Icons.local_shipping,
                            AppColors.violetColor(context),
                            isDark ? AppColors.violetColor(context).withValues(alpha: 0.15) : const Color(0xFFF0E7FF)),
                        if (totalMisc > 0) ...[
                          Divider(height: 1, color: AppColors.borderColor(context), indent: 56),
                          _buildListTile(context, 'Misc', totalMisc, Icons.receipt_long, AppColors.textSecondaryColor(context), AppColors.textSecondaryColor(context).withValues(alpha: 0.1)),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Top Purchased Materials
                  if (costProv.materialPurchases.isNotEmpty) ...[
                    Text('TOP PURCHASED MATERIALS', style: TextStyle(color: AppColors.textSecondaryColor(context), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    _buildTopMaterials(context, costProv.materialPurchases),
                    const SizedBox(height: 32),
                  ],



                  // Expense Chart
                  if (grandTotal > 0)
                    Container(
                      height: 250,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevatedColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderColor(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expense Distribution', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: [
                                  if (totalLabourCost > 0) _pieSection(context, totalLabourCost, grandTotal, isDark ? AppColors.successColor(context) : const Color(0xFF00A878), 'Labour'),
                                  if (totalMaterial > 0) _pieSection(context, totalMaterial, grandTotal, isDark ? AppColors.infoColor(context) : const Color(0xFF3B82F6), 'Mat'),
                                  if (totalMachinery > 0) _pieSection(context, totalMachinery, grandTotal, isDark ? AppColors.warningColor(context) : const Color(0xFFD88A00), 'Mach'),
                                  if (totalTransport > 0) _pieSection(context, totalTransport, grandTotal, AppColors.violetColor(context), 'Trans'),
                                  if (totalMisc > 0) _pieSection(context, totalMisc, grandTotal, AppColors.textSecondaryColor(context), 'Misc'),
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

  Widget _buildDropdown({required BuildContext context, required String? value, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceElevatedColor(context),
          style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 14),
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primaryColor(context)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, String title, double amount, IconData icon, Color color, Color bgColor) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 16, fontWeight: FontWeight.w600))),
          Text(currency.format(amount), style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTopMaterials(BuildContext context, List<dynamic> purchases) {
    final Map<String, double> materialTotals = {};
    for (var p in purchases) {
      materialTotals[p.materialName] = (materialTotals[p.materialName] ?? 0) + p.totalAmount;
    }
    final topMaterials = materialTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final displayList = topMaterials.take(4).toList();
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
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
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primaryColor(context).withValues(alpha: 0.15) : const Color(0xFFFFF5D9), 
                        borderRadius: BorderRadius.circular(10)
                      ),
                      child: Center(child: Text(mat.key.substring(0, 1).toUpperCase(), style: TextStyle(color: isDark ? AppColors.primaryColor(context) : const Color(0xFFD88A00), fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(mat.key, style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 15, fontWeight: FontWeight.w600))),
                    Text(currency.format(mat.value), style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (idx < displayList.length - 1) Divider(height: 1, color: AppColors.borderColor(context), indent: 72),
            ],
          );
        }).toList(),
      ),
    );
  }

  PieChartSectionData _pieSection(BuildContext context, double value, double total, Color color, String title) {
    final percentage = (value / total * 100).toStringAsFixed(0);
    return PieChartSectionData(
      color: color,
      value: value,
      title: '$percentage%',
      radius: 50,
      titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.surfaceElevatedColor(context)),
    );
  }
}
