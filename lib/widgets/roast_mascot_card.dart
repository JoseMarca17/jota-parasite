import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum MascotMood {
  neutral,
  judging,
  angry,
  smirking,
  proud,
}

extension MascotMoodPresentation on MascotMood {
  String get assetPath => 'assets/mascot/$name.png';

  String get badge => switch (this) {
        MascotMood.angry || MascotMood.judging => '¡ALERTA DE ANOMALÍA!',
        _ => 'NIVEL SUPERVIVENCIA',
      };

  String get title => switch (this) {
        MascotMood.neutral => 'ACTIVIDAD SOSPECHOSAMENTE BAJA',
        MascotMood.judging => 'PROCRASTINACIÓN DETECTADA',
        MascotMood.angry => 'COLAPSO DE CONSTANCIA',
        MascotMood.smirking => 'EL MILAGRO DE ÚLTIMA HORA',
        MascotMood.proud => 'ANOMALÍA POSITIVA',
      };

  List<String> get roasts => switch (this) {
        MascotMood.neutral => const [
            '¿Vas a mover un dedo hoy o solo abriste la app por reflejo parasitario?',
            'Tu lista de tareas no se va a completar por contemplación. Aunque sería bonito.',
            'Estoy aquí. Tus ganas de empezar, aparentemente, siguen de camino.',
          ],
        MascotMood.judging => const [
            'Claro, aplázala de nuevo. Mañana mágicamente vas a tener disciplina.',
            'Van dos aplazamientos. A la tercera te damos una medalla de evitación.',
            'La tarea no desaparece cuando apartas la mirada. Ya lo comprobaste, ¿no?',
          ],
        MascotMood.angry => const [
            'Racha en cero. Tu constancia duró menos que una promesa de año nuevo.',
            'Día cero. Ni siquiera me sorprende; eso es lo peor.',
            'Se rompió la racha. Al menos ahora puedes decepcionarme desde el principio.',
          ],
        MascotMood.smirking => const [
            'Completada a última hora. Guarda el champán, no te daremos un premio por hacer lo mínimo.',
            'Llegaste rozando el desastre. Qué forma tan innecesaria de sentirte vivo.',
            'Técnicamente cumpliste. No confundamos eso con una estrategia brillante.',
          ],
        MascotMood.proud => const [
            'Milagro #42: SlothBot está fingiendo un colapso de orgullo. No te acostumbres.',
            'Un día perfecto. Voy a fingir que siempre supe que podías hacerlo.',
            'Racha salvada. Disfruta este raro momento de competencia funcional.',
          ],
      };

  String get fallbackFace => switch (this) {
        MascotMood.neutral => '😐',
        MascotMood.judging => '🙄',
        MascotMood.angry => '😠',
        MascotMood.smirking => '😏',
        MascotMood.proud => '😌',
      };
}

/// Hero reactivo de la mascota. Un toque cambia el roast; [onTap] permite
/// conectar esa interacción con acciones o cambios de estado de la app.
class RoastMascotCard extends StatefulWidget {
  const RoastMascotCard({
    required this.mood,
    this.badge,
    this.title,
    this.quote,
    this.footer,
    this.miracleNumber = 42,
    this.onTap,
    super.key,
  });

  final MascotMood mood;
  final String? badge;
  final String? title;
  final String? quote;
  final String? footer;
  final int miracleNumber;
  final VoidCallback? onTap;

  @override
  State<RoastMascotCard> createState() => _RoastMascotCardState();
}

class _RoastMascotCardState extends State<RoastMascotCard> {
  int _roastIndex = 0;

  @override
  void didUpdateWidget(covariant RoastMascotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) _roastIndex = 0;
  }

  void _handleTap() {
    if (widget.quote == null) {
      setState(() => _roastIndex = (_roastIndex + 1) % widget.mood.roasts.length);
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final mood = widget.mood;
    final quote = widget.quote ?? mood.roasts[_roastIndex];
    final footer = widget.footer ??
        'Criterio de éxito: Muy por debajo del promedio  |  MILAGRO #${widget.miracleNumber}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Ink(
          decoration: AppTheme.heroCardDecoration,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(label: widget.badge ?? mood.badge),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _MascotImage(mood: mood),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title ?? mood.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '“$quote”',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: const Color(0xFFF2EAFB),
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0x33EADAFF)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.lime, size: 16),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        footer,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.touch_app_outlined,
                        color: AppColors.textSecondary, size: 17),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isAlert = label.toUpperCase().contains('ALERTA');
    final color = isAlert ? AppColors.alert : AppColors.lime;
    final textColor = isAlert ? const Color(0xFF7F1D1D) : AppColors.textOnSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
      ),
    );
  }
}

class _MascotImage extends StatelessWidget {
  const _MascotImage({required this.mood});

  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFF1E152A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x55A3FF2E)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        mood.assetPath,
        fit: BoxFit.cover,
        semanticLabel: 'Mascota en estado ${mood.name}',
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(
            mood.fallbackFace,
            style: const TextStyle(fontSize: 52),
          ),
        ),
      ),
    );
  }
}
