import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/common/home_shell.dart';
import 'package:macrovault/features/onboarding/onboarding_screen.dart';
import 'package:macrovault/state/providers.dart';

/// Root widget. Decides between onboarding and the main shell based on whether
/// a local user exists yet.
class MacroVaultApp extends ConsumerWidget {
  const MacroVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return MaterialApp(
      title: 'MacroVault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark, // dark-first for the MacroFactor/Cal AI vibe
      home: user.when(
        loading: () => const _Splash(),
        error: (e, _) => _ErrorScreen(message: '$e'),
        data: (u) => u == null ? const OnboardingScreen() : const HomeShell(),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: AppColors.brand),
            SizedBox(height: 16),
            Text('MacroVault',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Something went wrong:\n\n$message',
              textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
