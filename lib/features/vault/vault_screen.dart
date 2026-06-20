import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/features/vault/before_after_screen.dart';
import 'package:macrovault/features/vault/capsule_detail_screen.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/progress_capsule.dart';
import 'package:macrovault/models/vault_item.dart';
import 'package:macrovault/state/providers.dart';

final vaultItemsProvider = FutureProvider<List<VaultItem>>((ref) async {
  ref.logMutationToken;
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.watch(servicesProvider).vault.items(user.id);
});

final vaultCapsulesProvider =
    FutureProvider<List<ProgressCapsule>>((ref) async {
  ref.logMutationToken;
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.watch(servicesProvider).vault.capsules(user.id);
});

/// The Progress Vault. Gated behind biometrics when the user enables the lock;
/// re-locks when the app is backgrounded.
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-lock the moment we leave the foreground.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mounted) setState(() => _unlocked = false);
    }
  }

  Future<void> _unlock() async {
    setState(() => _checking = true);
    final ok =
        await ref.read(servicesProvider).vaultLock.authenticate();
    if (mounted) {
      setState(() {
        _unlocked = ok;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final lockEnabled = user?.vaultLockEnabled ?? false;

    if (lockEnabled && !_unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vault')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 56, color: AppColors.brand),
              const SizedBox(height: 16),
              const Text('Your Vault is locked',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('Unlock to view your progress archive.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _checking ? null : _unlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progress Vault'),
          actions: [
            IconButton(
              tooltip: 'Before / after',
              icon: const Icon(Icons.compare),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const BeforeAfterScreen())),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Timeline'),
            Tab(text: 'Capsules'),
            Tab(text: 'Search'),
          ]),
        ),
        body: const TabBarView(children: [
          _TimelineTab(),
          _CapsulesTab(),
          _SearchTab(),
        ]),
      ),
    );
  }
}

class _TimelineTab extends ConsumerWidget {
  const _TimelineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(vaultItemsProvider);
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyHint(
              'Your Vault is empty.\nFinish a Weekly Review to save your first Capsule.',
              icon: Icons.inventory_2_outlined);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) => _VaultItemTile(item: list[i]),
        );
      },
    );
  }
}

class _VaultItemTile extends StatelessWidget {
  const _VaultItemTile({required this.item});
  final VaultItem item;

  IconData get _icon => switch (item.type) {
        VaultItemType.capsule => Icons.inventory_2,
        VaultItemType.weeklyReview => Icons.event_note,
        VaultItemType.photo => Icons.photo,
        _ => Icons.flag,
      };

  @override
  Widget build(BuildContext context) {
    final isCapsule = item.type == VaultItemType.capsule;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.brand.withValues(alpha: 0.15),
          child: Icon(_icon, color: AppColors.brand),
        ),
        title: Text(item.title),
        subtitle: Text(Days.pretty(item.day)),
        trailing: isCapsule ? const Icon(Icons.chevron_right) : null,
        onTap: isCapsule && item.refId != null
            ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    CapsuleDetailScreen(capsuleId: item.refId!)))
            : null,
      ),
    );
  }
}

class _CapsulesTab extends ConsumerStatefulWidget {
  const _CapsulesTab();

  @override
  ConsumerState<_CapsulesTab> createState() => _CapsulesTabState();
}

class _CapsulesTabState extends ConsumerState<_CapsulesTab> {
  String? _tag;

  @override
  Widget build(BuildContext context) {
    final capsules = ref.watch(vaultCapsulesProvider);
    return capsules.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final tags = {for (final c in all) ...c.tags}.toList()..sort();
        final filtered =
            _tag == null ? all : all.where((c) => c.tags.contains(_tag)).toList();
        return Column(
          children: [
            if (tags.isNotEmpty)
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _tag == null,
                        onSelected: (_) => setState(() => _tag = null),
                      ),
                    ),
                    for (final t in tags)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: FilterChip(
                          label: Text(t),
                          selected: _tag == t,
                          onSelected: (_) => setState(() => _tag = t),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyHint('No capsules yet.',
                      icon: Icons.inventory_2_outlined)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) =>
                          _CapsuleCard(capsule: filtered[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CapsuleCard extends StatelessWidget {
  const _CapsuleCard({required this.capsule});
  final ProgressCapsule capsule;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text('Capsule · ${Days.prettyMonthDay(capsule.day)}'),
        subtitle: Text(capsule.tags.isEmpty
            ? '${capsule.wkAvgKcal?.round() ?? 0} kcal avg'
            : capsule.tags.join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CapsuleDetailScreen(capsuleId: capsule.id))),
      ),
    );
  }
}

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(vaultItemsProvider).asData?.value ?? [];
    final results = _q.trim().isEmpty
        ? items
        : items
            .where((i) =>
                i.title.toLowerCase().contains(_q.toLowerCase()))
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Search your Vault…',
                prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const EmptyHint('No matches.', icon: Icons.search_off)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: results.length,
                  itemBuilder: (_, i) => _VaultItemTile(item: results[i]),
                ),
        ),
      ],
    );
  }
}
