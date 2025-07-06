import 'package:dynamic_color/dynamic_color.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:relative_time/relative_time.dart';
import 'package:round_task/custom_colors.dart';
import 'package:round_task/screens/app_settings.dart';
import 'package:round_task/screens/task_queue.dart';
import 'package:round_task/screens/task_view.dart';
import 'package:round_task/widgets/second_tick_provider.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: "/",
      pageBuilder: (context, state) => _buildPage(
        context,
        state,
        child: const TaskQueueScreen(),
      ),
    ),
    GoRoute(
      path: "/task",
      pageBuilder: (context, state) {
        return _buildPage(
          context,
          state,
          child: TaskViewScreen(params: state.extra as TaskViewParams),
        );
      },
    ),
    GoRoute(
      path: "/settings",
      pageBuilder: (context, state) => _buildPage(
        context,
        state,
        child: const AppSettings(),
      ),
    ),
  ],
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  await EasyLocalization.ensureInitialized();
  runApp(ProviderScope(
    child: EasyLocalization(
      supportedLocales: const [
        Locale("en", "US"),
        Locale("pt", "BR"),
      ],
      fallbackLocale: const Locale("en", "US"),
      path: "assets/translations",
      assetLoader: const YamlAssetLoader(),
      child: const SecondTickProvider(child: MyApp()),
    ),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final ColorScheme lightScheme, darkScheme;
        if (lightDynamic != null && darkDynamic != null) {
          lightScheme = lightDynamic.harmonized();
          darkScheme = darkDynamic.harmonized();
        } else {
          lightScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
          darkScheme = ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          );
        }

        final lightCustomColors = CustomColors.light.harmonized(lightScheme);
        final darkCustomColors = CustomColors.dark.harmonized(darkScheme);

        final pageTransitionsTheme = PageTransitionsTheme(builders: {
          for (final platform in TargetPlatform.values)
            platform: const FadeForwardsPageTransitionsBuilder(),
        });

        return MaterialApp.router(
          routerConfig: _router,
          title: 'Round Task',
          themeMode: ThemeMode.system,
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
            pageTransitionsTheme: pageTransitionsTheme,
            extensions: [lightCustomColors],
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
            pageTransitionsTheme: pageTransitionsTheme,
            extensions: [darkCustomColors],
          ),
          localizationsDelegates: context.localizationDelegates
              .followedBy([RelativeTimeLocalizations.delegate]),
          supportedLocales: context.supportedLocales,
          locale: context.locale,
        );
      },
    );
  }
}

class _OverlayAnnotations extends StatelessWidget {
  const _OverlayAnnotations({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: theme.colorScheme.surfaceContainer,
        statusBarBrightness: theme.brightness.opposite,
        statusBarIconBrightness: theme.brightness.opposite,
        systemNavigationBarIconBrightness: theme.brightness.opposite,
      ),
      child: child,
    );
  }
}

Page<dynamic> _buildPage(
  BuildContext context,
  GoRouterState state, {
  required Widget child,
}) {
  return MaterialPage<dynamic>(
    key: state.pageKey,
    child: _OverlayAnnotations(child: child),
  );
}
