import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/site_data_provider.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SiteDataProvider>(
      builder: (context, data, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                Text('YS Construction', style: Theme.of(context).textTheme.headlineSmall),
                Text(
                  'From Site to System',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 420;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isWide ? 1.45 : 1.25,
                      children: [
                        SummaryCard(
                          title: 'Total Labour',
                          value: '${data.totalLabourCount}',
                          backgroundColor: AppColors.blueCard,
                          valueColor: AppColors.primary,
                          icon: Icons.engineering,
                        ),
                        SummaryCard(
                          title: 'Today Present',
                          value: '${data.todayPresentCount}',
                          backgroundColor: AppColors.greenCard,
                          valueColor: AppColors.present,
                          icon: Icons.check_circle_outline,
                        ),
                        SummaryCard(
                          title: 'Today Absent',
                          value: '${data.todayAbsentCount}',
                          backgroundColor: AppColors.redCard,
                          valueColor: AppColors.absent,
                          icon: Icons.cancel_outlined,
                        ),
                        SummaryCard(
                          title: 'Half-Day',
                          value: '${data.todayHalfDayCount}',
                          backgroundColor: AppColors.yellowCard,
                          valueColor: AppColors.halfDay,
                          icon: Icons.timelapse_outlined,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('Wage Snapshot', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SummaryCard(
                  title: 'Today',
                  value: 'Rs ${data.todayWageTotal.toStringAsFixed(0)}',
                  backgroundColor: AppColors.blueCard,
                  valueColor: AppColors.secondary,
                  icon: Icons.currency_rupee,
                  subtitle: 'Based on current attendance',
                ),
                const SizedBox(height: 8),
                SummaryCard(
                  title: 'This Week',
                  value: 'Rs ${data.weekWageTotal.toStringAsFixed(0)}',
                  backgroundColor: AppColors.greenCard,
                  valueColor: AppColors.present,
                  icon: Icons.calendar_view_week_outlined,
                ),
                const SizedBox(height: 8),
                SummaryCard(
                  title: 'This Month',
                  value: 'Rs ${data.monthWageTotal.toStringAsFixed(0)}',
                  backgroundColor: AppColors.yellowCard,
                  valueColor: AppColors.halfDay,
                  icon: Icons.calendar_month_outlined,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
