import 'package:pushtrial/core/api/auth_token.dart';
import 'package:flutter/material.dart';
import 'package:pushtrial/models/user_login.dart';
import 'package:pushtrial/core/services/firebase_push.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/features/auth/login_screen.dart';

import 'dart:convert';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/login.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/models/enrolled_student.dart';
import 'package:pushtrial/core/services/school_alerts.dart';
import 'package:pushtrial/core/config/theme_controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pushtrial/shared/utils/school_utils.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User user = UserData.myUser;
  Login userLogin = UserDataLogin.myUserLogin;
  String id = '0';
  String selectedYear = '';

  String syDesc = '';
  String sem = '';
  Future<String?> host = CallApi().getImage();
  bool isValid = false;
  bool loading = true;
  String? pic;
  String? picurl;
  List<SchoolInfo> schoolInfo = [];

  /// The logged-in school's colour (SchoolUtils); the theme colour while it is unknown.
  Color? _schoolColor = SchoolUtils.lastColor;
  Color get schoolColor =>
      _schoolColor ?? ShadTheme.of(context).colorScheme.primary;
  Color get accentColor => ShadTheme.of(context).colorScheme.primary;
  List<EnrolledStud> enrolledstud = [];
  bool realtimeAlerts = false;

  /// False for a school whose server has no app alerts yet: the switch would do nothing there.
  bool alertsAvailable = true;

  SchoolTone get _tone => SchoolTone(context, schoolColor);

  Future<void> getSchoolInfo() async {
    final response = await CallApi().getSchoolInfo();

    final parsedResponse = json.decode(response.body);
    if (parsedResponse is List && parsedResponse.isNotEmpty && mounted) {
      setState(() {
        schoolInfo = parsedResponse
            .map((model) => SchoolInfo.fromJson(model))
            .toList()
            .cast<SchoolInfo>();

        final parsed = SchoolUtils.parseColor(schoolInfo[0].schoolcolor);
        if (parsed != null) {
          _schoolColor = parsed;
          SchoolUtils.remember(parsed);
        }
      });
    }
  }

  Future<String?> getSchool() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selectedSchool');
  }

  Future<void> _loadSelectedSchool() async {
    String? selectedSchool = await getSchool();

    pic = selectedSchool;
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData({bool showLoading = true}) async {
    if (showLoading) setState(() => loading = true);
    try {
      await getUser();
      await getUserInfo();
      await _loadSelectedSchool();
      await Future.wait<void>([
        getSchoolInfo().timeout(const Duration(seconds: 15)),
        getEnrolledStud().timeout(const Duration(seconds: 15)),
      ]);
    } catch (_) {
      // Profile details already available from the signed-in user can still be shown.
    } finally {
      try {
        realtimeAlerts = await SchoolAlerts.isRealtimeRunning();
        alertsAvailable = await SchoolAlerts.serverHasAlerts();
      } catch (_) {
        // Keep the current toggle value if notification status is unavailable.
      }
      if (mounted) {
        setState(() {
          if (showLoading) loading = false;
        });
      }
    }
  }

  Future<void> _toggleRealtimeAlerts(bool on) async {
    final enabled = await SchoolAlerts.setRealtime(on);
    if (!mounted) return;
    setState(() => realtimeAlerts = enabled);
    if (on && !enabled) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          description: Text(
            'Allow notifications for this app to turn on real-time tap alerts.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage.root(
      title: 'Profile',
      backgroundColor: _tone.background,
      body: loading
          ? const LoadingSkeleton()
          : RefreshIndicator(
              color: accentColor,
              onRefresh: () => _initializeData(showLoading: false),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.lg,
                  Gap.lg,
                  Gap.xl + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _buildProfileHeader(),
                  Gap.hLg,
                  _buildSectionCard(
                    title: 'Appearance',
                    icon: LucideIcons.palette,
                    children: [
                      _buildSettingRow(
                        icon: AppThemeController.instance.isDark
                            ? LucideIcons.moon
                            : LucideIcons.sun,
                        title: 'Dark mode',
                        subtitle: 'Use a darker appearance throughout the app.',
                        value: AppThemeController.instance.isDark,
                        onChanged: (enabled) async {
                          final saved = await AppThemeController.instance
                              .setDark(enabled);
                          if (!saved && context.mounted) {
                            ShadToaster.of(context).show(
                              const ShadToast.destructive(
                                description: Text(
                                  'Could not save your appearance setting.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Enrollment',
                    icon: LucideIcons.school,
                    children: [
                      _buildInfoRow('School year', selectedYear),
                      _buildInfoRow('Grade level', _getGradeLevel()),
                      _buildInfoRow('Strand', _getStrand()),
                      _buildInfoRow('Course', _getCourse()),
                      _buildInfoRow('LRN', widget.user.lrn ?? ''),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Personal details',
                    icon: LucideIcons.user,
                    children: [
                      _buildInfoRow('First name', widget.user.firstname ?? ''),
                      _buildInfoRow(
                        'Middle name',
                        widget.user.middlename ?? '',
                      ),
                      _buildInfoRow('Last name', widget.user.lastname ?? ''),
                      _buildInfoRow('Suffix', widget.user.suffix),
                      _buildInfoRow('Student ID', widget.user.sid ?? ''),
                      _buildInfoRow('Date of birth', widget.user.dob ?? ''),
                      _buildInfoRow('Gender', widget.user.gender ?? ''),
                      _buildInfoRow(
                        'Nationality',
                        widget.user.nationalityDesc ?? '',
                      ),
                      _buildInfoRow(
                        'Mobile number',
                        widget.user.contactno ?? '',
                      ),
                      _buildInfoRow('Email address', widget.user.semail ?? ''),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Parents & guardian',
                    icon: LucideIcons.users,
                    children: [
                      _buildInfoRow(
                        "Father's name",
                        widget.user.fathername ?? '',
                      ),
                      _buildInfoRow(
                        "Father's occupation",
                        widget.user.foccupation ?? '',
                      ),
                      _buildInfoRow(
                        "Father's contact",
                        widget.user.fcontactno ?? '',
                      ),
                      _buildInfoRow(
                        "Mother's name",
                        widget.user.mothername ?? '',
                      ),
                      _buildInfoRow(
                        "Mother's occupation",
                        widget.user.moccupation ?? '',
                      ),
                      _buildInfoRow(
                        "Mother's contact",
                        widget.user.mcontactno ?? '',
                      ),
                      _buildInfoRow(
                        "Guardian's name",
                        widget.user.guardianname ?? '',
                      ),
                      _buildInfoRow(
                        "Guardian's relationship",
                        widget.user.guardianrelation ?? '',
                      ),
                      _buildInfoRow(
                        "Guardian's contact",
                        widget.user.gcontactno ?? '',
                      ),
                    ],
                  ),
                  _buildSectionCard(
                    title: 'Emergency contact',
                    icon: LucideIcons.siren,
                    children: [
                      _buildInfoRow(
                        'Primary contact',
                        widget.user.getPrimaryContactName() ?? 'Not provided',
                      ),
                    ],
                  ),
                  if (SchoolAlerts.supported && alertsAvailable)
                    _buildSectionCard(
                      title: 'Notifications',
                      icon: LucideIcons.bell,
                      children: [
                        _buildSettingRow(
                          icon: LucideIcons.bellRing,
                          title: 'Real-time tap alerts',
                          subtitle:
                              'Checks every 30 seconds, even when the app is closed. Shows a small notification while on.',
                          value: realtimeAlerts,
                          onChanged: _toggleRealtimeAlerts,
                        ),
                      ],
                    ),
                  Gap.hSm,
                  ShadButton.destructive(
                    onPressed: () => _logout(context),
                    width: double.infinity,
                    height: kMinTap + 8,
                    decoration: ShadDecoration(
                      border: ShadBorder.all(
                        radius: BorderRadius.circular(999),
                      ),
                    ),
                    leading: const Icon(LucideIcons.logOut, size: IconSize.row),
                    child: const Text('Log out'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final name = [
      widget.user.firstname,
      widget.user.middlename,
      widget.user.lastname,
      widget.user.suffix,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    final schoolName = schoolInfo.isEmpty ? '' : schoolInfo.first.schoolname;
    final imageUrl = _studentImageUrl();

    final tone = _tone;
    final onSolid = tone.onSolid;

    return SolidCard(
      tone: tone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, color: onSolid),
            child: ClipOval(
              child: imageUrl == null
                  ? _buildStudentAvatar()
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildStudentAvatar(),
                      errorWidget: (context, url, error) =>
                          _buildStudentAvatar(),
                    ),
            ),
          ),
          Gap.wLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Student profile' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.h4.copyWith(color: onSolid),
                ),
                if (schoolName.isNotEmpty) ...[
                  Gap.hXs,
                  Text(
                    schoolName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.small.copyWith(
                      color: onSolid.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                if (widget.user.sid != null && widget.user.sid!.isNotEmpty) ...[
                  Gap.hMd,
                  SchoolPill('ID ${widget.user.sid}', tone, onCard: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _studentImageUrl() {
    final path = widget.user.picurl?.trim() ?? '';
    if (path.isEmpty || path.toLowerCase() == 'null') return null;
    final uri = Uri.tryParse(path);
    if (uri == null) return null;
    if (uri.hasScheme) {
      return (uri.scheme == 'http' || uri.scheme == 'https') &&
              uri.host.isNotEmpty
          ? uri.toString()
          : null;
    }
    final base = Uri.tryParse(pic?.trim() ?? '');
    if (base == null ||
        !['http', 'https'].contains(base.scheme) ||
        base.host.isEmpty) {
      return null;
    }
    return base.resolveUri(uri).toString();
  }

  Widget _buildStudentAvatar() {
    final sex = widget.user.gender?.trim().toLowerCase();
    final icon = switch (sex) {
      'female' || 'f' => Icons.face_3,
      'male' || 'm' => Icons.face,
      _ => Icons.person,
    };
    final scheme = ShadTheme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.muted,
      child: Center(child: Icon(icon, size: 44, color: scheme.mutedForeground)),
    );
  }

  Future<void> getUserInfo() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('user');

    if (!mounted) return;
    setState(() {
      user = json == null ? UserData.myUser : User.fromJson(jsonDecode(json));

      picurl = user.picurl;
    });
  }

  /*************  ✨ Windsurf Command ⭐  *************/
  /// Returns the level name of the student's latest enrollment info or 'Not Available'
  /// if there is no enrolled student info.
  /*******  0719f279-07f4-473e-bf7c-cf4ed0ae6b5b  *******/
  String _getGradeLevel() {
    final latestInfo = getSelectedEnrolledStud();
    return latestInfo?.levelname ?? 'Not Available';
  }

  String _getStrand() {
    final latestInfo = getSelectedEnrolledStud();
    return latestInfo?.strandname ?? '';
  }

  String _getCourse() {
    final latestInfo = getSelectedEnrolledStud();
    return latestInfo?.courseDesc ?? '';
  }

  EnrolledStud? getSelectedEnrolledStud() {
    if (selectedYear.isEmpty) return null;
    for (final enrollment in enrolledstud.reversed) {
      if (enrollment.sydesc == selectedYear) return enrollment;
    }
    return null;
  }

  Future<void> getUser() async {
    final preferences = await SharedPreferences.getInstance();
    final studentId = preferences.getString('studid');
    if (!mounted || studentId == null) return;
    setState(() => id = studentId);
  }

  Future<void> getEnrolledStud() async {
    final response = await CallApi().getEnrolledStud(id);
    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['enrolledstud_info'] is! List) {
      return;
    }
    final enrollments = (decoded['enrolledstud_info'] as List)
        .map((item) => EnrolledStud.fromJson(item))
        .toList();
    if (!mounted) return;
    setState(() {
      enrolledstud = enrollments;
      if (enrollments.isNotEmpty) {
        selectedYear = enrollments.last.sydesc;
        syDesc = selectedYear;
        sem = enrollments.last.semester;
      }
    });
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = ShadTheme.of(context);
    return RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SchoolIcon(icon),
              Gap.wSm,
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.large,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Gap.hMd,
          Divider(height: 1, thickness: 1, color: theme.colorScheme.border),
          Gap.hSm,
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTap),
        child: Row(
          children: [
            SchoolIcon(icon, size: 36),
            Gap.wMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.p.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Gap.hXs,
                  Text(subtitle, style: theme.textTheme.muted),
                ],
              ),
            ),
            Gap.wMd,
            ShadSwitch(
              value: value,
              onChanged: onChanged,
              checkedTrackColor: schoolColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return InfoRow(label, value.trim());
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    final userLoginJson = prefs.getString('userlogin');
    if (userJson != null && userLoginJson != null) {
      final user = User.fromJson(jsonDecode(userJson));
      final studid = user.id;
      final userLogin = Login.fromJson(jsonDecode(userLoginJson));
      final type = userLogin.type;

      // Forgets this phone's push token on the school's server if Firebase push was in use.
      await FirebasePush.onLoggedOut(studid, type);
    }

    SchoolUtils.reset();
    await SchoolAlerts.onLoggedOut();
    await AuthToken.clear();
    await prefs.remove('user');
    await prefs.remove('userlogin');
    await prefs.remove('studid');

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
