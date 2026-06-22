import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/toolkit_provider.dart';
import '../utils/calc_constants.dart';
import 'concrete_screen.dart';
import 'structural_screen.dart';
import 'steel_screen.dart';
import 'area_screen.dart';
import 'earthwork_screen.dart';
import 'converter_screen.dart';
import 'history_screen.dart';
import 'material_cost_screen.dart';
import 'labour_cost_screen.dart';

class ToolkitItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final List<String> features;
  final Widget screen;

  ToolkitItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.features,
    required this.screen,
  });
}

class HomeCalcScreen extends StatefulWidget {
  const HomeCalcScreen({super.key});

  @override
  State<HomeCalcScreen> createState() => _HomeCalcScreenState();
}

class _HomeCalcScreenState extends State<HomeCalcScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<ToolkitItem> _allTools = [
    ToolkitItem(
      id: 'concrete',
      title: 'Concrete',
      description: 'Volume & mix proportions',
      icon: Icons.domain_rounded,
      color: CalcColors.concrete,
      bgColor: CalcColors.concreteBg,
      features: ['Slabs & Beams', 'Columns', 'Footings'],
      screen: const ConcreteScreen(),
    ),
    ToolkitItem(
      id: 'steel',
      title: 'Steel',
      description: 'Reinforcement bar weight',
      icon: Icons.linear_scale_rounded,
      color: CalcColors.steel,
      bgColor: CalcColors.steelBg,
      features: ['Rebar Weights', 'Length to Weight'],
      screen: const SteelScreen(),
    ),
    ToolkitItem(
      id: 'area',
      title: 'Area Works',
      description: 'Finishing quantities',
      icon: Icons.grid_view_rounded,
      color: CalcColors.areaWorks,
      bgColor: CalcColors.areaWorksBg,
      features: ['Tiles & Flooring', 'Paint & Plaster'],
      screen: const AreaScreen(),
    ),
    ToolkitItem(
      id: 'mat_cost',
      title: 'Material Cost Estimator',
      description: 'Material cost breakdown',
      icon: Icons.request_quote_rounded,
      color: AppColors.blue,
      bgColor: AppColors.blue.withValues(alpha: 0.1),
      features: ['Unit Rates', 'Total Material Cost'],
      screen: const MaterialCostScreen(),
    ),
    ToolkitItem(
      id: 'earthwork',
      title: 'Earthwork',
      description: 'Excavation & filling',
      icon: Icons.terrain_rounded,
      color: CalcColors.earthwork,
      bgColor: CalcColors.earthworkBg,
      features: ['Trench Volume', 'Soil Export'],
      screen: const EarthworkScreen(),
    ),
    ToolkitItem(
      id: 'labour_cost',
      title: 'Labour Cost Estimator',
      description: 'Workforce cost projection',
      icon: Icons.groups_rounded,
      color: AppColors.danger,
      bgColor: AppColors.danger.withValues(alpha: 0.1),
      features: ['Team Size', 'Duration & Wages'],
      screen: const LabourCostScreen(),
    ),
    ToolkitItem(
      id: 'structural',
      title: 'Structural',
      description: 'Load & capacity checks',
      icon: Icons.account_balance_rounded,
      color: CalcColors.structural,
      bgColor: CalcColors.structuralBg,
      features: ['Beams & Columns', 'Load Distribution'],
      screen: const StructuralScreen(),
    ),
    ToolkitItem(
      id: 'converter',
      title: 'Converter',
      description: 'Civil unit conversions',
      icon: Icons.swap_horiz_rounded,
      color: CalcColors.converter,
      bgColor: CalcColors.converterBg,
      features: ['Length, Area, Vol', 'Metric/Imperial'],
      screen: const ConverterScreen(),
    ),
  ];

  Map<String, List<ToolkitItem>> get _categorizedTools {
    return {
      'Material Calculators': _allTools.where((t) => ['concrete', 'steel', 'area', 'mat_cost'].contains(t.id)).toList(),
      'Site Calculators': _allTools.where((t) => ['earthwork', 'labour_cost'].contains(t.id)).toList(),
      'Structural Calculators': _allTools.where((t) => ['structural'].contains(t.id)).toList(),
      'Utilities': _allTools.where((t) => ['converter'].contains(t.id)).toList(),
    };
  }

  void _navigateToTool(ToolkitItem tool) {
    HapticFeedback.lightImpact();
    context.read<ToolkitProvider>().addToRecents(tool.id);
    Navigator.push(context, MaterialPageRoute(builder: (_) => tool.screen));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ToolkitProvider>();
    final searchResults = _searchQuery.isEmpty 
        ? <ToolkitItem>[] 
        : _allTools.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                 t.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        title: const Text('Construction Toolkit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.gold),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSearchBar(),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildSearchResults(searchResults),
            )
          else ...[
            if (provider.recents.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildHorizontalSection('Recently Used', provider.recents.map((id) => _allTools.firstWhere((t) => t.id == id)).toList(), provider),
              ),
            if (provider.favorites.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildHorizontalSection('Favorites', provider.favorites.map((id) => _allTools.firstWhere((t) => t.id == id)).toList(), provider),
              ),
            ..._categorizedTools.entries.map((entry) {
              return SliverToBoxAdapter(
                child: _buildCategorySection(entry.key, entry.value, provider),
              );
            }),
            const SliverToBoxAdapter(child: SizedBox(height: 80)), // Padding for bottom nav
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search calculators...',
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildHorizontalSection(String title, List<ToolkitItem> items, ToolkitProvider provider) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(title, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _buildHorizontalCard(items[index], provider),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHorizontalCard(ToolkitItem tool, ToolkitProvider provider) {
    return GestureDetector(
      onTap: () => _navigateToTool(tool),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tool.bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tool.icon, color: tool.color, size: 20),
                ),
                GestureDetector(
                  onTap: () => provider.toggleFavorite(tool.id),
                  child: Icon(
                    provider.isFavorite(tool.id) ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: provider.isFavorite(tool.id) ? AppColors.gold : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(tool.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(tool.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, List<ToolkitItem> items, ToolkitProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildListCard(items[index], provider),
        ),
      ],
    );
  }

  Widget _buildSearchResults(List<ToolkitItem> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text('No calculators found.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildListCard(items[index], context.watch<ToolkitProvider>()),
    );
  }

  Widget _buildListCard(ToolkitItem tool, ToolkitProvider provider) {
    return GestureDetector(
      onTap: () => _navigateToTool(tool),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tool.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tool.icon, color: tool.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(tool.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      GestureDetector(
                        onTap: () => provider.toggleFavorite(tool.id),
                        child: Icon(
                          provider.isFavorite(tool.id) ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: provider.isFavorite(tool.id) ? AppColors.gold : AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(tool.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tool.features.map((f) => _buildFeatureChip(f)).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text('• $text', style: const TextStyle(color: AppColors.goldLight, fontSize: 11)),
    );
  }
}
