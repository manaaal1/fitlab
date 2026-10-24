import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/style_request.dart';

import '../generator/generator_tab.dart';
import '../item_actions.dart';
import '../saved_outfits/looks_tab.dart';
import '../settings/settings_screen.dart';
import 'wardrobe_tab.dart';

/// Top-level layout: a bottom navigation bar on phones and a navigation
/// rail on wide screens, switching between Wardrobe, Generate and Looks.
class RootShell extends StatefulWidget {
  const RootShell({super.key, this.generatorRevealDelay});

  final Duration? generatorRevealDelay;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.checkroom_outlined, Icons.checkroom_rounded, 'Wardrobe'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Generate'),
    (Icons.bookmarks_outlined, Icons.bookmarks_rounded, 'Looks'),
  ];

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    // "Style this piece" from anywhere jumps to the generator.
    if (context.watch<StyleRequestController>().pending != null &&
        _index != 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 1);
      });
    }

    final body = IndexedStack(
      index: _index,
      children: [
        const WardrobeTab(),
        GeneratorTab(
          revealDelay:
              widget.generatorRevealDelay ?? GeneratorTab.defaultRevealDelay,
        ),
        LooksTab(onGoToGenerator: () => _select(1)),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitLab'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.8,
                  leading: _index == 0
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FloatingActionButton(
                            heroTag: 'add-piece',
                            tooltip: 'Add a piece',
                            elevation: 0,
                            onPressed: () => ItemActions.openEditor(context),
                            child: const Icon(Icons.add_rounded),
                          ),
                        )
                      : null,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.$1),
                        selectedIcon: Icon(d.$2),
                        label: Text(d.$3),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      floatingActionButton: !wide && _index == 0
          ? FloatingActionButton(
              heroTag: 'add-piece',
              tooltip: 'Add a piece',
              onPressed: () => ItemActions.openEditor(context),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: d.$3,
                  ),
              ],
            ),
    );
  }
}
