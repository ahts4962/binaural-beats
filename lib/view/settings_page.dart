import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../locale.dart';
import '../miscellaneous_app_settings.dart';
import '../theme.dart';

/// Settings page.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// Show color picker dialog and update color if user selects a color.
  Future<bool> _colorPickerDialog() async {
    return ColorPicker(
      color: ref.read(appThemeProvider).color,
      onColorChanged: (color) => ref.read(appThemeProvider.notifier).setColor(color),
      width: 40,
      height: 40,
      borderRadius: 4,
      spacing: 5,
      runSpacing: 5,
      wheelDiameter: 155,
      enableShadesSelection: false,
      heading: Text(
        AppLocalizations.of(context)!.colorPickerTitle,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: false,
        ColorPickerType.bw: false,
        ColorPickerType.custom: false,
        ColorPickerType.wheel: true,
      },
    ).showPickerDialog(
      context,
      constraints: const BoxConstraints(minHeight: 350, minWidth: 320, maxWidth: 320),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsPageTitle),
      ),
      body: ListView(
        children: <Widget>[
          // Language
          ListTile(
            title: Text(l10n.languageSettingLabel),
            trailing: DropdownMenu<Locale>(
              initialSelection: ref.watch(appLocaleProvider),
              requestFocusOnTap: false,
              onSelected: (value) {
                if (value != null) {
                  ref.read(appLocaleProvider.notifier).set(value);
                }
              },
              dropdownMenuEntries: ref.watch(supportedLocalesProvider).map((e) {
                return DropdownMenuEntry<Locale>(
                  value: e,
                  label: languageDisplayStrings[e.languageCode]!,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Theme color
          ListTile(
            title: Text(l10n.themeColorSettingLabel),
            trailing: ColorIndicator(
              width: 44,
              height: 44,
              borderRadius: 4,
              color: ref.watch(appThemeProvider).color,
              onSelectFocus: false,
              onSelect: () async {
                final Color colorBeforeDialog = ref.read(appThemeProvider).color;
                if (!(await _colorPickerDialog())) {
                  ref.read(appThemeProvider.notifier).setColor(colorBeforeDialog);
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          // Theme mode
          ListTile(
            title: Text(l10n.themeModeSettingLabel),
            trailing: DropdownMenu<ThemeMode>(
              key: UniqueKey(),
              initialSelection: ref.watch(appThemeProvider).mode,
              requestFocusOnTap: false,
              onSelected: (value) {
                if (value != null) {
                  ref.read(appThemeProvider.notifier).setMode(value);
                }
              },
              dropdownMenuEntries: <DropdownMenuEntry<ThemeMode>>[
                DropdownMenuEntry<ThemeMode>(
                  value: ThemeMode.light,
                  label: l10n.lightModeLabel,
                ),
                DropdownMenuEntry<ThemeMode>(
                  value: ThemeMode.dark,
                  label: l10n.darkModeLabel,
                ),
                DropdownMenuEntry<ThemeMode>(
                  value: ThemeMode.system,
                  label: l10n.systemThemeModeLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Show tooltips
          ListTile(
            title: Text(l10n.showTooltipsSettingLabel),
            trailing: Switch(
              value: ref.watch(miscellaneousAppSettingsProvider).showTooltips,
              onChanged: (value) {
                ref.read(miscellaneousAppSettingsProvider.notifier).setShowTooltips(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
