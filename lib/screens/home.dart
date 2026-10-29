import 'package:pushtrial/api/api_version.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/user.dart';
import '../widgets/carousel_card.dart';
import 'package:pushtrial/services/message_read_store.dart';
import 'package:pushtrial/services/messages_repository.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/login.dart';
import 'package:pushtrial/models/user_login.dart';
import 'package:pushtrial/api/api.dart';
import 'notifications.dart';
import 'payment.dart';
import 'clearance.dart';
import 'enrollment.dart';
import 'scholarship_request.dart';
import 'teacher_evaluation.dart';
import 'billing_information.dart';
import 'billing_information_v2.dart';
import 'reportcard.dart';
import 'class_schedule.dart';
import 'class_schedule_v2.dart';
import 'package:pushtrial/models/school_info.dart';
import 'dart:convert';
import 'dart:async';
import '../widgets/school_utils.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../widgets/ui/ui.dart';

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
  Color schoolColor = const Color(0xFFD71920);

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
        setState(() => _notificationCount = list.where((m) => m.isUnread).length);
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

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _initializeData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello!', style: text.muted),
                          Gap.hXs,
                          Text(
                            name,
                            style: text.h3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Gap.wMd,
                    _NotificationBell(
                      count: _notificationCount,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationsScreen(),
                          ),
                        );
                        // Whatever was just viewed is now read on this phone.
                        if (mounted) getSMSBunker();
                      },
                    ),
                  ],
                ),
                Gap.hXl,
                CarouselCard(key: ValueKey(_carouselRefreshKey)),
                const SectionHeader('Features'),
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: features.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: Gap.lg,
                    crossAxisSpacing: Gap.sm,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final feature = features[index];
                    final label = feature['label'] as String;
                    return Semantics(
                      button: true,
                      label: label,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openFeature(index),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShadCard(
                              height: 60,
                              width: 60,
                              padding: EdgeInsets.zero,
                              child: Center(
                                child: Icon(
                                  feature['icon'] as IconData,
                                  size: IconSize.nav,
                                  color: scheme.primary,
                                ),
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
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
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
  const _NotificationBell({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
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
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: theme.radius,
                  border: Border.all(color: theme.colorScheme.border),
                ),
                child: SizedBox(
                  width: kMinTap,
                  height: kMinTap,
                  child: Icon(
                    count > 0 ? LucideIcons.bellRing : LucideIcons.bell,
                    size: IconSize.row,
                    color: theme.colorScheme.foreground,
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
