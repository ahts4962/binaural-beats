import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'preferences.dart';

part 'theme.freezed.dart';
part 'theme.g.dart';

/// The state of the app theme.
@freezed
class AppThemeState with _$AppThemeState {
  const factory AppThemeState({
    required Color color,
    required ThemeMode mode,
  }) = _AppThemeState;
}

/// The notifier for the app theme.
@riverpod
class AppTheme extends _$AppTheme {
  @override
  AppThemeState build() {
    final preferences = ref.watch(appPreferencesProvider);
    final color = Color(preferences.getInt('appThemeColor') ?? Colors.blue.value);
    var themeModeIndex = preferences.getInt('appThemeMode') ?? ThemeMode.system.index;
    if (themeModeIndex < 0 || themeModeIndex >= ThemeMode.values.length) {
      themeModeIndex = ThemeMode.system.index;
    }
    final themeMode = ThemeMode.values[themeModeIndex];

    ref.listenSelf((previous, next) {
      preferences.setInt('appThemeColor', next.color.value);
      preferences.setInt('appThemeMode', next.mode.index);
    });

    ref.onDispose(preferences.flush);

    return AppThemeState(color: color, mode: themeMode);
  }

  /// Sets the color of the theme.
  void setColor(Color color) {
    state = state.copyWith(color: color);
  }

  /// Sets the theme mode.
  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
  }
}
