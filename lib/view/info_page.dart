import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tone_generator.dart';

/// Info page.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.infoPageTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => const _DeviceInfoDialog(),
                ),
                child: Text(l10n.deviceInfoLabel),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => showAboutDialog(
                  context: context,
                  applicationName: 'Binaural Beats',
                  applicationVersion: '1.0.0',
                  applicationIcon: Image.asset('assets/app_icon.png', width: 36, height: 36),
                ),
                child: Text(l10n.aboutDialogButtonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dialog that shows the audio device information.
class _DeviceInfoDialog extends ConsumerStatefulWidget {
  const _DeviceInfoDialog();

  @override
  ConsumerState<_DeviceInfoDialog> createState() => _InfoDialogState();
}

class _InfoDialogState extends ConsumerState<_DeviceInfoDialog> {
  late final Future<String> _deviceInfo;

  @override
  initState() {
    super.initState();
    _deviceInfo = ref.read(toneGeneratorProvider).getAudioDeviceInfo();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      l10n.deviceInfoLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder(
                      future: _deviceInfo,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return Text(
                            snapshot.data ?? l10n.deviceInfoError,
                            textAlign: TextAlign.center,
                          );
                        } else {
                          return const CircularProgressIndicator();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
