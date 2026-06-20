import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/state/dashboard.dart';
import 'package:macrovault/state/providers.dart';

/// The No-Shame Reset prompt. Appears calmly after 2+ missed days. No guilt
/// language; just the next useful action.
class ResetPromptCard extends ConsumerWidget {
  const ResetPromptCard({super.key, required this.data});
  final DashboardData data;

  Future<void> _copyLastGoodDay(BuildContext context, WidgetRef ref) async {
    final services = ref.read(servicesProvider);
    final last = await services.entries.lastLoggedDay(data.user.id);
    if (last == null) return;
    await services.logging
        .copyDay(userId: data.user.id, fromDay: last, toDay: data.day);
    ref.bumpLogMutation();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied your last logged day. Welcome back.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.brand.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.waving_hand_outlined, color: AppColors.brand),
                SizedBox(width: 8),
                Text('Welcome back',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "It's been a few days — that's completely fine. Pick the easiest "
              'way back in. Progress is the trend, not any single day.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _copyLastGoodDay(context, ref),
                  child: const Text('Copy my last logged day'),
                ),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Fresh start. Just log your next meal — even protein-only counts.')),
                    );
                  },
                  child: const Text('Start fresh today'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
