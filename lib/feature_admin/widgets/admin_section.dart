import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';

/// A titled card in the admin's side panel.
class AdminSection extends StatelessWidget {
  const new({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => FCard(
    child: Padding(
      padding: const .all(AppSizes.gap16),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: AppSizes.gap8,
        children: [
          Text(
            title,
            style: context.theme.typography.body.sm.copyWith(fontWeight: .w600),
          ),
          ...children,
        ],
      ),
    ),
  );
}
