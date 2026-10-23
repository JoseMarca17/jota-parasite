import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jota_parasite/theme/app_theme.dart';
import 'package:jota_parasite/widgets/roast_mascot_card.dart';

void main() {
  testWidgets('la mascota cambia el roast al tocar la tarjeta', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: RoastMascotCard(mood: MascotMood.neutral)),
      ),
    );

    expect(find.textContaining('¿Vas a mover un dedo hoy'), findsOneWidget);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no se va a completar por contemplación'),
      findsOneWidget,
    );
  });
}
