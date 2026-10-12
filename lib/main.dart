import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'widgets/roast_mascot_card.dart';

void main() {
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
      home: const StageOnePreviewPage(),
    );
  }
}

/// Pantalla mínima para ejecutar y revisar el sistema visual de la Etapa 1.
class StageOnePreviewPage extends StatefulWidget {
  const StageOnePreviewPage({super.key});

  @override
  State<StageOnePreviewPage> createState() => _StageOnePreviewPageState();
}

class _StageOnePreviewPageState extends State<StageOnePreviewPage> {
  MascotMood _mood = MascotMood.neutral;

  void _cycleMood() {
    final moods = MascotMood.values;
    setState(() => _mood = moods[(moods.indexOf(_mood) + 1) % moods.length]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jota Parasite'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PROTOCOLO DE SUPERVIVENCIA',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.lime,
                            letterSpacing: 1.3,
                          )),
                  const SizedBox(height: 8),
                  Text('Tu productividad, bajo vigilancia.',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  RoastMascotCard(
                    mood: _mood,
                    miracleNumber: 42,
                    onTap: _cycleMood,
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Toca la tarjeta para comprobar el siguiente estado',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
