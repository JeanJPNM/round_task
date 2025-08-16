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
import 'package:round_task/db/database.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/screens/app_settings.dart';
import 'package:round_task/screens/calendar_view.dart';
import 'package:round_task/screens/task_queue.dart';
import 'package:round_task/screens/task_time_measurements.dart';
import 'package:round_task/screens/task_view.dart';
import 'package:round_task/widgets/second_tick_provider.dart';
import 'package:round_task/widgets/time_tracking_banner.dart';

final _router = GoRouter(
  routes: [
    ShellRoute(builder: _buildShell, routes: [
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
          final child = switch (state.extra) {
            TaskViewParams params => TaskViewScreen(params: params),
            LazyTaskViewParams params => LazyTaskViewScreen(params: params),
            _ => const Scaffold(
                body: Center(
                  child: Text("Invalid task page parameter"),
                ),
              ),
          };
          return _buildPage(
            context,
            state,
            child: child,
          );
        },
        routes: [
          GoRoute(
              path: "measurements",
              pageBuilder: (context, state) {
                return _buildPage(
                  context,
                  state,
                  child: TaskTimeMeasurements(
                    params: state.extra as TaskTimeMeasurementsParams,
                  ),
                );
              }),
        ],
      ),
      GoRoute(
        path: "/settings",
        pageBuilder: (context, state) => _buildPage(
          context,
          state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: "/calendar_view",
        pageBuilder: (context, state) => _buildPage(
          context,
          state,
          child: const CalendarViewScreen(),
        ),
      ),
    ]),
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedColor = ref.watch(
        appSettingsPod.select((settings) => settings.valueOrNull?.seedColor));
    final appBrightness = ref.watch(
        appSettingsPod.select((settings) => settings.valueOrNull?.brightness));
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final ColorScheme lightScheme, darkScheme;
        if (seedColor != null) {
          lightScheme = ColorScheme.fromSeed(seedColor: seedColor);
          darkScheme = ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.dark,
          );
        } else if (lightDynamic != null && darkDynamic != null) {
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
          themeMode: switch (appBrightness) {
            AppBrightness.light => ThemeMode.light,
            AppBrightness.dark => ThemeMode.dark,
            _ => ThemeMode.system,
          },
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

Widget _buildShell(BuildContext context, GoRouterState state, Widget child) {
  return _OverlayAnnotations(
    child: TimeTrackingBannerShell(
      // same values as the FadeForwardsPageTransitionsBuilder
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubicEmphasized,
      isDisabled: (trackedTaskId) {
        if (state.fullPath == '/calendar_view') {
          return true;
        }

        final taskId = switch (state.extra) {
          TaskViewParams(:final task?) => task.id,
          LazyTaskViewParams(:final taskId) => taskId,
          TaskTimeMeasurementsParams(:final task) => task.id,
          _ => null
        };

        return taskId == trackedTaskId;
      },
      child: child,
    ),
  );
}
