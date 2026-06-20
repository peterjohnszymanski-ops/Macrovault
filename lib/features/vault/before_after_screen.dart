import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/models/progress_photo.dart';
import 'package:macrovault/state/providers.dart';

final _allPhotosProvider = FutureProvider<List<ProgressPhoto>>((ref) async {
  ref.logMutationToken;
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  final list = await ref.watch(servicesProvider).photos.all(user.id);
  list.sort((a, b) => a.day.compareTo(b.day));
  return list;
});

/// Side-by-side before/after comparison. Defaults to earliest vs latest; both
/// sides are selectable.
class BeforeAfterScreen extends ConsumerStatefulWidget {
  const BeforeAfterScreen({super.key});

  @override
  ConsumerState<BeforeAfterScreen> createState() => _BeforeAfterScreenState();
}

class _BeforeAfterScreenState extends ConsumerState<BeforeAfterScreen> {
  int? _leftIndex;
  int? _rightIndex;

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(_allPhotosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Before / after')),
      body: photos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.length < 2) {
            return const EmptyHint(
                'Add at least two photos to compare.',
                icon: Icons.compare);
          }
          final left = _leftIndex ?? 0;
          final right = _rightIndex ?? list.length - 1;
          return Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _Side(photo: list[left], label: 'Before')),
                    Expanded(child: _Side(photo: list[right], label: 'After')),
                  ],
                ),
              ),
              _Picker(
                list: list,
                leftIndex: left,
                rightIndex: right,
                onLeft: (i) => setState(() => _leftIndex = i),
                onRight: (i) => setState(() => _rightIndex = i),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Side extends ConsumerWidget {
  const _Side({required this.photo, required this.label});
  final ProgressPhoto photo;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.read(servicesProvider).photoStorage;
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<String>(
            future: storage.absolutePath(photo.relativePath),
            builder: (_, snap) {
              if (!snap.hasData || !File(snap.data!).existsSync()) {
                return const ColoredBox(color: Colors.black12);
              }
              return Image.file(File(snap.data!), fit: BoxFit.cover);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text('$label · ${Days.prettyMonthDay(photo.day)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.list,
    required this.leftIndex,
    required this.rightIndex,
    required this.onLeft,
    required this.onRight,
  });

  final List<ProgressPhoto> list;
  final int leftIndex;
  final int rightIndex;
  final ValueChanged<int> onLeft;
  final ValueChanged<int> onRight;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: leftIndex,
                decoration: const InputDecoration(labelText: 'Before'),
                items: [
                  for (var i = 0; i < list.length; i++)
                    DropdownMenuItem(
                        value: i,
                        child: Text(
                            '${list[i].pose.label} ${Days.prettyMonthDay(list[i].day)}')),
                ],
                onChanged: (i) => i != null ? onLeft(i) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: rightIndex,
                decoration: const InputDecoration(labelText: 'After'),
                items: [
                  for (var i = 0; i < list.length; i++)
                    DropdownMenuItem(
                        value: i,
                        child: Text(
                            '${list[i].pose.label} ${Days.prettyMonthDay(list[i].day)}')),
                ],
                onChanged: (i) => i != null ? onRight(i) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
