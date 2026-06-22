import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/calc_constants.dart';
import '../models/calc_history_item.dart';
import '../services/calc_history_service.dart';

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
      backgroundColor: CalcColors.pageBg,
      appBar: AppBar(
        backgroundColor: CalcColors.pageBg,
        elevation: 0,
        title: const Text('History', style: CalcTextStyles.screenTitle),
        iconTheme: const IconThemeData(color: CalcColors.textPrimary),
        actions: [
          if (_history.isNotEmpty)
            TextButton(
              onPressed: () => _clearHistory(),
              child: const Text('Clear', style: TextStyle(color: CalcColors.red)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CalcColors.amber))
          : _history.isEmpty
              ? const Center(
                  child: Text(
                    'No calculations yet.',
                    style: TextStyle(color: CalcColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(CalcDimens.pagePadding),
                  itemCount: _history.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CalcColors.surface,
                        borderRadius: BorderRadius.circular(CalcDimens.radiusLg),
                        border: Border.all(color: CalcColors.border, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CalcColors.amber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM, hh:mm a').format(item.timestamp),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CalcColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: CalcColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: CalcColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
