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
import '../../../widgets/glass_card.dart';

class ToolkitItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;
  final Widget screen;

  ToolkitItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
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

  List<ToolkitItem> get _allTools => [
    ToolkitItem(
      id: 'concrete',
      title: 'Concrete',
      description: 'Volume & mix proportions',
      icon: Icons.domain_rounded,
      color: CalcColors.concrete(context),
      features: const ['Slabs • Beams'],
      screen: const ConcreteScreen(),
    ),
    ToolkitItem(
      id: 'steel',
      title: 'Steel',
      description: 'Reinforcement bar weight',
      icon: Icons.linear_scale_rounded,
      color: CalcColors.steel(context),
      features: const ['Rebar Weight'],
      screen: const SteelScreen(),
    ),
    ToolkitItem(
      id: 'area',
      title: 'Area Works',
      description: 'Finishing quantities',
      icon: Icons.grid_view_rounded,
      color: CalcColors.areaWorks(context),
      features: const ['Tiles • Flooring'],
      screen: const AreaScreen(),
    ),
    ToolkitItem(
      id: 'mat_cost',
      title: 'Material Cost Estimator',
      description: 'Material cost breakdown',
      icon: Icons.request_quote_rounded,
      color: Theme.of(context).brightness == Brightness.dark ? AppColors.orange : const Color(0xFFF97316),
      features: const ['Unit Rates'],
      screen: const MaterialCostScreen(),
    ),
    ToolkitItem(
      id: 'earthwork',
      title: 'Earthwork',
      description: 'Excavation & filling',
      icon: Icons.terrain_rounded,
      color: CalcColors.earthwork(context),
      features: const ['Trench Volume'],
      screen: const EarthworkScreen(),
    ),
    ToolkitItem(
      id: 'labour_cost',
      title: 'Labour Cost Estimator',
      description: 'Workforce cost projection',
      icon: Icons.groups_rounded,
      color: Theme.of(context).brightness == Brightness.dark ? AppColors.danger : const Color(0xFFF43F5E),
      features: const ['Team Size'],
      screen: const LabourCostScreen(),
    ),
    ToolkitItem(
      id: 'structural',
      title: 'Structural',
      description: 'Load & capacity checks',
      icon: Icons.account_balance_rounded,
      color: CalcColors.structural(context),
      features: const ['Beams • Columns'],
      screen: const StructuralScreen(),
    ),
    ToolkitItem(
      id: 'converter',
      title: 'Converter',
      description: 'Civil unit conversions',
      icon: Icons.swap_horiz_rounded,
      color: CalcColors.converter(context),
      features: const ['Length • Area'],
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: isDark ? BoxDecoration(color: AppColors.backgroundColor(context)) : const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF4F7FB),
            Color(0xFFF0F4F8),
            Color(0xFFF4F7FB),
          ],
        ),
      ),
      child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF0B3157)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Construction Toolkit', style: TextStyle(color: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF0B3157), fontWeight: FontWeight.w700, fontSize: 18)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              child: GlassCard(
                useBlur: true,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                borderRadius: 14,
                baseColorTint: isDark ? null : const Color(0xFFFFF9E6),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                },
                child: Icon(Icons.history_rounded, color: const Color(0xFFF5A900), size: 20),
              ),
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
            _buildGridSection(searchResults, provider)
          else ...[
            if (provider.favorites.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text('Favorites', style: TextStyle(color: AppColors.textPrimaryColor(context), fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              _buildGridSection(provider.favorites.map((id) => _allTools.firstWhere((t) => t.id == id)).toList(), provider),
            ],
            ..._categorizedTools.entries.map((entry) {
              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key, style: TextStyle(color: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF0B3157), fontWeight: FontWeight.w700, fontSize: 15)),
                          Text('View all', style: TextStyle(color: isDark ? AppColors.primaryColor(context) : const Color(0xFFF5A900), fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  _buildGridSection(entry.value, provider),
                ],
              );
            }),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      useBlur: true,
      padding: EdgeInsets.zero,
      borderRadius: 18,
      baseColorTint: isDark ? null : Colors.white,
      tintOpacityLight: 0.85,
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF0B3157), fontSize: 14),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search calculators...',
          hintStyle: TextStyle(color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6B8AAA), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6B8AAA), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6B8AAA), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : Icon(Icons.tune_rounded, color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6B8AAA), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildGridSection(List<ToolkitItem> items, ToolkitProvider provider) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text('No calculators found.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ),
        ),
      );
    }
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildGridCard(items[index], provider),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildGridCard(ToolkitItem tool, ToolkitProvider provider) {
    final isFavorite = provider.isFavorite(tool.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassCard(
      useBlur: true,
      padding: const EdgeInsets.all(14),
      borderRadius: 24,
      baseColorTint: isDark ? null : Colors.white,
      tintOpacityLight: 0.8,
      onTap: () => _navigateToTool(tool),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(tool.icon, color: tool.color, size: 24),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  provider.toggleFavorite(tool.id);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      key: ValueKey(isFavorite),
                      color: isFavorite ? const Color(0xFFF5A900) : (isDark ? AppColors.textTertiaryColor(context).withValues(alpha: 0.5) : const Color(0xFFA8BDD0)),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tool.title, 
            style: TextStyle(color: isDark ? AppColors.textPrimaryColor(context) : const Color(0xFF0B3157), fontWeight: FontWeight.w700, fontSize: 13, height: 1.2), 
            maxLines: 2, 
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            tool.description, 
            style: TextStyle(color: isDark ? AppColors.textSecondaryColor(context) : const Color(0xFF6483A3), fontSize: 11, fontWeight: FontWeight.w500, height: 1.2), 
            maxLines: 2, 
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tool.features.map((f) => _buildFeatureChip(f, tool.color, isDark)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String text, Color accentColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withValues(alpha: isDark ? 0.3 : 0.15)),
      ),
      child: Text(text, style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}
