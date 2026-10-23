import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'features/auth/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseConfig.validate();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const JotaParasiteApp());
}

class JotaParasiteApp extends StatelessWidget {
  const JotaParasiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jota Parasite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AuthGate(client: Supabase.instance.client),
    );
  }
}
