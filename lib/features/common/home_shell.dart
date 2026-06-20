import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/features/dashboard/dashboard_screen.dart';
import 'package:macrovault/features/progress/progress_screen.dart';
import 'package:macrovault/features/vault/vault_screen.dart';
import 'package:macrovault/features/settings/settings_screen.dart';

/// Bottom-tab shell: Today (dashboard) · Vault · More. Weight, measurements,
/// photos and the weekly review are reached from the dashboard so logging a
/// meal stays a one-tap, zero-scroll action from the first screen.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = [
    DashboardScreen(),
    ProgressScreen(),
    VaultScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.show_chart),
              selectedIcon: Icon(Icons.insights),
              label: 'Progress'),
          NavigationDestination(
              icon: Icon(Icons.lock_outline),
              selectedIcon: Icon(Icons.lock),
              label: 'Vault'),
          NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'More'),
        ],
      ),
    );
  }
}
