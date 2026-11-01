import 'package:pushtrial/api/auth_token.dart';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pushtrial/push_notifications.dart';
import 'package:pushtrial/services/firebase_push.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/api/api.dart';
import '../models/user.dart';
import '../models/login.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../schools/screens/schools.dart';
import '../widgets/ui/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  static const _brandRed = Color(0xFFD71920); // fallback when school colour is missing

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final CallApi _callApi = CallApi();
  String? picurl;
  String? pic;
  bool _obscureText = true;
  List<SchoolInfo> schoolInfo = [];

  bool loading = true;
  bool _isSubmitting = false;

  Color schoolColor = _brandRed;

  Color hexToColor(String hexString) {
    final hex = hexString.replaceFirst('#', '');
    final value = hex.length == 6 ? 'FF$hex' : hex;
    if (value.length != 8) return _brandRed;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return _brandRed;
    final color = Color(parsed);
    return color.a == 0 ? _brandRed : color;
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  Future<void> getSchoolInfo() async {
    try {
      final response = await CallApi().getSchoolInfo();
      final parsedResponse = json.decode(response.body);
      if (response.statusCode != 200 ||
          parsedResponse is! List ||
          parsedResponse.isEmpty) {
        throw Exception('School information unavailable');
      }
      final info = parsedResponse
          .map((model) => SchoolInfo.fromJson(model))
          .toList();
      if (!mounted) return;
      setState(() {
        schoolInfo = info;
        schoolColor = hexToColor(info.first.schoolcolor);
        picurl = info.first.picurl;
      });
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog(
        'Thank you for your patience. This school is currently undergoing setup and is not accessible at this time. Please choose another school to proceed.',
      );
    }
  }

  void _showErrorDialog(String message) {
    showShadDialog(
      context: context,
      builder: (BuildContext context) {
        return ShadDialog.alert(
          title: const Text('School unavailable'),
          description: Text(message),
          actions: [
            ShadButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SchoolScreen()),
                );
              },
              child: const Text('Choose another school'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> getSchool() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selectedSchool');
  }

  Future<void> _loadSelectedSchool() async {
    String? selectedSchool = await getSchool();

    pic = selectedSchool;
  }

  Future<void> _login() async {
    if (_isSubmitting) return;
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      setState(() => _isSubmitting = true);
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      try {
        final response = await _callApi.login(username, password);
        // print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          if (response.body.isNotEmpty) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);

            if (responseData['stud'] != null &&
                responseData['userlogin'] != null) {
              final User user = User.fromJson(responseData['stud']);
              final Login userLogin = Login.fromJson(responseData['userlogin']);
              final prefs = await SharedPreferences.getInstance();

              // A v2 server signs the phone in with a token; a v1 server has none.
              final issued = responseData['token'];
              if (issued is String && issued.isNotEmpty) {
                await AuthToken.save(issued);
              } else {
                await AuthToken.clear();
              }

              await prefs.setString('user', jsonEncode(user.toJson()));
              await prefs.setString(
                'studid',
                responseData['stud']['id'].toString(),
              );
              await prefs.setString(
                'userlogin',
                jsonEncode(userLogin.toJson()),
              );

              // Only when Firebase push is in use for this phone (a school whose server has no app
              // alerts yet) is a push token requested and saved; FirebasePush decides after sign-in
              // for a school that hasn't been seen before.
              if (FirebasePush.isActive) {
                String? token = await PushNotifications.getFCMToken();
                if (token != null) {
                  await _callApi.getSaveToken(user.id, userLogin.type, token);
                }
              }

              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/home', arguments: user);
            } else {
              _showSnackBar('Incorrect username or password');
            }
          } else {
            _showSnackBar('Invalid username or password');
          }
        } else if (response.statusCode == 400) {
          _showSnackBar('Bad request. Please check your input.');
        } else if (response.statusCode == 401) {
          _showSnackBar('Incorrect username or password.');
        } else if (response.statusCode == 429) {
          _showSnackBar('Too many attempts. Please wait a few minutes and try again.');
        } else {
          _showSnackBar('Failed to login. Please try again.');
        }
      } catch (_) {
        _showSnackBar('An error occurred. Please try again.');
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      loading = true;
    });
    await _loadSelectedSchool();
    await getSchoolInfo();

    if (mounted) setState(() => loading = false);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ShadToaster.of(
      context,
    ).show(ShadToast.destructive(description: Text(message)));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _changeSchool() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SchoolScreen()),
      );
    }
  }

  Widget _buildSchoolLogo() {
    // A school without a logo of its own shows the Essentiel logo.
    final fallback = const EssentielEmblem();
    if (picurl == null || picurl!.trim().isEmpty || pic == null) return fallback;
    // Same address the app has always used: the school's domain followed by the stored path.
    // Uri.resolve would rewrite paths such as "../images/logo.png", so join them as text.
    final path = picurl!.trim();
    final url = path.startsWith('http')
        ? path
        : '${pic!.endsWith('/') ? pic : '$pic/'}${path.replaceFirst(RegExp(r'^/+'), '')}';
    return CachedNetworkImage(
      imageUrl: Uri.encodeFull(url),
      fit: BoxFit.contain,
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }


  Color _shade(Color color, double lightnessDelta) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
        .toColor();
  }

  /// Rounded, softly filled field that turns to the school colour when focused.
  ShadDecoration _fieldDecoration(ShadColorScheme scheme) {
    const radius = BorderRadius.all(Radius.circular(14));
    return ShadDecoration(
      color: scheme.muted.withValues(alpha: 0.6),
      border: ShadBorder.fromBorderSide(
        ShadBorderSide(color: Colors.transparent, width: 1.5),
        radius: radius,
      ),
      focusedBorder: ShadBorder.fromBorderSide(
        ShadBorderSide(color: schoolColor, width: 1.5),
        radius: radius,
      ),
      // The soft ring around a focused field: the school colour instead of the theme's red.
      secondaryFocusedBorder: ShadBorder.fromBorderSide(
        ShadBorderSide(color: schoolColor.withValues(alpha: 0.25), width: 4),
        radius: const BorderRadius.all(Radius.circular(18)),
      ),
      errorBorder: ShadBorder.fromBorderSide(
        ShadBorderSide(color: scheme.destructive, width: 1.5),
        radius: radius,
      ),
    );
  }

  Widget _buildHeader({
    required ShadTextTheme text,
    required Color onHeader,
    required Color headerStart,
    required Color headerEnd,
    required String schoolName,
    required bool compact,
  }) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [headerStart, headerEnd],
        ),
      ),
      child: CustomPaint(
        painter: _HeaderDecorPainter(onHeader.withValues(alpha: 0.10)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Gap.lg,
            top + Gap.sm,
            Gap.lg,
            compact ? Gap.xxl + Gap.sm : 56,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Row(
                    children: [
                      const EssentielMark(size: 52),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _changeSchool,
                        style: TextButton.styleFrom(
                          foregroundColor: onHeader,
                          backgroundColor: onHeader.withValues(alpha: 0.14),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md,
                            vertical: Gap.xs,
                          ),
                        ),
                        icon: const Icon(LucideIcons.school, size: 16),
                        label: const Text('Change school'),
                      ),
                    ],
                  ),
                  // The logo and name fold away while the keyboard is open, so the fields and
                  // the Sign in button stay above it.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: compact
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            children: [
                              Gap.hXl,
                              Container(
                                width: 104,
                                height: 104,
                                padding: const EdgeInsets.all(Gap.md),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: onHeader.withValues(alpha: 0.35),
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipOval(child: _buildSchoolLogo()),
                              ),
                              Gap.hLg,
                              Text(
                                schoolName.isEmpty ? 'Your school' : schoolName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.h4.copyWith(
                                  color: onHeader,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Gap.hSm,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Gap.md,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: onHeader.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.users, size: 14, color: onHeader),
                                    Gap.wSm,
                                    Text(
                                      'Student & Parent Portal',
                                      style: text.small.copyWith(
                                        color: onHeader,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureTile(IconData icon, String label, ShadTextTheme text) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: schoolColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: IconSize.row, color: schoolColor),
          ),
          Gap.hSm,
          Text(
            label,
            textAlign: TextAlign.center,
            style: text.small.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildForm({
    required ShadTextTheme text,
    required ShadColorScheme scheme,
    required bool compact,
  }) {
    final onButton =
        schoolColor.computeLuminance() > 0.6 ? Colors.black : Colors.white;
    final decoration = _fieldDecoration(scheme);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back',
            style: text.h3.copyWith(fontWeight: FontWeight.w800),
          ),
          Gap.hXs,
          Text(
            'Sign in to follow grades, attendance and billing.',
            style: text.muted,
          ),
          Gap.hXl,
          Text('Username', style: text.small),
          Gap.hSm,
          ShadInputFormField(
            controller: _usernameController,
            decoration: decoration,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            placeholder: const Text('Enter your username'),
            leading: Icon(
              LucideIcons.user,
              size: IconSize.row,
              color: scheme.mutedForeground,
            ),
            validator: (value) =>
                value.trim().isEmpty ? 'Please enter your username' : null,
          ),
          Gap.hLg,
          Text('Password', style: text.small),
          Gap.hSm,
          ShadInputFormField(
            controller: _passwordController,
            decoration: decoration,
            obscureText: _obscureText,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _login(),
            placeholder: const Text('Enter your password'),
            leading: Icon(
              LucideIcons.lock,
              size: IconSize.row,
              color: scheme.mutedForeground,
            ),
            trailing: Tooltip(
              message: _obscureText ? 'Show password' : 'Hide password',
              child: ShadButton.ghost(
                onPressed: _togglePasswordVisibility,
                child: Icon(
                  _obscureText ? LucideIcons.eye : LucideIcons.eyeOff,
                  color: scheme.mutedForeground,
                  size: IconSize.row,
                ),
              ),
            ),
            validator: (value) =>
                value.isEmpty ? 'Please enter your password' : null,
          ),
          Gap.hMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 14, color: scheme.mutedForeground),
              Gap.wSm,
              Expanded(
                child: Text(
                  'Student usernames start with S and parent usernames with P.',
                  style: text.muted.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          Gap.hXl,
          ShadButton(
            onPressed: _isSubmitting ? null : _login,
            enabled: !_isSubmitting,
            width: double.infinity,
            height: kMinTap + 8,
            backgroundColor: schoolColor,
            foregroundColor: onButton,
            decoration: ShadDecoration(
              border: ShadBorder(radius: BorderRadius.circular(14)),
              shadows: [
                BoxShadow(
                  color: schoolColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: onButton,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sign in'),
                      Gap.wSm,
                      Icon(LucideIcons.logIn, size: IconSize.inline, color: onButton),
                    ],
                  ),
          ),
          if (!compact) ...[
            Gap.hXxl,
            Row(
              children: [
                Expanded(child: Divider(color: scheme.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  child: Text('What you can do', style: text.muted),
                ),
                Expanded(child: Divider(color: scheme.border)),
              ],
            ),
            Gap.hLg,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _featureTile(LucideIcons.bookOpen, 'Report card', text),
                _featureTile(LucideIcons.calendarClock, 'Class schedule', text),
                _featureTile(LucideIcons.receipt, 'Billing', text),
                _featureTile(LucideIcons.badgeCheck, 'Tap history', text),
              ],
            ),
            Gap.hXl,
            Center(
              child: Text(
                'Powered by Essentiel',
                style: text.muted.copyWith(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final schoolName = schoolInfo.isEmpty
        ? 'Your school'
        : schoolInfo.first.schoolname.trim();

    final headerStart = _shade(schoolColor, -0.04);
    final headerEnd = _shade(schoolColor, -0.20);
    final headerIsLight = headerStart.computeLuminance() > 0.55;
    final onHeader = headerIsLight ? const Color(0xFF111827) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: headerIsLight
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: scheme.background,
        body: loading
            ? const SafeArea(child: LoadingSkeleton(cards: 2))
            : SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 24),
                      child: child,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildHeader(
                        text: text,
                        onHeader: onHeader,
                        headerStart: headerStart,
                        headerEnd: headerEnd,
                        schoolName: schoolName,
                        compact: keyboardOpen,
                      ),
                      // The sheet overlaps the bottom of the header so its rounded top
                      // corners show the gradient behind them.
                      Transform.translate(
                        offset: const Offset(0, -28),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: scheme.background,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 460),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    Gap.xl,
                                    Gap.xl + Gap.xs,
                                    Gap.xl,
                                    Gap.xl,
                                  ),
                                  child: _buildForm(
                                    text: text,
                                    scheme: scheme,
                                    compact: keyboardOpen,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Soft overlapping circles on the header, in the spirit of the blob shapes used by
/// school portals; purely decorative.
class _HeaderDecorPainter extends CustomPainter {
  const _HeaderDecorPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.10), 90, paint);
    canvas.drawCircle(Offset(size.width * 0.02, size.height * 0.38), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.80, size.height * 0.88), 46, paint);
  }

  @override
  bool shouldRepaint(_HeaderDecorPainter oldDelegate) => oldDelegate.color != color;
}
