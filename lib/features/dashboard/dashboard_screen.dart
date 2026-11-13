import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pushtrial/models/user.dart';
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

  late User user;
  late List<Widget> _pages;

  String picurl = '';
  List<SchoolInfo> schoolInfo = [];
  String? pic = '';
  Color schoolColor = const Color(0xFFD71920);

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
      schoolColor = result['schoolColor'];
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
    });
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
        body: SafeArea(
          child: IndexedStack(index: _selectedIndex, children: _pages),
        ),
        bottomNavigationBar: TabNavigation(
          items: _tabs,
          currentIndex: _selectedIndex,
          onChanged: _onItemTapped,
          accent: schoolColor,
        ),
      ),
    );
  }
}
