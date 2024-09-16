import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'view/main_page.dart';
import 'locale.dart';
import 'miscellaneous_app_settings.dart';
import 'preferences.dart';
import 'theme.dart';
import 'window_management.dart';

/// Entry point of the application.
Future<void> main() async {
  final sharedPreferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(allowList: preferenceKeys),
  );
  final preferences = AppPreferences(sharedPreferences);

  if (Platform.isWindows) {
    WidgetsFlutterBinding.ensureInitialized();
    initializeWindow(preferences);
  }

  runApp(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TooltipVisibility(
      visible: ref.watch(miscellaneousAppSettingsProvider).showTooltips,
      child: MaterialApp(
        title: 'Binaural Beats',
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: ref.watch(supportedLocalesProvider),
        locale: ref.watch(appLocaleProvider),
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: ref.watch(appThemeProvider).color,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: ref.watch(appThemeProvider).color,
          brightness: Brightness.dark,
        ),
        themeMode: ref.watch(appThemeProvider).mode,
        home: const Scaffold(
          body: MainPage(),
        ),
      ),
    );
  }
}
