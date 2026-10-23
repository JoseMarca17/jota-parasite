import 'package:flutter/material.dart';

enum AppDestination { home, calendar, streaks }

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    required this.selectedDestination,
    required this.onDestinationSelected,
    super.key,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedDestination.index,
      onDestinationSelected: (index) {
        onDestinationSelected(AppDestination.values[index]);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Calendario',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_fire_department_outlined),
          selectedIcon: Icon(Icons.local_fire_department_rounded),
          label: 'Rachas',
        ),
      ],
    );
  }
}
