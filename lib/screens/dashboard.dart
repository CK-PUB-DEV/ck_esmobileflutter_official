import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/schools/models/schools.dart';
import 'home.dart';
import 'school_calendar.dart';
import 'taphistory.dart';
import 'profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/login.dart';
import 'package:pushtrial/models/user_login.dart';
import 'dart:convert';
import 'dart:async';
import '../widgets/school_utils.dart';
import '../models/school_info.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  DashboardScreen({required this.user});

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
  Color schoolColor = const Color(0xFF1D1D1D);

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
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / 4;
    final circleSize = 50.0;
    // BottomNavigationBar grows by the system navigation bar's height (edge-to-edge on
    // Android 15+), so the selected-item circle has to rise by the same amount to stay in the notch.
    final systemNavBarHeight = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // No AppBar on this screen, so nothing else sets the status bar style: keep its icons dark.
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
      extendBody: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: IndexedStack(index: _selectedIndex, children: _pages),
        ),
      ),

      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: ClipPath(
              clipper: CurvedNavBarClipper(
                selectedIndex: _selectedIndex,
                totalItems: 4,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1D1D1D),
                  boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  color: Colors.transparent,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      splashFactory: NoSplash.splashFactory,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                    ),
                    child: BottomNavigationBar(
                      currentIndex: _selectedIndex,
                      onTap: _onItemTapped,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      type: BottomNavigationBarType.fixed,
                      selectedItemColor: schoolColor,
                      unselectedItemColor: Colors.grey,
                      showSelectedLabels: false,
                      showUnselectedLabels: false,
                      items: [
                        BottomNavigationBarItem(
                          icon: _selectedIndex == 0
                              ? const SizedBox.shrink()
                              : const Icon(Icons.home_outlined),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: _selectedIndex == 1
                              ? const SizedBox.shrink()
                              : const Icon(Icons.sensor_occupied_outlined),
                          label: 'Tap',
                        ),
                        BottomNavigationBarItem(
                          icon: _selectedIndex == 2
                              ? const SizedBox.shrink()
                              : const Icon(Icons.calendar_month_outlined),
                          label: 'Calendar',
                        ),
                        BottomNavigationBarItem(
                          icon: _selectedIndex == 3
                              ? const SizedBox.shrink()
                              : const Icon(Icons.person),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: 30 + systemNavBarHeight,
            left: itemWidth * _selectedIndex + (itemWidth - circleSize) / 2,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: schoolColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    _getIcon(_selectedIndex),
                    key: ValueKey<int>(_selectedIndex),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home_outlined;
      case 1:
        return Icons.sensor_occupied_outlined;
      case 2:
        return Icons.calendar_month_outlined;
      case 3:
        return Icons.person;
      default:
        return Icons.home_outlined;
    }
  }
}

class CurvedNavBarClipper extends CustomClipper<Path> {
  final int selectedIndex;
  final int totalItems;

  CurvedNavBarClipper({required this.selectedIndex, required this.totalItems});

  @override
  Path getClip(Size size) {
    double width = size.width;
    double itemWidth = width / totalItems;
    double centerX = itemWidth * selectedIndex + itemWidth / 2;
    double radius = 40;

    Path path = Path();
    path.lineTo(centerX - radius - 10, 0);
    path.quadraticBezierTo(centerX - radius, 0, centerX - radius + 10, 20);
    path.arcToPoint(
      Offset(centerX + radius - 10, 20),
      radius: Radius.circular(40),
      clockwise: false,
    );
    path.quadraticBezierTo(centerX + radius, 0, centerX + radius + 10, 0);
    path.lineTo(width, 0);
    path.lineTo(width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CurvedNavBarClipper oldClipper) {
    return oldClipper.selectedIndex != selectedIndex;
  }
}
