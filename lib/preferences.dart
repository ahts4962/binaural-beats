import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utils.dart';

part 'preferences.g.dart';

const Set<String> preferenceKeys = {
  'windowLeft',
  'windowTop',
  'windowRight',
  'windowBottom',
  'windowMaximizedLeft',
  'windowMaximizedTop',
  'windowMaximized',
  'appLanguageCode',
  'appThemeColor',
  'appThemeMode',
  'showTooltips',
  'binauralBeatsFrequency',
  'baseFrequency',
  'leftVolume',
  'rightVolume',
  'frequenciesLimited',
  'volumesSynchronized',
};

/// AppPreferences instance cached by Riverpod.
@Riverpod(keepAlive: true)
AppPreferences appPreferences(AppPreferencesRef ref) {
  throw UnimplementedError();
}

/// The class that manages the application preferences.
class AppPreferences {
  final SharedPreferencesWithCache _sharedPreferences;

  /// The debouncers for each preference key.
  final Map<String, Debouncer> _debouncers = {};

  AppPreferences(SharedPreferencesWithCache sharedPreferences)
      : _sharedPreferences = sharedPreferences;

  /// Immediately executes all set operations.
  ///
  /// Returns a [Future] that completes when all set operations are done.
  Future<void> flush() async {
    final List<Future<void>> futures = [];
    for (final debouncer in _debouncers.values) {
      debouncer.flush();
      futures.add(debouncer.future);
    }
    await Future.wait(futures);
  }

  /// Gets the integer value with the specified key.
  ///
  /// If the value is not found or the type is incorrect, returns `null`.
  int? getInt(String key) {
    try {
      return _sharedPreferences.getInt(key);
    } on TypeError {
      return null;
    }
  }

  /// Gets the double value with the specified key.
  ///
  /// If the value is not found or the type is incorrect, returns `null`.
  double? getDouble(String key) {
    try {
      return _sharedPreferences.getDouble(key);
    } on TypeError {
      return null;
    }
  }

  /// Gets the boolean value with the specified key.
  ///
  /// If the value is not found or the type is incorrect, returns `null`.
  bool? getBool(String key) {
    try {
      return _sharedPreferences.getBool(key);
    } on TypeError {
      return null;
    }
  }

  /// Gets the string value with the specified key.
  ///
  /// If the value is not found or the type is incorrect, returns `null`.
  String? getString(String key) {
    try {
      return _sharedPreferences.getString(key);
    } on TypeError {
      return null;
    }
  }

  /// Gets the integer value with the specified key.
  ///
  /// If the value is not found, sets the default value and returns it.
  int getIntWithDefault(String key, int defaultValue) {
    int? value;
    try {
      value = _sharedPreferences.getInt(key);
    } on TypeError {
      setInt(key, defaultValue);
      return defaultValue;
    }
    if (value == null) {
      setInt(key, defaultValue);
      return defaultValue;
    }
    return value;
  }

  /// Gets the double value with the specified key.
  ///
  /// If the value is not found, sets the default value and returns it.
  double getDoubleWithDefault(String key, double defaultValue) {
    double? value;
    try {
      value = _sharedPreferences.getDouble(key);
    } on TypeError {
      setDouble(key, defaultValue);
      return defaultValue;
    }
    if (value == null) {
      setDouble(key, defaultValue);
      return defaultValue;
    }
    return value;
  }

  /// Gets the boolean value with the specified key.
  ///
  /// If the value is not found, sets the default value and returns it.
  bool getBoolWithDefault(String key, bool defaultValue) {
    bool? value;
    try {
      value = _sharedPreferences.getBool(key);
    } on TypeError {
      setBool(key, defaultValue);
      return defaultValue;
    }
    if (value == null) {
      setBool(key, defaultValue);
      return defaultValue;
    }
    return value;
  }

  /// Sets the integer value with the specified key.
  ///
  /// If the value is the same as the current value, does nothing.
  /// This method calls [SharedPreferences.setInt] with debouncing.
  void setInt(String key, int value) {
    bool changed;
    try {
      changed = _sharedPreferences.getInt(key) != value;
    } on TypeError {
      changed = true;
    }
    if (!changed) {
      return;
    }
    final debouncer = _debouncers.putIfAbsent(key, () => Debouncer());
    debouncer.runAsync(() async => await _sharedPreferences.setInt(key, value));
  }

  /// Sets the double value with the specified key.
  ///
  /// If the value is the same as the current value, does nothing.
  /// This method calls [SharedPreferences.setDouble] with debouncing.
  void setDouble(String key, double value) {
    bool changed;
    try {
      changed = _sharedPreferences.getDouble(key) != value;
    } on TypeError {
      changed = true;
    }
    if (!changed) {
      return;
    }
    final debouncer = _debouncers.putIfAbsent(key, () => Debouncer());
    debouncer.runAsync(() async => await _sharedPreferences.setDouble(key, value));
  }

  /// Sets the boolean value with the specified key.
  ///
  /// If the value is the same as the current value, does nothing.
  /// This method calls [SharedPreferences.setBool] with debouncing.
  void setBool(String key, bool value) {
    bool changed;
    try {
      changed = _sharedPreferences.getBool(key) != value;
    } on TypeError {
      changed = true;
    }
    if (!changed) {
      return;
    }
    final debouncer = _debouncers.putIfAbsent(key, () => Debouncer());
    debouncer.runAsync(() async => await _sharedPreferences.setBool(key, value));
  }

  /// Sets the string value with the specified key.
  ///
  /// If the value is the same as the current value, does nothing.
  /// This method calls [SharedPreferences.setString] with debouncing.
  void setString(String key, String value) {
    bool changed;
    try {
      changed = _sharedPreferences.getString(key) != value;
    } on TypeError {
      changed = true;
    }
    if (!changed) {
      return;
    }
    final debouncer = _debouncers.putIfAbsent(key, () => Debouncer());
    debouncer.runAsync(() async => await _sharedPreferences.setString(key, value));
  }
}
