import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/services/firebase_push.dart';
import 'package:pushtrial/services/school_alerts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'home.dart';
import 'school_calendar.dart';
import 'taphistory.dart';
import 'profile.dart';
import 'dart:async';
import '../widgets/school_utils.dart';
import '../models/school_info.dart';
import '../widgets/ui/ui.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
    const labels = ['Home', 'Tap history', 'Calendar', 'Profile'];

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
        bottomNavigationBar: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: shad.background,
              border: Border(top: BorderSide(color: shad.border)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              child: Row(
                children: List.generate(4, (index) {
                  final selected = index == _selectedIndex;
                  final foreground = selected
                      ? shad.primary
                      : shad.mutedForeground;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: labels[index],
                        child: ShadButton.ghost(
                          onPressed: () => _onItemTapped(index),
                          width: double.infinity,
                          height: 56,
                          padding: EdgeInsets.zero,
                          backgroundColor: selected
                              ? shad.accent
                              : Colors.transparent,
                          foregroundColor: foreground,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getIcon(index),
                                size: IconSize.nav,
                                color: foreground,
                              ),
                              Gap.hXs,
                              Text(
                                labels[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.small.copyWith(
                                  color: foreground,
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return LucideIcons.house;
      case 1:
        return LucideIcons.badgeCheck;
      case 2:
        return LucideIcons.calendarDays;
      case 3:
        return LucideIcons.user;
      default:
        return LucideIcons.house;
    }
  }
}
