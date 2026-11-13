import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:pushtrial/shared/widgets/ui/app_spacing.dart';

/// Standard page for every feature screen: app bar, safe area, 16px side padding and an
/// optional pull-to-refresh. Pass [children] for a scrolling page, or [body] for anything
/// that manages its own scrolling (lists, tab views).
///
/// Two header styles live here, so no screen builds its own app bar:
///  * `AppPage(...)`      – inner screen: small title, back arrow when it was pushed.
///  * `AppPage.root(...)` – dashboard tab (Home, Tap history, Calendar, Profile): large title,
///    never a back arrow.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    this.children,
    this.body,
    this.onRefresh,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
  }) : isRoot = false,
       assert(
         (children == null) != (body == null),
         'Pass either children or body',
       );

  const AppPage.root({
    super.key,
    required this.title,
    this.children,
    this.body,
    this.onRefresh,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
  }) : isRoot = true,
       assert(
         (children == null) != (body == null),
         'Pass either children or body',
       );

  /// Dashboard tab: large title and no back button.
  final bool isRoot;

  final String title;
  final List<Widget>? children;
  final Widget? body;
  final Future<void> Function()? onRefresh;
  final List<Widget>? actions;

  /// Fixed widget under the app bar (e.g. a TabBar).
  final PreferredSizeWidget? bottom;
  final EdgeInsetsGeometry padding;

  /// Tinted page background (e.g. the school wash). When set, the app bar is transparent and
  /// borderless so the rounded cards below float on the tint.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    // The page runs to the bottom edge, so it can scroll behind a floating footer. Its own list
    // keeps clear of the system inset (and of the footer, which raises that inset) instead.
    final resolved = padding.resolve(Directionality.of(context));
    Widget content =
        body ??
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: resolved.copyWith(
            bottom: resolved.bottom + MediaQuery.paddingOf(context).bottom,
          ),
          children: children!,
        );
    if (onRefresh != null) {
      content = RefreshIndicator(onRefresh: onRefresh!, child: content);
    }
    return Scaffold(
      backgroundColor: backgroundColor ?? theme.colorScheme.background,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: false,
        automaticallyImplyLeading: !isRoot,
        titleTextStyle: isRoot
            ? theme.textTheme.h3.copyWith(color: theme.colorScheme.foreground)
            : null,
        toolbarHeight: isRoot ? 68 : null,
        actions: actions == null || !isRoot ? actions : [...actions!, Gap.wSm],
        bottom: bottom,
        backgroundColor: backgroundColor == null ? null : Colors.transparent,
        scrolledUnderElevation: backgroundColor == null ? null : 0,
        shape: backgroundColor == null
            ? Border(bottom: BorderSide(color: theme.colorScheme.border))
            : null,
      ),
      body: SafeArea(top: false, bottom: body != null, child: content),
    );
  }
}
