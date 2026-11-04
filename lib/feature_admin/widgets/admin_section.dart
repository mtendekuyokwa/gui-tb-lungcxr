import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gui_lungcxr/constants/app_sizes.dart';

/// A titled admin card, laid out with the [FCard] style's own padding and
/// title / subtitle text styles so every admin card matches the theme.
class AdminSection extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => FCard(
    builder: (context, style, _) => Padding(
      padding: style.padding,
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: AppSizes.gap8,
        children: [
          Column(
            crossAxisAlignment: .start,
            spacing: AppSizes.gap2,
            children: [
              Text(title, style: style.titleTextStyle),
              if (subtitle case final subtitle?)
                Text(subtitle, style: style.subtitleTextStyle),
            ],
          ),
          ...children,
        ],
      ),
    ),
  );
}
