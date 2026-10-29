import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'app_spacing.dart';

/// Standard page for every feature screen: app bar, safe area, 16px side padding and an
/// optional pull-to-refresh. Pass [children] for a scrolling page, or [body] for anything
/// that manages its own scrolling (lists, tab views).
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.children,
    this.body,
    this.onRefresh,
    this.actions,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
  }) : assert(
         (children == null) != (body == null),
         'Pass either children or body',
       );

  final String title;
  final List<Widget>? children;
  final Widget? body;
  final Future<void> Function()? onRefresh;
  final List<Widget>? actions;

  /// Fixed widget under the app bar (e.g. a TabBar).
  final PreferredSizeWidget? bottom;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    Widget content = body ??
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          children: children!,
        );
    if (onRefresh != null) {
      content = RefreshIndicator(onRefresh: onRefresh!, child: content);
    }
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: false,
        actions: actions,
        bottom: bottom,
        shape: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      body: SafeArea(top: false, child: content),
    );
  }
}
