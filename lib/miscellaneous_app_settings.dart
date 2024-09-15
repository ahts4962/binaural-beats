import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'preferences.dart';

part 'miscellaneous_app_settings.freezed.dart';
part 'miscellaneous_app_settings.g.dart';

/// The state of the miscellaneous app settings.
@freezed
class MiscellaneousAppSettingsState with _$MiscellaneousAppSettingsState {
  const factory MiscellaneousAppSettingsState({
    required bool showTooltips,
  }) = _MiscellaneousAppSettingsState;
}

/// The notifier for the miscellaneous app settings.
@riverpod
class MiscellaneousAppSettings extends _$MiscellaneousAppSettings {
  @override
  MiscellaneousAppSettingsState build() {
    final preferences = ref.watch(appPreferencesProvider);
    final showTooltips = preferences.getBool('showTooltips') ?? true;

    ref.listenSelf((previous, next) {
      preferences.setBool('showTooltips', next.showTooltips);
    });

    ref.onDispose(preferences.flush);

    return MiscellaneousAppSettingsState(showTooltips: showTooltips);
  }

  /// Sets whether tooltips should be shown.
  void setShowTooltips(bool showTooltips) {
    state = state.copyWith(showTooltips: showTooltips);
  }
}
