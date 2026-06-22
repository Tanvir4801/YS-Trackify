import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/notification_model.dart';
import '../../services/labour_mode/labour_firestore_service.dart';

class LabourNotificationsScreen extends StatelessWidget {
  const LabourNotificationsScreen({
    super.key,
    required this.labourId,
    required this.firestoreService,
  });

  final String labourId;
  final LabourFirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: firestoreService.streamNotifications(labourId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load notifications',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  Text(
                    'No new notifications',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _NotificationCard(
                title: notif.title,
                message: notif.message,
                timestamp: notif.timestamp,
                type: notif.type,
                isUnread: !notif.isRead,
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.isUnread,
  });

  final String title;
  final String message;
  final DateTime timestamp;
  final String type;
  final bool isUnread;

  IconData _getIcon() {
    switch (type.toLowerCase()) {
      case 'attendance':
        return Icons.fact_check_rounded;
      case 'salary':
      case 'payment':
        return Icons.account_balance_wallet_rounded;
      case 'advance':
        return Icons.money_rounded;
      default:
        return Icons.message_rounded;
    }
  }

  Color _getColor() {
    switch (type.toLowerCase()) {
      case 'attendance':
        return AppColors.present;
      case 'salary':
      case 'payment':
        return AppColors.gold;
      case 'advance':
        return Colors.blueAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final timeStr = DateFormat('dd MMM, hh:mm a').format(timestamp);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? AppColors.navyLight : AppColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUnread ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_getIcon(), color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
