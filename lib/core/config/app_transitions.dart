import 'package:flutter/material.dart';

/// One place that decides how every screen change moves.
///
/// Wired once through [AppTransitions.theme] in `MaterialApp.theme.pageTransitionsTheme`, so every
/// `Navigator.push`, `pushReplacementNamed`, `pushAndRemoveUntil` and named route picks it up with
/// no per-screen code. Change the numbers here and the whole app follows.
///
/// The motion is a short "rise and fade": the new screen fades in while rising ~8% of its height. It only animates opacity and translation, both handled by the compositor without
/// re-laying-out or re-painting the page, and the outgoing screen is left untouched (no
/// `saveLayer`), so it stays smooth on low-end phones.
class AppTransitions {
  AppTransitions._();

  static const Duration duration = Duration(milliseconds: 240);
  static const Duration reverseDuration = Duration(milliseconds: 260);
  /// Screens animate on open only; closing a screen is instant.
  static const Duration routeReverseDuration = Duration.zero;
  static const Duration tabDuration = Duration(milliseconds: 180);
  static const Offset _rise = Offset(0, 0.08);

  /// Pass as `sheetAnimationStyle:` to every `showModalBottomSheet` so sheets share the same timing.
  static const AnimationStyle sheet = AnimationStyle(
    duration: duration,
    reverseDuration: reverseDuration,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  static const PageTransitionsTheme theme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: AppPageTransitionsBuilder(),
      TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
      TargetPlatform.windows: AppPageTransitionsBuilder(),
      TargetPlatform.linux: AppPageTransitionsBuilder(),
      TargetPlatform.macOS: AppPageTransitionsBuilder(),
      TargetPlatform.iOS: AppPageTransitionsBuilder(),
    },
  );
}

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static final Animatable<Offset> _slide = Tween<Offset>(
    begin: AppTransitions._rise,
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  static final Animatable<double> _fade = CurveTween(curve: Curves.easeOut);

  @override
  Duration get transitionDuration => AppTransitions.duration;

  @override
  Duration get reverseTransitionDuration => AppTransitions.routeReverseDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AppPageTransitionsBuilder.wrap(animation, secondaryAnimation, child);
  }

  /// Fade up: the new screen fades in while rising ~8% of its height. The outgoing screen is
  /// left untouched (no extra layer), which keeps it cheap.
  static Widget wrap(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: animation.drive(_fade),
        child: SlideTransition(position: animation.drive(_slide), child: child),
      ),
    );
  }
}

/// Route used for every screen push, so the animation never depends on the platform theme.
/// Use `AppRoute(builder: ...)` wherever you would have used `MaterialPageRoute`.
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({required WidgetBuilder builder, super.settings})
    : super(
        pageBuilder: (context, _, _) => builder(context),
        transitionDuration: AppTransitions.duration,
        reverseTransitionDuration: AppTransitions.routeReverseDuration,
        transitionsBuilder: (context, animation, secondary, child) =>
            AppPageTransitionsBuilder.wrap(animation, secondary, child),
      );
}

/// Fades a freshly selected tab in. Keeps every tab alive (so scroll position and state survive),
/// just restarts a short fade whenever [index] changes.
class TabFade extends StatefulWidget {
  const TabFade({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppTransitions.tabDuration,
    value: 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void didUpdateWidget(TabFade old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(_opacity),
      child: widget.child,
    ),
  );
}
