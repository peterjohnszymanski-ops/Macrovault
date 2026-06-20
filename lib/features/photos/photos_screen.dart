import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/progress_photo.dart';
import 'package:macrovault/state/providers.dart';
import 'package:uuid/uuid.dart';

final _photosProvider = FutureProvider<List<ProgressPhoto>>((ref) async {
  ref.logMutationToken;
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.watch(servicesProvider).photos.all(user.id);
});

/// Private progress photos. Imported images are EXIF-stripped and stored in the
/// app's encrypted documents dir — never the camera roll.
class PhotosScreen extends ConsumerWidget {
  const PhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(_photosProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress photos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => _add(context, ref, ImageSource.camera),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => _add(context, ref, ImageSource.gallery),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.brand.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(12),
            child: const Text(
              'Photos are private to this app, encrypted at rest, and stripped '
              'of location/EXIF data. Nothing is saved to your camera roll.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: photos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyHint(
                      'No photos yet.\nAdd a front/side/back shot to start your timeline.',
                      icon: Icons.photo_camera_outlined);
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _PhotoTile(photo: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(
      BuildContext context, WidgetRef ref, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 92);
    if (picked == null || !context.mounted) return;

    final pose = await showModalBottomSheet<Pose>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in Pose.values)
              ListTile(
                title: Text(p.label),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (pose == null) return;

    final services = ref.read(servicesProvider);
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    // Strip metadata + store privately.
    final relPath = await services.photoStorage.importStripped(picked.path);
    await services.photos.insert(ProgressPhoto(
      id: const Uuid().v4(),
      userId: user.id,
      day: Days.today(),
      pose: pose,
      relativePath: relPath,
      createdAt: DateTime.now(),
    ));
    ref.bumpLogMutation();
  }
}

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.photo});
  final ProgressPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.read(servicesProvider);
    return FutureBuilder<String>(
      future: services.photoStorage.absolutePath(photo.relativePath),
      builder: (context, snap) {
        return GestureDetector(
          onLongPress: () async {
            final yes = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete photo?'),
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
              await services.photoStorage.deleteFile(photo.relativePath);
              await services.photos.delete(photo.id);
              ref.bumpLogMutation();
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (snap.hasData && File(snap.data!).existsSync())
                  Image.file(File(snap.data!), fit: BoxFit.cover)
                else
                  Container(color: Colors.black12),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    child: Text(
                      '${photo.pose.label} · ${Days.prettyMonthDay(photo.day)}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
