import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';

/// One bottom tab of a narrow-screen layout.
class NarrowTab {
  const NarrowTab({
    required this.label,
    required this.icon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final Widget page;
}

/// Single-column layout for screens under [AppSizes.narrowBreakpoint]:
/// the selected page on top, a tab bar pinned to the bottom. Either owned
/// (it remembers the index itself) or controlled: when [index] is given,
/// [onChanged] must report every tab press so a parent can, say, move the
/// admin from the dashboard tiles to the case list.
class NarrowTabs extends StatefulWidget {
  const new({required this.tabs, this.index, this.onChanged, super.key});

  final List<NarrowTab> tabs;

  /// The selected tab when the parent controls it; null when NarrowTabs
  /// keeps its own.
  final int? index;

  /// Called on every tab press in controlled mode.
  final ValueChanged<int>? onChanged;

  @override
  State<NarrowTabs> createState() => _NarrowTabsState();
}

class _NarrowTabsState extends State<NarrowTabs> {
  var _index = 0;

  bool get _controlled => widget.index != null;

  int get _current => _controlled ? widget.index! : _index;

  void _select(int i) {
    if (_controlled) {
      widget.onChanged?.call(i);
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Expanded(
          child: IndexedStack(
            index: _current,
            children: [for (final tab in widget.tabs) tab.page],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.background,
            border: Border(top: BorderSide(color: theme.colors.border)),
          ),
          child: Padding(
            padding: const .all(AppSizes.gap8),
            child: Row(
              spacing: AppSizes.gap6,
              children: [
                for (var i = 0; i < widget.tabs.length; i++)
                  Expanded(
                    child: FButton(
                      variant: _current == i ? .secondary : .ghost,
                      size: .sm,
                      onPress: () => _select(i),
                      prefix: Icon(widget.tabs[i].icon),
                      child: Flexible(
                        child: Text(widget.tabs[i].label, overflow: .ellipsis),
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
