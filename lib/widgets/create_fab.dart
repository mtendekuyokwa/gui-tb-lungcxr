import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';
import 'package:gui_lungcxr/constants/strings.dart';

/// Builds the form of a [CreateAction] inside the pop-up panel. The context
/// is the one the FAB was pressed from (so the widget can read the feature's
/// state provider); [onDone] closes the panel.
typedef CreateBuilder = Widget Function(
  BuildContext context,
  VoidCallback onDone,
);

/// One creation flow behind a [CreateFab]: what the menu calls it, its icon,
/// and the form it floats in.
class CreateAction {
  const CreateAction({
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final CreateBuilder builder;
}

/// The floating "create" button for whatever needs making on a screen:
/// several actions open a pop-up menu first, one action goes straight to
/// the form. Either way the form itself floats in as a bottom pop-up, so
/// the page behind stays where it was. [onClose] pops the panel.
class CreateFab extends StatelessWidget {
  const CreateFab({required this.actions, super.key});

  final List<CreateAction> actions;

  /// Opens [action]'s form in the create pop-up, from a FAB or any other
  /// button. Only the close button dismisses it: a stray click outside must
  /// not throw away a half-filled form.
  static void open(BuildContext context, CreateAction action) {
    final panel = Navigator.of(context);
    onClose() => panel.pop();
    // Web-app: a centered card over a scrim on wide screens.
    if (MediaQuery.widthOf(context) >= AppSizes.narrowBreakpoint) {
      showFDialog(
        context: context,
        barrierDismissible: false,
        builder: (_, _, _) => FDialog(
          builder: (dialogContext, style) => _CreatePanel(
            bounded: false,
            title: action.label,
            onClose: onClose,
            child: action.builder(context, onClose),
          ),
        ),
      );
      return;
    }
    showFSheet(
      context: context,
      barrierDismissible: false,
      side: .btt,
      draggable: false,
      builder: (_) => _CreatePanel(
        bounded: true,
        title: action.label,
        onClose: onClose,
        child: action.builder(context, onClose),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.widthOf(context) < AppSizes.narrowBreakpoint;

    // One action skips the menu: the pop-up *is* the form.
    final Widget fab = actions.length == 1
        ? _Fab(onPress: () => open(context, actions.single))
        : FPopoverMenu(
            menuAnchor: .topCenter,
            childAnchor: .bottomCenter,
            menuBuilder: (context, controller, menu) => [
              .group(
                children: [
                  for (final action in actions)
                    .item(
                      prefix: Icon(action.icon, size: AppSizes.icon16),
                      title: Text(action.label),
                      // Closing the menu is async; the panel opening is
                      // not worth waiting for.
                      onPress: () {
                        unawaited(controller.hide());
                        open(context, action);
                      },
                    ),
                ],
              ),
            ],
            builder: (_, controller, _) =>
                _Fab(onPress: () => unawaited(controller.toggle())),
          );

    // The FAB sits a direct child of the workspace's Stack, so Positioned
    // holds it to the bottom-right corner in every branch.
    return Positioned(
      right: AppSizes.gap16,
      bottom: narrow ? AppSizes.fabNarrowInset : AppSizes.gap20,
      child: fab,
    );
  }
}

/// A floating action button in the theme's primary color: a plain circle
/// that lifts from the page.
class _Fab extends StatelessWidget {
  const _Fab({required this.onPress});

  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        label: Strings.create,
        child: GestureDetector(
          onTap: onPress,
          behavior: .opaque,
          child: Container(
            width: AppSizes.fabSize,
            height: AppSizes.fabSize,
            decoration: BoxDecoration(
              shape: .circle,
              color: colors.primary,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                FLucideIcons.plus,
                size: AppSizes.icon24,
                color: colors.primaryForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The panel inside the create pop-up: its title, a close button, and the
/// form. In the bottom sheet (mobile) the form scrolls in a bounded area;
/// in the web modal the card shrink-wraps to its content.
class _CreatePanel extends StatelessWidget {
  const _CreatePanel({
    required this.bounded,
    required this.title,
    required this.onClose,
    required this.child,
  });

  final bool bounded;
  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final form = SingleChildScrollView(child: child);
    final narrow = MediaQuery.widthOf(context) < AppSizes.narrowBreakpoint;
    final body = narrow
        ? form
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.panelMaxWidth,
              ),
              child: form,
            ),
          );

    return Padding(
      padding: const .all(AppSizes.gap16),
      child: Column(
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: .stretch,
        spacing: AppSizes.gap8,
        children: [
          Row(
            spacing: AppSizes.gap8,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: theme.typography.body.md.copyWith(fontWeight: .w600),
                ),
              ),
              FTooltip(
                tipBuilder: (_, _) => const Text(Strings.close),
                child: FButton.icon(
                  variant: .ghost,
                  size: .sm,
                  onPress: onClose,
                  child: const Icon(FLucideIcons.x),
                ),
              ),
            ],
          ),
          bounded ? Expanded(child: body) : body,
        ],
      ),
    );
  }
}
