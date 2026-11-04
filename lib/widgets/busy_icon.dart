import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// A button's prefix icon that turns into a small spinner while the
/// button's async task runs, so every slow action shows it is working.
class BusyIcon extends StatelessWidget {
  const BusyIcon({required this.busy, required this.icon, super.key});

  final bool busy;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      busy ? const FCircularProgress(size: .sm) : Icon(icon);
}
