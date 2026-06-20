import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/settings/edit_goal_screen.dart';
import 'package:macrovault/features/settings/recipes_screen.dart';
import 'package:macrovault/models/user.dart';
import 'package:macrovault/state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final goal = ref.watch(activeGoalProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _section('Profile'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user?.name ?? '—'),
            subtitle: Text('Units: ${user?.units.storageValue ?? '—'}'),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Goal & targets'),
            subtitle: goal == null
                ? null
                : Text(
                    '${goal.type.label} · ${goal.calorieTarget} kcal · ${goal.proteinTargetG.round()}g protein'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const EditGoalScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Recipes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecipesScreen())),
          ),

          _section('Privacy & security'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Lock the Vault'),
            subtitle:
                const Text('Require Face ID / passcode to open your Vault'),
            value: user?.vaultLockEnabled ?? false,
            onChanged: user == null
                ? null
                : (v) async {
                    final services = ref.read(servicesProvider);
                    if (v) {
                      final ok = await services.vaultLock.authenticate(
                          reason: 'Confirm to enable the Vault lock');
                      if (!ok) return;
                    }
                    await services.profile
                        .upsertUser(user.copyWith(vaultLockEnabled: v));
                    ref.invalidate(currentUserProvider);
                  },
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Export everything'),
            subtitle: const Text('Download all your data as a ZIP'),
            onTap: () => _export(context, ref),
          ),

          _section('AI (optional)'),
          ListTile(
            leading: const Icon(Icons.camera_enhance_outlined),
            title: const Text('Food photo AI'),
            subtitle: Text(user?.aiPhotoReady == true
                ? 'On — photos sent to your proxy for estimates'
                : 'Off — local-first by default'),
            trailing: const Icon(Icons.chevron_right),
            onTap: user == null ? null : () => _configureAi(context, ref, user),
          ),

          _section('Danger zone'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.danger),
            title: const Text('Delete all data',
                style: TextStyle(color: AppColors.danger)),
            onTap: () => _deleteAll(context, ref),
          ),

          _section('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('MacroVault'),
            subtitle: Text(
                'Local-first. No accounts, no cloud, no AI. Your data stays on this device, encrypted.'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(s.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final includeMedia = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export everything'),
        content: const Text(
          'This creates a ZIP with all your logs (JSON + CSV).\n\n'
          'You can also include your private progress photos. '
          'Anyone you share the file with will be able to see them — '
          'your health metrics are kept in separate data files, never embedded '
          'in the images.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Data only')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Include photos')),
        ],
      ),
    );
    if (includeMedia == null) return;
    try {
      await ref
          .read(servicesProvider)
          .export
          .exportAndShare(includeMedia: includeMedia);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _configureAi(
      BuildContext context, WidgetRef ref, AppUser user) async {
    var consent = user.aiConsent;
    final urlController =
        TextEditingController(text: user.aiProxyUrl ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Food photo AI'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'When on, a meal photo is sent to a vision proxy you control, '
                'which returns calorie/macro estimates. The app never stores an '
                'API key — your proxy calls the model. You always confirm the '
                'results before anything is logged.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: (v) => setLocal(() => consent = v),
                title: const Text('Enable food photo AI'),
              ),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Vision proxy URL',
                  hintText: 'https://your-proxy.example.com/recognize',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await ref.read(servicesProvider).profile.upsertUser(user.copyWith(
          aiConsent: consent,
          aiProxyUrl: urlController.text.trim(),
        ));
    ref.invalidate(currentUserProvider);
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
            'This permanently erases everything on this device — logs, weights, '
            'photos, and your Vault. This cannot be undone. Consider exporting first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(servicesProvider).wipeAllData();
    ref.invalidate(currentUserProvider);
    ref.invalidate(activeGoalProvider);
    ref.bumpLogMutation();
  }
}
