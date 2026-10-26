import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';

/// One bottom tab of a narrow-screen layout.
class NarrowTab {
  const NarrowTab({required this.label, required this.icon, required this.page});

  final String label;
  final IconData icon;
  final Widget page;
}

/// Single-column layout for screens under [AppSizes.narrowBreakpoint]:
/// the selected page on top, a tab bar pinned to the bottom.
class NarrowTabs extends StatefulWidget {
  const new({required this.tabs, super.key});

  final List<NarrowTab> tabs;

  @override
  State<NarrowTabs> createState() => _NarrowTabsState();
}

class _NarrowTabsState extends State<NarrowTabs> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [for (final tab in widget.tabs) tab.page],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.background,
            border: Border(
              top: BorderSide(color: theme.colors.border),
            ),
          ),
          child: Padding(
            padding: const .all(AppSizes.gap8),
            child: Row(
              spacing: AppSizes.gap6,
              children: [
                for (var i = 0; i < widget.tabs.length; i++)
                  Expanded(
                    child: FButton(
                      variant: _index == i ? .secondary : .ghost,
                      size: .sm,
                      onPress: () => setState(() => _index = i),
                      prefix: Icon(widget.tabs[i].icon),
                      child: Flexible(
                        child: Text(
                          widget.tabs[i].label,
                          overflow: .ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
