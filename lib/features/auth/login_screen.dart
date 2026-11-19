import 'package:pushtrial/core/api/auth_token.dart';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pushtrial/core/services/push_notifications.dart';
import 'package:pushtrial/core/services/firebase_push.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/core/api/api.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/login.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pushtrial/core/config/app_config.dart';
import 'package:pushtrial/features/schools/models/schools.dart';
import 'package:pushtrial/features/schools/school_finder_sheet.dart';
import 'package:pushtrial/shared/utils/school_utils.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  static const _brandRed = Color(
    0xFFD71920,
  ); // fallback when school colour is missing

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  // Made again whenever the school changes, so it always talks to the chosen school's server.
  CallApi _callApi = CallApi();
  String? picurl;
  String? pic;
  bool _obscureText = true;
  List<SchoolInfo> schoolInfo = [];

  bool loading = true;
  bool _isSubmitting = false;

  /// The last sign-in problem, shown under the fields until the person edits them again.
  String? _loginError;

  Color schoolColor = _brandRed;

  /// False on a first launch, until the person picks a school in the finder.
  bool get hasSchool => pic != null && pic!.isNotEmpty;

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
      // Remembered now so the dashboard opens in the school colour straight after sign-in.
      final parsed = SchoolUtils.parseColor(info.first.schoolcolor);
      if (parsed != null) await SchoolUtils.remember(parsed);
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

  Future<void> _showErrorDialog(String message) async {
    final choose = await showNoticeSheet(
      context,
      title: 'School unavailable',
      message: message,
      buttonLabel: 'Choose another school',
      icon: LucideIcons.school,
      error: true,
    );
    if (choose && mounted) _chooseSchool();
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
    if (!hasSchool) return _chooseSchool();
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isSubmitting = true;
        _loginError = null;
      });
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
          _showSnackBar(
            'Too many attempts. Please wait a few minutes and try again.',
          );
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
    _usernameController.addListener(_clearLoginError);
    _passwordController.addListener(_clearLoginError);
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      loading = true;
    });
    await _loadSelectedSchool();
    if (hasSchool) await getSchoolInfo();

    // First launch shows the sign-in form as it is; the finder opens only when the person taps
    // the School field or the "Choose your school" button.
    if (mounted) setState(() => loading = false);
  }

  /// Sign-in problems show under the fields (where the person is looking), not as a brief toast.
  void _showSnackBar(String message) {
    if (!mounted) return;
    setState(() => _loginError = message);
  }

  void _clearLoginError() {
    if (_loginError != null && mounted) setState(() => _loginError = null);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _finderOpen = false;

  /// Opens the school finder over this screen and switches to the school that is picked.
  Future<void> _chooseSchool() async {
    if (_finderOpen || !mounted) return;
    _finderOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();
    final School? school = await showSchoolFinder(context);
    _finderOpen = false;
    if (school == null || !mounted) return;
    await _applySchool(school);
  }

  Future<void> _applySchool(School school) async {
    setState(() => loading = true);
    SchoolUtils.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedSchool', AppConfig.secureUrl(school.eslink));
    await prefs.setString('schoolVersion', school.schoolVersion);
    await prefs.setInt('selectedSchoolId', school.id);
    _callApi = CallApi();
    _usernameController.clear();
    _passwordController.clear();
    if (!mounted) return;
    setState(() {
      _loginError = null;
      pic = prefs.getString('selectedSchool');
      schoolInfo = [];
      picurl = null;
      schoolColor = _brandRed;
    });
    await getSchoolInfo();
    if (mounted) setState(() => loading = false);
  }

  /// Back to the original Essentiel screen: forgets the chosen school (so a sign-out does not
  /// leave the last school on this screen) and returns to the school selector with Essentiel's
  /// own logo and colour.
  Future<void> _resetSchool() async {
    if (_isSubmitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    SchoolUtils.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedSchool');
    await prefs.remove('selectedSchoolId');
    await prefs.remove('schoolVersion');
    _callApi = CallApi();
    _usernameController.clear();
    _passwordController.clear();
    if (!mounted) return;
    setState(() {
      _loginError = null;
      pic = null;
      schoolInfo = [];
      picurl = null;
      schoolColor = _brandRed;
    });
  }

  /// "‹ Essentiel" pill in the header, shown while a school is chosen.
  Widget _buildBackToEssentiel({
    required ShadTextTheme text,
    required Color onHeader,
  }) {
    return Semantics(
      button: true,
      label: 'Back to Essentiel. Forgets the chosen school',
      excludeSemantics: true,
      child: Material(
        color: onHeader.withValues(alpha: 0.16),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: _resetSchool,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kTapTarget),
            child: Padding(
              padding: const EdgeInsets.only(left: Gap.sm, right: Gap.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.chevronLeft,
                    size: IconSize.row,
                    color: onHeader,
                  ),
                  Gap.wXs,
                  Text(
                    'Essentiel',
                    style: text.small.copyWith(
                      color: onHeader,
                      fontWeight: FontWeight.w700,
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

  Widget _buildSchoolLogo() {
    // A school without a logo of its own shows the Essentiel logo.
    final fallback = const EssentielEmblem();
    if (picurl == null || picurl!.trim().isEmpty || pic == null)
      return fallback;
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

  /// Rounded, softly filled field that turns to the school colour when focused.
  ShadDecoration _fieldDecoration(ShadColorScheme scheme) {
    final radius = BorderRadius.circular(AppRadius.pill);
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
        radius: radius,
      ),
      errorBorder: ShadBorder.fromBorderSide(
        ShadBorderSide(color: scheme.destructive, width: 1.5),
        radius: radius,
      ),
    );
  }

  Color _shade(Color color, double lightnessDelta) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
        .toColor();
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
        painter: HeaderDecorPainter(onHeader.withValues(alpha: 0.10)),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                Gap.lg,
                top + (compact ? Gap.lg : Gap.xxl),
                Gap.lg,
                compact ? Gap.xxl : 56,
              ),
              // The logo folds away while the keyboard is open, but the school stays named, so the
              // person never types a password without seeing which school it is for.
              child: Center(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!compact) ...[
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
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          schoolName.isEmpty ? 'Student portal' : schoolName,
                          textAlign: TextAlign.center,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: (compact ? text.small : text.h4).copyWith(
                            color: onHeader,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasSchool)
              Positioned(
                left: Gap.md,
                top: top + Gap.sm,
                child: _buildBackToEssentiel(text: text, onHeader: onHeader),
              ),
          ],
        ),
      ),
    );
  }

  /// The school as a field: shows the chosen school, or asks for one, and opens the finder.
  Widget _buildSchoolField({
    required ShadTextTheme text,
    required ShadColorScheme scheme,
  }) {
    final name = schoolInfo.isEmpty ? '' : schoolInfo.first.schoolname.trim();
    return ListRow(
      margin: EdgeInsets.zero,
      title: name.isEmpty ? 'Select your school' : name,
      subtitle: name.isEmpty ? null : 'Change school',
      semanticLabel: name.isEmpty
          ? 'School. Choose your school'
          : 'School: $name. Change school',
      leading: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(Gap.xs + 2),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.border),
        ),
        child: ClipOval(
          child: name.isEmpty ? const EssentielEmblem() : _buildSchoolLogo(),
        ),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: IconSize.inline,
        color: scheme.mutedForeground,
      ),
      onTap: _chooseSchool,
    );
  }

  Widget _buildForm({
    required ShadTextTheme text,
    required ShadColorScheme scheme,
  }) {
    final onButton = schoolColor.computeLuminance() > 0.6
        ? Colors.black
        : Colors.white;
    final decoration = _fieldDecoration(scheme);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSchoolField(text: text, scheme: scheme),
          // Until a school is chosen only the school field shows; the username and password
          // fields appear (animated) once there is a school to sign in to.
          AnimatedSize(
            duration: AppMotion.of(context, const Duration(milliseconds: 250)),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !hasSchool
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Gap.hMd,
                      ShadInputFormField(
                        controller: _usernameController,
                        enabled: hasSchool,
                        decoration: decoration,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        placeholder: const Text('Student or parent username'),
                        leading: Icon(
                          LucideIcons.user,
                          size: IconSize.row,
                          color: scheme.mutedForeground,
                        ),
                        validator: (value) => value.trim().isEmpty
                            ? 'Please enter your username'
                            : null,
                      ),
                      Gap.hMd,
                      ShadInputFormField(
                        controller: _passwordController,
                        enabled: hasSchool,
                        decoration: decoration,
                        obscureText: _obscureText,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _login(),
                        placeholder: const Text('Password'),
                        leading: Icon(
                          LucideIcons.lock,
                          size: IconSize.row,
                          color: scheme.mutedForeground,
                        ),
                        trailing: Tooltip(
                          message: _obscureText
                              ? 'Show password'
                              : 'Hide password',
                          child: ShadButton.ghost(
                            width: kTapTarget,
                            height: kTapTarget,
                            padding: EdgeInsets.zero,
                            decoration: appPillDecoration(),
                            onPressed: _togglePasswordVisibility,
                            child: Icon(
                              _obscureText
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              color: scheme.mutedForeground,
                              size: IconSize.row,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value.isEmpty ? 'Please enter your password' : null,
                      ),
                    ],
                  ),
          ),
          AnimatedSize(
            duration: AppMotion.of(context, const Duration(milliseconds: 200)),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _loginError == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Gap.md),
                    child: Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.lg,
                          vertical: Gap.md,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.destructive.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppRadius.row),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              LucideIcons.circleAlert,
                              size: IconSize.row,
                              color: scheme.destructive,
                            ),
                            Gap.wSm,
                            Expanded(
                              child: Text(
                                _loginError!,
                                style: text.smallStrong.copyWith(
                                  color: scheme.destructive,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          Gap.hXl,
          ShadButton(
            onPressed: _isSubmitting
                ? null
                : (hasSchool ? _login : _chooseSchool),
            enabled: !_isSubmitting,
            width: double.infinity,
            height: kMinTap + 8,
            backgroundColor: schoolColor,
            foregroundColor: onButton,
            decoration: appPillDecoration(),
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: onButton,
                    ),
                  )
                : Text(hasSchool ? 'Sign in' : 'Choose your school'),
          ),
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
        ? ''
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
            : LayoutBuilder(
                // The page is at least as tall as the screen: the header takes the spare height
                // and the white sheet sits at the bottom, instead of leaving an empty gap below it.
                builder: (context, viewport) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: viewport.maxHeight),
                    child: IntrinsicHeight(
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
                            Expanded(
                              child: _buildHeader(
                                text: text,
                                onHeader: onHeader,
                                headerStart: headerStart,
                                headerEnd: headerEnd,
                                schoolName: schoolName,
                                compact: keyboardOpen,
                              ),
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
                                      constraints: const BoxConstraints(
                                        maxWidth: 460,
                                      ),
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
                ),
              ),
      ),
    );
  }
}
