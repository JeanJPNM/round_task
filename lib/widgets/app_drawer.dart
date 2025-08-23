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
  AppDrawerDestination(icon: Icon(Icons.task_alt), key: "tasks", route: "/"),
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
    int? selectedIndex = appDrawerDestinations.indexWhere(
      (destination) => destination.route == routerState.fullPath,
    );

    if (selectedIndex < 0) selectedIndex = null;

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (value) {
        if (value == selectedIndex) return;
        final destination = appDrawerDestinations[value];
        close(context);

        if (selectedIndex == null) {
          context.go(destination.route);
          return;
        }

        final selected = appDrawerDestinations[selectedIndex];
        if (selected.route == '/') {
          // push other screens on top of the main one
          // makes the back button go back to the main screen
          context.push(destination.route);
        } else if (destination.route == '/') {
          // reset the navigation stack when going back to main screen
          // this allows the user to press the back button to exit the app
          context.go("/");
        } else {
          // use pushReplacement to navigate between other screens
          // also makes the back button go back to the main screen
          context.pushReplacement(destination.route);
        }
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
