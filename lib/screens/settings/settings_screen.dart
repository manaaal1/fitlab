import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../data/backup/backup_service.dart';
import '../../providers/outfits_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../widgets/signature_footer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear everything?'),
        content: const Text(
          'This removes every piece, photo and saved look. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final outfits = context.read<OutfitsProvider>();
    await context.read<WardrobeProvider>().clearAll();
    await outfits.load();
    messenger.showSnackBar(
      const SnackBar(content: Text('Your wardrobe is a fresh start ✷')),
    );
  }

  Future<void> _backUp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final backup = context.read<BackupService>();
    try {
      final info = await PackageInfo.fromPlatform();
      final now = DateTime.now();
      final bytes = await backup.export(appVersion: info.version, now: now);
      final saved = await FilePicker.saveFile(
        fileName: BackupService.fileName(now),
        bytes: bytes,
        mimeType: 'application/zip',
        dialogTitle: 'Save FitLab backup',
      );
      if (saved == null) return; // cancelled
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup saved ♡ keep it somewhere safe.')),
      );
    } catch (e) {
      debugPrint('Backup failed: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not create the backup.')),
      );
    }
  }

  Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final backup = context.read<BackupService>();
    final wardrobe = context.read<WardrobeProvider>();
    final outfits = context.read<OutfitsProvider>();

    final picked = await FilePicker.pickFile(dialogTitle: 'Choose a backup');
    if (picked == null || !context.mounted) return;

    try {
      final bytes = await picked.readAsBytes();
      final manifest = backup.inspect(bytes);
      if (!context.mounted) return;

      final when = DateTime.tryParse('${manifest['exportedAt']}');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore this backup?'),
          content: Text(
            'It has ${manifest['pieces']} pieces and ${manifest['looks']} '
            'saved looks'
            '${when == null ? '' : ', from ${DateFormat.yMMMd().format(when)}'}'
            '.\n\nYour current wardrobe will be replaced.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final summary = await backup.restore(bytes);
      wardrobe.clearFilters();
      await wardrobe.load();
      await outfits.load();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restored ${summary.pieces} pieces and ${summary.looks} looks ✷',
          ),
        ),
      );
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('Restore failed: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read that file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _Header('Appearance'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.wb_sunny_rounded),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.nightlight_round),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => settings.setThemeMode(s.first),
                ),
              ),
              const SizedBox(height: 16),
              _Header('Data'),
              ListTile(
                leading: const Icon(Icons.save_alt_rounded),
                title: const Text('Back up wardrobe'),
                subtitle: const Text('Save pieces, photos and looks to a file'),
                onTap: () => _backUp(context),
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore_rounded),
                title: const Text('Restore from backup'),
                subtitle: const Text('Replaces your current wardrobe'),
                onTap: () => _restore(context),
              ),
              ListTile(
                leading: const Icon(Icons.replay_rounded),
                title: const Text('Replay the intro'),
                onTap: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  settings.resetOnboarding();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_sweep_outlined,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Clear wardrobe',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text('Remove all pieces and saved looks'),
                onTap: () => _confirmClear(context),
              ),
              const SizedBox(height: 16),
              _Header('About'),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) => ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('FitLab'),
                  subtitle: Text(
                    snap.hasData
                        ? 'Version ${snap.data!.version} (${snap.data!.buildNumber})'
                        : 'Version …',
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open source licences'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'FitLab',
                ),
              ),
              const SignatureFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
