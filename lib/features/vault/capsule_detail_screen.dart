import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/core/formatters.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/models/progress_capsule.dart';
import 'package:macrovault/models/progress_photo.dart';
import 'package:macrovault/state/providers.dart';

final _capsuleProvider =
    FutureProvider.family<ProgressCapsule?, String>((ref, id) async {
  ref.logMutationToken;
  return ref.watch(servicesProvider).vault.capsule(id);
});

final _capsulePhotosProvider =
    FutureProvider.family<List<ProgressPhoto>, List<String>>((ref, ids) async {
  if (ids.isEmpty) return [];
  return ref.watch(servicesProvider).photos.byIds(ids);
});

class CapsuleDetailScreen extends ConsumerWidget {
  const CapsuleDetailScreen({super.key, required this.capsuleId});
  final String capsuleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_capsuleProvider(capsuleId));
    final user = ref.watch(currentUserProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capsule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final c = async.asData?.value;
              if (c == null) return;
              final yes = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete capsule?'),
                  content: const Text(
                      'This removes it from your Vault. Photos are not deleted.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete')),
                  ],
                ),
              );
              if (yes == true) {
                await ref
                    .read(servicesProvider)
                    .vault
                    .deleteVaultItem(c.vaultItemId);
                ref.bumpLogMutation();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (c) {
          if (c == null) return const Center(child: Text('Not found'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(Days.pretty(c.day),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              if (c.tags.isNotEmpty) ...[
                Gap.h8,
                Wrap(
                  spacing: 6,
                  children: [for (final t in c.tags) Chip(label: Text(t))],
                ),
              ],
              Gap.h16,
              SectionCard(
                title: 'That week',
                child: Column(
                  children: [
                    if (c.weightTrendKg != null && user != null)
                      _row('Weight (trend)',
                          Fmt.weight(c.weightTrendKg!, user.units)),
                    if (c.wkAvgKcal != null)
                      _row('Avg calories', '${c.wkAvgKcal!.round()} kcal'),
                    if (c.wkAvgProtein != null)
                      _row('Avg protein', '${c.wkAvgProtein!.round()} g'),
                    if (c.macroConsistency != null)
                      _row('Calorie adherence',
                          Fmt.percent(c.macroConsistency!)),
                    if (c.waterConsistency != null)
                      _row('Water consistency',
                          Fmt.percent(c.waterConsistency!)),
                  ],
                ),
              ),
              Gap.h16,
              if (c.whatWorked.isNotEmpty)
                _note('What worked', c.whatWorked, AppColors.good),
              if (c.whatDidnt.isNotEmpty)
                _note('What hurt', c.whatDidnt, AppColors.warn),
              if (c.whatToRepeat.isNotEmpty)
                _note('Repeat next time', c.whatToRepeat, AppColors.brand),
              if (c.moodNotes.isNotEmpty)
                _note('Reflection', c.moodNotes, AppColors.fat),
              if (c.photoIds.isNotEmpty) ...[
                Gap.h8,
                const Text('Photos',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Gap.h8,
                _CapsulePhotos(ids: c.photoIds),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _note(String title, String body, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Text(body),
            ],
          ),
        ),
      );
}

class _CapsulePhotos extends ConsumerWidget {
  const _CapsulePhotos({required this.ids});
  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(_capsulePhotosProvider(ids));
    final storage = ref.read(servicesProvider).photoStorage;
    return photos.maybeWhen(
      data: (list) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in list)
            FutureBuilder<String>(
              future: storage.absolutePath(p.relativePath),
              builder: (_, snap) {
                if (!snap.hasData || !File(snap.data!).existsSync()) {
                  return const SizedBox(width: 100, height: 130);
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(snap.data!),
                      width: 100, height: 130, fit: BoxFit.cover),
                );
              },
            ),
        ],
      ),
      orElse: () => const SizedBox(height: 20),
    );
  }
}
