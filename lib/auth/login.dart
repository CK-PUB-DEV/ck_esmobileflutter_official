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
    final fallback = Icon(
      LucideIcons.graduationCap,
      color: ShadTheme.of(context).colorScheme.primary,
      size: 48,
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final schoolName = schoolInfo.isEmpty
        ? 'Your school'
        : schoolInfo.first.schoolname.trim();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: scheme.background,
        body: SafeArea(
          child: loading
              ? const LoadingSkeleton(cards: 2)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.xxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: theme.radius,
                                ),
                                child: Icon(
                                  LucideIcons.graduationCap,
                                  color: scheme.primaryForeground,
                                  size: IconSize.row,
                                ),
                              ),
                              Gap.wSm,
                              Text('Essentiel', style: text.large),
                              const Spacer(),
                              ShadButton.ghost(
                                onPressed: _changeSchool,
                                size: ShadButtonSize.sm,
                                child: const Text('Change school'),
                              ),
                            ],
                          ),
                          if (!keyboardOpen) ...[
                            Gap.hXxl,
                            Center(
                              child: Container(
                                width: 112,
                                height: 112,
                                padding: const EdgeInsets.all(Gap.md),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: schoolColor.withValues(alpha: 0.25),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: schoolColor.withValues(alpha: 0.15),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: _buildSchoolLogo(),
                              ),
                            ),
                            Gap.hLg,
                            Text(
                              schoolName.isEmpty ? 'Your school' : schoolName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.h4,
                            ),
                            Gap.hXs,
                            Text(
                              'Student portal',
                              textAlign: TextAlign.center,
                              style: text.muted,
                            ),
                            Gap.hXl,
                          ] else
                            Gap.hLg,
                          ShadCard(
                            padding: const EdgeInsets.all(Gap.xl),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Welcome back', style: text.h3),
                                  Gap.hXs,
                                  Text(
                                    'Sign in to access your student account.',
                                    style: text.muted,
                                  ),
                                  Gap.hXl,
                                  Text('Username', style: text.small),
                                  Gap.hSm,
                                  ShadInputFormField(
                                    controller: _usernameController,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    placeholder: const Text(
                                      'Enter your username',
                                    ),
                                    leading: const Icon(
                                      LucideIcons.user,
                                      size: IconSize.row,
                                    ),
                                    validator: (value) => value.trim().isEmpty
                                        ? 'Please enter your username'
                                        : null,
                                  ),
                                  Gap.hLg,
                                  Text('Password', style: text.small),
                                  Gap.hSm,
                                  ShadInputFormField(
                                    controller: _passwordController,
                                    obscureText: _obscureText,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    onSubmitted: (_) => _login(),
                                    placeholder: const Text(
                                      'Enter your password',
                                    ),
                                    leading: const Icon(
                                      LucideIcons.lock,
                                      size: IconSize.row,
                                    ),
                                    trailing: Tooltip(
                                      message: _obscureText
                                          ? 'Show password'
                                          : 'Hide password',
                                      child: ShadButton.ghost(
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
                                    validator: (value) => value.isEmpty
                                        ? 'Please enter your password'
                                        : null,
                                  ),
                                  Gap.hXl,
                                  ShadButton(
                                    onPressed: _isSubmitting ? null : _login,
                                    enabled: !_isSubmitting,
                                    width: double.infinity,
                                    height: kMinTap + 4,
                                    backgroundColor: schoolColor,
                                    foregroundColor:
                                        schoolColor.computeLuminance() > 0.6
                                        ? Colors.black
                                        : Colors.white,
                                    child: _isSubmitting
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.3,
                                              color: scheme.primaryForeground,
                                            ),
                                          )
                                        : const Text('Sign in'),
                                  ),
                                ],
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
    );
  }
}
