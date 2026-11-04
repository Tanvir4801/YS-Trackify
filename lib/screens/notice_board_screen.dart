import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/theme/app_colors.dart';
import '../models/notice_model.dart';
import '../services/labour_mode/labour_firestore_service.dart';
import '../services/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/error_handler.dart';

class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({super.key});

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  final LabourFirestoreService _firestoreService = LabourFirestoreService();
  final _messageController = TextEditingController();
  bool _isPosting = false;

  late String _supervisorId;
  late String _contractorId;

  @override
  void initState() {
    super.initState();
    _supervisorId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _contractorId = SessionService.instance.contractorId ?? _supervisorId;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _postNotice() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final notice = Notice(
        id: const Uuid().v4(),
        contractorId: _contractorId,
        supervisorId: _supervisorId,
        message: text,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await _firestoreService.postNotice(notice);
      _messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notice broadcasted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getUserFriendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Notice Board'),
        backgroundColor: AppColors.surfaceColor(context),
        foregroundColor: AppColors.textPrimaryColor(context),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          _buildPostForm(),
          Expanded(
            child: StreamBuilder<List<Notice>>(
              stream: _firestoreService.streamNotices(_supervisorId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: AppColors.primaryColor(context)));
                }
                final notices = snapshot.data ?? [];
                if (notices.isEmpty) {
                  return Center(
                    child: Text(
                      'No active notices.',
                      style: TextStyle(color: AppColors.textSecondaryColor(context)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final n = notices[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevatedColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.campaign_rounded, color: AppColors.primaryColor(context), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Broadcast',
                                style: TextStyle(
                                  color: AppColors.primaryColor(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            n.message,
                            style: TextStyle(color: AppColors.textPrimaryColor(context), fontSize: 16),
                          ),
                        ],
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

  Widget _buildPostForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surfaceSecondaryColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _messageController,
            style: TextStyle(color: AppColors.textPrimaryColor(context)),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., Tomorrow holiday. Salary on Sunday.',
              hintStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
              filled: true,
              fillColor: AppColors.surfaceElevatedColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isPosting ? null : _postNotice,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor(context),
              foregroundColor: AppColors.textOnPrimaryColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isPosting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: AppColors.textOnPrimaryColor(context), strokeWidth: 2),
                  )
                : const Text(
                    'Broadcast Notice',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }
}
