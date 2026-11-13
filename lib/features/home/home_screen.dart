import 'package:pushtrial/core/api/api_version.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/shared/widgets/carousel_card.dart';
import 'package:pushtrial/core/services/message_read_store.dart';
import 'package:pushtrial/core/services/messages_repository.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/login.dart';
import 'package:pushtrial/models/user_login.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/features/notifications/notifications_screen.dart';
import 'package:pushtrial/features/payment/payment_screen.dart';
import 'package:pushtrial/features/clearance/clearance_screen.dart';
import 'package:pushtrial/features/enrollment/enrollment_screen.dart';
import 'package:pushtrial/features/scholarship/scholarship_request_screen.dart';
import 'package:pushtrial/features/teacher_evaluation/teacher_evaluation_screen.dart';
import 'package:pushtrial/features/billing/billing_information_screen.dart';
import 'package:pushtrial/features/billing/billing_information_v2_screen.dart';
import 'package:pushtrial/features/report_card/report_card_screen.dart';
import 'package:pushtrial/features/class_schedule/class_schedule_screen.dart';
import 'package:pushtrial/features/class_schedule/class_schedule_v2_screen.dart';
import 'package:pushtrial/models/school_info.dart';
import 'dart:convert';
import 'dart:async';
import 'package:pushtrial/shared/utils/school_utils.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> features = [
    {'icon': LucideIcons.calendarClock, 'label': 'Class schedule'},
    {'icon': LucideIcons.graduationCap, 'label': 'Report card'},
    {'icon': LucideIcons.receipt, 'label': 'Billing information'},
    {'icon': LucideIcons.fileCheck, 'label': 'Clearance'},
    {'icon': LucideIcons.arrowLeftRight, 'label': 'Payment transactions'},
    {'icon': LucideIcons.award, 'label': 'Scholarship request'},
    {'icon': LucideIcons.clipboardList, 'label': 'Teacher evaluation'},
    {'icon': LucideIcons.school, 'label': 'Enrollment'},
  ];

  int _carouselRefreshKey = 0;
  int _notificationCount = 0;
  User user = UserData.myUser;
  late Future<void> _checkAndNotifyFuture;
  int studid = 0;
  int id = 0;
  String userFirstName = '';

  String? notificationMessage;
  List<String> notifications = [];
  Login userLogin = UserDataLogin.myUserLogin;
  int type = 0;

  bool loading = true;
  String schoolVersion = 'v1';
  String billingVersion = 'v1';
  Future<String?> host = CallApi().getImage();
  String? picurl;
  String? pic;

  List<SchoolInfo> schoolInfo = [];
  Color? schoolColor = SchoolUtils.lastColor;

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

  @override
  void initState() {
    super.initState();

    _checkAndNotifyFuture = _initializeData();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadSchoolInfo();
    await _loadSelectedSchool();
    setState(() {
      loading = true;
      _carouselRefreshKey++; // Increment key to rebuild CarouselCard
    });
    await getUser();
    await getLogin();
    await getSMSBunker();

    setState(() {
      loading = false;
    });
  }

  Future<void> getLogin() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('userlogin');
    userLogin = json == null
        ? UserDataLogin.myUserLogin
        : Login.fromJson(jsonDecode(json));
    // print('User login data in notifications: $userLogin');

    type = userLogin.type;
  }

  getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('user');
    final version = preferences.getString('schoolVersion') ?? 'v1';
    final billing = await ApiVersion.billingVersion();
    setState(() {
      schoolVersion = version;
      billingVersion = billing;
    });
    user = json == null ? UserData.myUser : User.fromJson(jsonDecode(json));
    print('User data: $user');
    {
      setState(() {
        studid = user.id;
        userFirstName = user.firstname!;
      });
    }
  }

  Future<void> getSMSBunker() async {
    try {
      // Same list and rule as the Notifications page: unread = under 24 hours old and not yet read
      // on this phone (read state is kept in the app only), from whatever version of the school's
      // server there is (see MessagesRepository).
      final list = await MessagesRepository.load(studid, userLogin.type);
      if (list != null) {
        await MessageReadStore.apply(list, studid);
        setState(
          () => _notificationCount = list.where((m) => m.isUnread).length,
        );
      }
    } catch (e) {
      print('Exception occurred: $e');
    }
  }

  void _handleNotification(String message) {
    setState(() {
      notifications.add(message);
      _notificationCount = notifications.length;
    });
  }

  Future<void> saveUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('firstname', user.firstname ?? '');
    await prefs.setString('middlename', user.middlename ?? '');
    await prefs.setString('lastname', user.lastname ?? '');
    await prefs.setString('sid', user.sid ?? '');
    await prefs.setString('fathername', user.fathername ?? '');
  }

  Future<User> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    return User(
      firstname: prefs.getString('firstname') ?? '',
      middlename: prefs.getString('middlename') ?? '',
      lastname: prefs.getString('lastname') ?? '',
      sid: prefs.getString('sid') ?? '',
      fathername: prefs.getString('fathername') ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final name = '${user.firstname ?? ''} ${user.lastname ?? ''}'.trim();
    // Tinted from the logged-in school's colour; the theme colour until that is known.
    final tone = SchoolTone(context, schoolColor ?? scheme.primary);

    return AppPage.root(
      title: name.isEmpty ? 'Hello!' : 'Hello, ${user.firstname ?? name}!',
      backgroundColor: tone.background,
      onRefresh: _initializeData,
      actions: [
        _NotificationBell(
          count: _notificationCount,
          tone: tone,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationsScreen()),
            );
            // Whatever was just viewed is now read on this phone.
            if (mounted) getSMSBunker();
          },
        ),
      ],
      children: [
        CarouselCard(
          key: ValueKey(_carouselRefreshKey),
          schoolColor: schoolColor,
        ),
        Padding(
          padding: const EdgeInsets.only(top: Gap.xl, bottom: Gap.lg),
          child: Row(
            children: [
              AccentBar(tone),
              Gap.wSm,
              Text('Features', style: text.large),
            ],
          ),
        ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: features.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: Gap.lg,
            crossAxisSpacing: Gap.sm,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final feature = features[index];
            final label = feature['label'] as String;
            // Tall rounded tile: a round icon well on top, the label under it.
            return Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: RoundedCard(
                radius: 24,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.xs,
                  vertical: Gap.md,
                ),
                onTap: () => _openFeature(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.muted,
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        size: IconSize.row + 2,
                        color: scheme.foreground,
                      ),
                    ),
                    Gap.hSm,
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.small.copyWith(
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openFeature(int index) {
    final Widget? page;
    switch (index) {
      case 0:
        page = schoolVersion == 'v2'
            ? const ClassScheduleV2Screen()
            : ClassScheduleScreen();
        break;
      case 1:
        page = ReportCardScreen();
        break;
      case 2:
        page = billingVersion == 'v2'
            ? const BillingInformationV2Page()
            : BillingInformationPage();
        break;
      case 3:
        page = ClearanceScreen();
        break;
      case 4:
        page = PaymentPage();
        break;
      case 5:
        page = ScholarshipRequestScreen();
        break;
      case 6:
        page = TeacherEvaluationScreen();
        break;
      case 7:
        page = EnrollmentScreen();
        break;
      default:
        page = null;
    }
    if (page == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
  }
}

/// Bell with an unread count; the whole thing is a 44px touch target.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.count,
    required this.tone,
    required this.onTap,
  });

  final int count;
  final SchoolTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'Notifications, $count unread' : 'Notifications',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: kMinTap,
          height: kMinTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: kMinTap,
                height: kMinTap,
                child: RoundedCard(
                  radius: 999,
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  child: Icon(
                    count > 0 ? LucideIcons.bellRing : LucideIcons.bell,
                    size: IconSize.row,
                    color: ShadTheme.of(context).colorScheme.foreground,
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  right: -Gap.xs,
                  top: -Gap.xs,
                  child: ShadBadge.destructive(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    child: Text(count > 99 ? '99+' : '$count'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
