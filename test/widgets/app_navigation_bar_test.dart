import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jota_parasite/theme/app_theme.dart';
import 'package:jota_parasite/widgets/app_navigation_bar.dart';

void main() {
  testWidgets('la navegación inferior indica y cambia la sección activa', (
    tester,
  ) async {
    var selected = AppDestination.calendar;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: AppNavigationBar(
              selectedDestination: selected,
              onDestinationSelected: (destination) {
                setState(() => selected = destination);
              },
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppDestination.calendar.index,
    );

    await tester.tap(find.text('Rachas'));
    await tester.pumpAndSettle();

    expect(selected, AppDestination.streaks);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppDestination.streaks.index,
    );
  });
}
