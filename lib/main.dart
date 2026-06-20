import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/app.dart';
import 'package:macrovault/state/app_services.dart';
import 'package:macrovault/state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the encrypted DB and assemble services before the first frame.
  final services = await AppServices.bootstrap();

  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const MacroVaultApp(),
    ),
  );
}
