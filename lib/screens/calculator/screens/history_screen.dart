import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../utils/calc_constants.dart';
import '../models/calc_history_item.dart';
import '../services/calc_history_service.dart';
import 'history_detail_screen.dart';
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<CalcHistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await CalcHistoryService.getAll();
    setState(() {
      _history = list;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    await CalcHistoryService.clear();
    setState(() {
      _history = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalcColors.pageBg(context),
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg(context),
        elevation: 0,
        title: Text('History', style: CalcTextStyles.screenTitle(context)),
        iconTheme: IconThemeData(color: CalcColors.textPrimary(context)),
        actions: [
          if (_history.isNotEmpty)
            TextButton(
              onPressed: () => _clearHistory(),
              child: Text('Clear', style: TextStyle(color: CalcColors.red(context))),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: CalcColors.amber(context)))
          : _history.isEmpty
              ? Center(
                  child: Text(
                    'No calculations yet.',
                    style: TextStyle(color: CalcColors.textSecondary(context)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(CalcDimens.pagePadding),
                  itemCount: _history.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderColor(context), width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor(context).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primaryColor(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM').format(item.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiaryColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    final inputs = await Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => HistoryDetailScreen(item: item),
                                    ));
                                    if (inputs != null && mounted) {
                                      Navigator.pop(context, inputs);
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: BorderSide(color: AppColors.borderColor(context)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text('View Details', style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.pop(context, item.inputs);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor(context).withValues(alpha: 0.1),
                                    foregroundColor: AppColors.primaryColor(context),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: Text('Use Again', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
