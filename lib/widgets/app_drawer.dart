import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppDrawerDestination {
  const AppDrawerDestination({
    required this.icon,
    required this.route,
    required this.key,
  });

  final Widget icon;
  final String route;
  final String key;
}

const appDrawerDestinations = [
  AppDrawerDestination(
    icon: Icon(Icons.task_alt),
    key: "tasks",
    route: "/",
  ),
  AppDrawerDestination(
    icon: Icon(Icons.calendar_today),
    route: "/calendar_view",
    key: "calendar_view.title",
  ),
  AppDrawerDestination(
    icon: Icon(Icons.delete),
    key: "trash_bin.title",
    route: "/trash_bin",
  ),
  AppDrawerDestination(
    icon: Icon(Icons.settings),
    key: "settings",
    route: "/settings",
  ),
];

class AppDrawerButton extends StatelessWidget {
  const AppDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return DrawerButton(onPressed: () => AppDrawer.open(context));
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static void open(BuildContext context) {
    context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
  }

  static void close(BuildContext context) {
    context.findRootAncestorStateOfType<ScaffoldState>()?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routerState = GoRouterState.of(context);
    final selectedIndex = appDrawerDestinations.indexWhere(
      (destination) => destination.route == routerState.matchedLocation,
    );
    return NavigationDrawer(
      selectedIndex: selectedIndex >= 0 ? selectedIndex : null,
      onDestinationSelected: (value) {
        if (value == selectedIndex) return;
        final destination = appDrawerDestinations[value];

        close(context);
        context.pushReplacement(destination.route);
      },
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          child: Text(
            context.tr("app_name"),
            style: theme.textTheme.titleSmall,
          ),
        ),
        for (final destination in appDrawerDestinations)
          NavigationDrawerDestination(
            icon: destination.icon,
            label: Text(context.tr(destination.key)),
          ),
      ],
    );
  }
}
