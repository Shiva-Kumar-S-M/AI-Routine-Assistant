import 'package:flutter/material.dart';
import '../../domain/models/emotional_log.dart';
import '../../data/repositories/usage_repository.dart';
import '../../services/app_label_helper.dart';

class PostSessionCheckInDialog extends StatelessWidget {
  final String packageName;
  final String appName;
  final int? usageLogId;

  const PostSessionCheckInDialog({
    super.key,
    required this.packageName,
    required this.appName,
    this.usageLogId,
  });

  static Future<void> show(
    BuildContext context, {
    required String packageName,
    required String appName,
    int? usageLogId,
  }) async {
    return showDialog(
      context: context,
      builder: (_) => PostSessionCheckInDialog(
        packageName: packageName,
        appName: appName,
        usageLogId: usageLogId,
      ),
    );
  }

  Future<void> _logEmotion(BuildContext context, String emotion) async {
    final repo = UsageRepository();
    final log = EmotionalLog(
      usageLogId: usageLogId,
      packageName: packageName,
      triggerEmotion: emotion,
      timestamp: DateTime.now(),
    );
    await repo.insertEmotionalLog(log);

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emotional trigger logged: $emotion'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.psychology, color: Color(0xFF6750A4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Session Check-In: ${(appName.isNotEmpty && appName != packageName) ? appName : AppLabelHelper.cleanPackageName(packageName)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What triggered this session? (One-tap log for ML routine insights)',
            style: TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _emotionButton(context, '🥱', 'bored', 'Bored'),
              _emotionButton(context, '😰', 'anxious', 'Anxious'),
              _emotionButton(context, '🔄', 'habit', 'Habit'),
              _emotionButton(context, '✅', 'needed_it', 'Needed It'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emotionButton(BuildContext context, String emoji, String tag, String label) {
    return InkWell(
      onTap: () => _logEmotion(context, tag),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
