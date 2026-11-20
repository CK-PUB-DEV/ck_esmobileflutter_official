import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/core/config/app_transitions.dart';
import 'package:pushtrial/core/services/firebase_push.dart';
import 'package:pushtrial/core/services/school_alerts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pushtrial/features/home/home_screen.dart';
import 'package:pushtrial/features/calendar/school_calendar_screen.dart';
import 'package:pushtrial/features/tap_history/tap_history_screen.dart';
import 'package:pushtrial/features/profile/profile_screen.dart';
import 'dart:async';
import 'package:pushtrial/shared/utils/school_utils.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';
import 'package:pushtrial/shared/widgets/navigation/tab_navigation.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  static const _tabs = [
    TabNavItem(icon: LucideIcons.house, label: 'Home'),
    TabNavItem(icon: LucideIcons.badgeCheck, label: 'Tap history'),
    TabNavItem(icon: LucideIcons.calendarDays, label: 'Calendar'),
    TabNavItem(icon: LucideIcons.user, label: 'Profile'),
  ];
  int _selectedIndex = 0;

  /// True while the footer is folded to icons only (the page is scrolling down).
  bool _navCollapsed = false;
  double _scrollTravel = 0;

  late User user;
  late List<Widget> _pages;

  String picurl = '';
  List<SchoolInfo> schoolInfo = [];
  String? pic = '';
  /// Null until the school's colour is known; the tab bar then uses the theme colour.
  Color? schoolColor = SchoolUtils.lastColor;

  @override
  void initState() {
    super.initState();
    user = widget.user;

    _pages = [
      HomeScreen(user: user),
      const TapHistoryScreen(),
      const SchoolCalendar(),
      ProfileScreen(user: user),
    ];

    _initializeData();
    // The first alerts check learns whether this school's server has app alerts. Then Firebase push
    // follows it: off where the app's own alerts work (no duplicates), on where the server is old.
    SchoolAlerts.onLoggedIn().whenComplete(FirebasePush.reconcile);
  }

  Future<void> _initializeData() async {
    await _loadSchoolInfo();
    await _loadSelectedSchool();
  }

  Future<void> _loadSchoolInfo() async {
    final result = await SchoolUtils.getSchoolInfoData();
    setState(() {
      final color = result['schoolColor'];
      if (color is Color && color.a > 0) schoolColor = color;
      picurl = result['picurl'];
      schoolInfo = result['schoolInfo'];
    });
  }

  Future<void> _loadSelectedSchool() async {
    pic = await SchoolUtils.loadSelectedSchool();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // A new tab opens at its top, so the footer is full again.
      _navCollapsed = false;
      _scrollTravel = 0;
    });
  }

  void _setNavCollapsed(bool value) {
    if (_navCollapsed == value) return;
    setState(() => _navCollapsed = value);
  }

  /// Folds the footer when the page scrolls down and restores it on the way back up, like the
  /// Instagram tab bar. Scroll notifications from any tab's list bubble up to here.
  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final pixels = metrics.pixels;

      // At the top the footer is always full; ignore the elastic bounce past either end.
      if (pixels <= metrics.minScrollExtent + 8) {
        _scrollTravel = 0;
        _setNavCollapsed(false);
        return false;
      }
      if (pixels >= metrics.maxScrollExtent) return false;
      // A page that barely scrolls does not need the footer out of the way.
      if (metrics.maxScrollExtent < 96) return false;

      // Count travel in one direction; reverse and the count starts over.
      if (delta != 0 && delta.sign != _scrollTravel.sign) _scrollTravel = 0;
      _scrollTravel += delta;
      if (_scrollTravel > 16) {
        _setNavCollapsed(true);
      } else if (_scrollTravel < -12) {
        _setNavCollapsed(false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final shad = theme.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: shad.background,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
      child: Scaffold(
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          // top: false - each tab's header draws its own colour behind the status bar / island.
          child: SafeArea(
            top: false,
            bottom: false,
            child: TabFade(
              index: _selectedIndex,
              child: IndexedStack(index: _selectedIndex, children: _pages),
            ),
          ),
        ),
        bottomNavigationBar: TabNavigation(
          items: _tabs,
          currentIndex: _selectedIndex,
          onChanged: _onItemTapped,
          accent: schoolColor,
          collapsed: _navCollapsed,
        ),
      ),
    );
  }
}
