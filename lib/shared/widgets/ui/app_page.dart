import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:pushtrial/shared/utils/school_utils.dart';
import 'package:pushtrial/shared/widgets/ui/app_spacing.dart';
import 'package:pushtrial/shared/widgets/ui/app_tokens.dart';
import 'package:pushtrial/shared/widgets/ui/school_surface.dart';

/// Standard page for every feature screen: app bar, safe area, 16px side padding and an
/// optional pull-to-refresh. Pass [children] for a scrolling page, or [body] for anything
/// that manages its own scrolling (lists, tab views).
///
/// Two header styles live here, so no screen builds its own app bar:
///  * `AppPage(...)`      - inner screen: round back button and a medium title.
///  * `AppPage.root(...)` - dashboard tab (Home, Tap history, Calendar, Profile): title,
///    never a back button.
///
/// The header is edge to edge: its colour starts at the very top of the screen, behind the status
/// bar, notch or Dynamic Island, and the title sits below that inset. So the area above the
/// island always matches the header, on any phone. At rest it is flat; once the page scrolls the
/// header turns into a white surface with rounded bottom corners and a soft shadow, so the
/// content visibly passes beneath it.
class AppPage extends StatefulWidget {
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

  /// Trailing header widgets (e.g. icon buttons).
  final List<Widget>? actions;

  /// Fixed widget under the title (e.g. a TabBar).
  final PreferredSizeWidget? bottom;
  final EdgeInsetsGeometry padding;

  /// Page and header colour. Defaults to the logged-in school's tint (see [SchoolUtils]).
  final Color? backgroundColor;

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  // A notifier instead of setState: scrolling only rebuilds the header, never the page content.
  final ValueNotifier<bool> _lifted = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _lifted.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    // A small dead zone (lift past 8px, drop under 2px) so the header does not flicker at the edge.
    final p = n.metrics.pixels;
    if (!_lifted.value && p > 8) _lifted.value = true;
    if (_lifted.value && p < 2) _lifted.value = false;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    // No page sets its own colour: the tint comes from the logged-in school (SchoolUtils), and
    // pages fall back to the plain theme background until that is known.
    final school = SchoolUtils.lastColor;
    final bg =
        widget.backgroundColor ??
        (school == null
            ? scheme.background
            : SchoolTone(context, school).background);
    final isDark = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;
    final top = MediaQuery.paddingOf(context).top;
    final showBack = !widget.isRoot && Navigator.canPop(context);

    // The page runs to the bottom edge, so it can scroll behind a floating footer. Its own list
    // keeps clear of the system inset (and of the footer, which raises that inset) instead.
    final resolved = widget.padding.resolve(Directionality.of(context));
    Widget content =
        widget.body ??
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: resolved.copyWith(
            bottom: resolved.bottom + MediaQuery.paddingOf(context).bottom,
          ),
          children: widget.children!,
        );
    if (widget.onRefresh != null) {
      content = RefreshIndicator(onRefresh: widget.onRefresh!, child: content);
    }

    // Same title size on every header, with or without a back button.
    final titleStyle = theme.textTheme.h4.copyWith(color: scheme.foreground);

    final duration = AppMotion.of(context);

    // The row never changes while scrolling, so it is built once and handed to the builder.
    final headerRow = Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Row(
                children: [
                  if (showBack) ...[
                    _BackButton(onTap: () => Navigator.maybePop(context)),
                    Gap.wSm,
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  if (widget.actions != null) ...widget.actions!,
                ],
              ),
            ),
          ),
          if (widget.bottom != null) widget.bottom!,
        ],
      ),
    );

    // At rest the header is flat and the same colour as the page. Once the content scrolls under
    // it, it becomes a white surface with rounded bottom corners and a soft shadow.
    final header = RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: _lifted,
        child: headerRow,
        builder: (context, lifted, child) => AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: lifted ? scheme.card : bg,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(lifted ? AppRadius.header : 0),
            ),
            boxShadow: lifted
                ? AppShadow.lifted(isDark)
                : const [],
          ),
          child: child,
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Transparent status bar so the header colour shows through above the island, with icons
      // that stay readable on it.
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            header,
            Expanded(
              // The header already covers the top inset; a dashboard tab keeps running to the
              // bottom edge, a pushed screen with a custom body keeps clear of the system bar.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: SafeArea(
                    top: false,
                    bottom: widget.body != null && !widget.isRoot,
                    child: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round white back button (44px target) with a soft shadow.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      excludeSemantics: true,
      // The circle stays 44px; the tappable area around it is 48px.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: kTapTarget,
          height: kTapTarget,
          child: Center(
            child: SizedBox(
              width: kMinTap,
              height: kMinTap,
              child: RoundedCard(
                radius: AppRadius.pill,
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                child: Icon(
                  LucideIcons.chevronLeft,
                  size: 24,
                  color: ShadTheme.of(context).colorScheme.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
