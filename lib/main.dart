import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pushtrial/core/api/auth_token.dart';
import 'package:pushtrial/core/services/push_notifications.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pushtrial/core/config/app_config.dart';
import 'package:pushtrial/core/config/theme_controller.dart';
import 'package:pushtrial/core/services/firebase_push.dart';
import 'package:pushtrial/core/services/school_alerts.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/features/auth/login_screen.dart';
import 'package:pushtrial/features/loading/loading_screen.dart';
import 'package:pushtrial/features/notifications/notifications_screen.dart';
import 'package:pushtrial/features/dashboard/dashboard_screen.dart';

// import 'schools/schools.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// A school chosen before this rule existed may be saved with an `http://` address. In a release
/// build that is rewritten to `https://` once at start-up, so every screen that reads it agrees.
Future<void> _upgradeSavedSchoolToHttps() async {
  if (AppConfig.allowHttp) return;
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('selectedSchool');
  if (saved != null && AppConfig.secureUrl(saved) != saved) {
    await prefs.setString('selectedSchool', AppConfig.secureUrl(saved));
  }
}

void showNotification({required String title, required String body}) {
  showNoticeSheet(
    navigatorKey.currentContext!,
    title: title,
    message: body,
    icon: LucideIcons.bell,
  );
}

void main() {
  // The app has many print() calls that show addresses and student data. They are useful in debug
  // builds, but in a release they would still be written to the phone's log, where any tool
  // attached over USB can read them. So release builds drop them.
  runZoned(
    _main,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (kDebugMode) parent.print(zone, line);
      },
    ),
  );
}

/// The school's server no longer accepts this phone's sign-in (it expired, or the password was
/// changed): forget the saved student and show the sign-in screen.
Future<void> _sessionEnded() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('user');
  await prefs.remove('userlogin');
  await prefs.remove('studid');
  await SchoolAlerts.onLoggedOut();
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  navigator.pushNamedAndRemoveUntil('/login', (route) => false);
  final context = navigatorKey.currentContext;
  if (context != null && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Your session ended. Please sign in again.'),
      ),
    );
  }
}

Future<void> _main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthToken.ensureLoaded();
  AuthToken.onRejected = _sessionEnded;
  await _upgradeSavedSchoolToHttps();
  await AppThemeController.instance.load();
  // Debug builds skip the screenshot block so screens can be captured while testing;
  // release builds stay protected unless built with ALLOW_SCREEN_CAPTURE.
  if (!kIsWeb && !AppConfig.allowScreenCapture) {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageOn();
  }
  PushNotifications.init();

  if (!kIsWeb) {
    await PushNotifications.localNotiInit();
    await SchoolAlerts.initialize();
  }

  // Firebase push runs only where the school's server doesn't have the app's own alerts yet (and
  // came up last time it was needed); see FirebasePush. Otherwise it stays off.
  await FirebasePush.startup();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// The app's type scale (see [AppType]); shadcn's own sizes are tuned for the web and run large
  /// on a phone. Line heights stay generous for wrapped text.
  ///
  /// shadcn text styles carry no colour of their own, so `textTheme.muted` would render as plain
  /// foreground text. Bake the muted colour in so every `muted` label really looks muted.
  static ShadTextTheme _textTheme(ShadColorScheme scheme) => ShadTextTheme(
    h1: ShadTextDefaultTheme.h1(
      family: kDefaultFontFamily,
    ).copyWith(
      fontSize: AppType.display,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    h2: ShadTextDefaultTheme.h2(
      family: kDefaultFontFamily,
    ).copyWith(fontSize: AppType.heading, height: 1.2),
    h3: ShadTextDefaultTheme.h3(
      family: kDefaultFontFamily,
    ).copyWith(fontSize: AppType.subheading, height: 1.2),
    h4: ShadTextDefaultTheme.h4(
      family: kDefaultFontFamily,
    ).copyWith(fontSize: AppType.title, height: 1.3),
    large: ShadTextDefaultTheme.large(
      family: kDefaultFontFamily,
    ).copyWith(fontSize: AppType.section, height: 1.4),
    p: ShadTextDefaultTheme.p(
      family: kDefaultFontFamily,
    ).copyWith(fontSize: AppType.body, height: 1.45),
    small: ShadTextDefaultTheme.small(
      family: kDefaultFontFamily,
    ).copyWith(fontSize: AppType.small, height: 1.4),
    muted: ShadTextDefaultTheme.muted(
      family: kDefaultFontFamily,
    ).copyWith(
      fontSize: AppType.caption,
      height: 1.4,
      color: scheme.mutedForeground,
    ),
  );

  // Built once: rebuilding these on every toggle added to the lag.
  static final ShadThemeData _lightShadTheme = _buildShadTheme(false);
  static final ShadThemeData _darkShadTheme = _buildShadTheme(true);

  static ShadThemeData _buildShadTheme(bool dark) {
    final scheme = dark
        ? const ShadNeutralColorScheme.dark()
        : const ShadNeutralColorScheme.light();
    return ShadThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      textTheme: _textTheme(scheme),
      radius: BorderRadius.circular(12),
      selectTheme: _selectTheme(scheme, dark),
      inputTheme: _inputTheme(scheme, dark),
      // Dropdown lists: a rounded floating card, with a soft gray highlight on the chosen option
      // instead of the colour fill, so only destructive actions ever read red.
      popoverTheme: ShadPopoverTheme(
        decoration: ShadDecoration(
          color: scheme.card,
          border: ShadBorder.all(
            color: dark ? scheme.border : scheme.foreground.withValues(alpha: 0.10),
            width: 1,
            radius: BorderRadius.circular(20),
          ),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.5 : 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      ),
      optionTheme: ShadOptionTheme(
        radius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hoveredBackgroundColor: scheme.muted,
        selectedBackgroundColor: scheme.muted,
        selectedTextStyle: TextStyle(
          color: scheme.foreground,
          fontWeight: FontWeight.w600,
        ),
        selectedIconColor: scheme.foreground,
      ),
    );
  }

  /// Material themes are built from fixed data, never from the surrounding (animating) theme, so
  /// MaterialApp is not rebuilt with a fresh ThemeData on every frame of shadcn's theme lerp.
  static final ThemeData _lightMaterialTheme = _materialTheme(_lightShadTheme);
  static final ThemeData _darkMaterialTheme = _materialTheme(_darkShadTheme);

  static ThemeData _materialTheme(ShadThemeData shadTheme) {
    final shad = shadTheme.colorScheme;
    final dark = shadTheme.brightness == Brightness.dark;
    final base = ThemeData(
      fontFamily: shadTheme.textTheme.family,
      brightness: shadTheme.brightness,
      // Unstyled `Text`, list tiles and Material widgets read these, so they match the app scale.
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: AppType.body, height: 1.45),
        bodyMedium: TextStyle(fontSize: AppType.body, height: 1.45),
        bodySmall: TextStyle(fontSize: AppType.caption, height: 1.4),
        titleLarge: TextStyle(fontSize: AppType.title),
        titleMedium: TextStyle(fontSize: AppType.section),
        titleSmall: TextStyle(fontSize: AppType.body),
        labelLarge: TextStyle(fontSize: AppType.body),
        labelMedium: TextStyle(fontSize: AppType.small),
        labelSmall: TextStyle(fontSize: AppType.micro),
      ),
      colorScheme: ColorScheme(
        brightness: shadTheme.brightness,
        primary: shad.primary,
        onPrimary: shad.primaryForeground,
        secondary: shad.secondary,
        onSecondary: shad.secondaryForeground,
        error: shad.destructive,
        onError: shad.destructiveForeground,
        surface: shad.background,
        onSurface: shad.foreground,
      ),
      scaffoldBackgroundColor: shad.background,
      dividerTheme: DividerThemeData(color: shad.border, thickness: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: shad.primary,
        selectionColor: shad.selection,
        selectionHandleColor: shad.primary,
      ),
      iconTheme: IconThemeData(size: 16, color: shad.foreground),
    );
    final colorScheme = base.colorScheme.copyWith(
      surface: shad.card,
      onSurface: shad.cardForeground,
      onSurfaceVariant: shad.mutedForeground,
      surfaceContainerHighest: shad.muted,
      outline: shad.border,
      outlineVariant: shad.border,
    );
    final radius = BorderRadius.circular(12);
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: shad.background,
      appBarTheme: AppBarTheme(
        backgroundColor: shad.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: shad.foreground),
        titleTextStyle: TextStyle(
          color: shad.foreground,
          fontSize: AppType.title,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: shad.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: shad.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: shad.border, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: shad.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: shad.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: shad.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: shad.border),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(shad.muted),
        headingTextStyle: TextStyle(
          color: shad.foreground,
          fontSize: AppType.caption,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: TextStyle(color: shad.foreground, fontSize: AppType.caption),
        dividerThickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: shad.mutedForeground,
        textColor: shad.foreground,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: shad.primary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: shad.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: shad.input),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: shad.input),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: shad.ring, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: shad.primary,
          foregroundColor: shad.primaryForeground,
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: const Size(0, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: shad.foreground,
          side: BorderSide(color: shad.border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          minimumSize: const Size(0, 44),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: shad.primary),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? shad.primary : shad.input,
        ),
        thumbColor: WidgetStatePropertyAll(shad.primaryForeground),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, child) => ShadApp.custom(
        themeMode: AppThemeController.instance.mode,
        theme: _lightShadTheme,
        darkTheme: _darkShadTheme,
        appBuilder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          title: 'Student portal',
          themeMode: AppThemeController.instance.mode,
          // The Material theme is derived from the shadcn one, which already animates; lerping a
          // second full ThemeData every frame is what made the switch stutter.
          themeAnimationDuration: Duration.zero,
          theme: _lightMaterialTheme,
          darkTheme: _darkMaterialTheme,
          localizationsDelegates: const [
            GlobalShadLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          // A plain (non-animated) ShadTheme here shadows the one ShadApp lerps over 200ms, so the
          // screens below see the new theme at once and rebuild a single time.
          builder: (context, child) => MediaQuery(
            // Honour the phone's font size, but keep it in range (see AppType).
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(context).clamp(
                minScaleFactor: AppType.minTextScale,
                maxScaleFactor: AppType.maxTextScale,
              ),
            ),
            child: ShadTheme(
              data: AppThemeController.instance.isDark
                  ? _darkShadTheme
                  : _lightShadTheme,
              child: _ThemeSwitchFade(child: ShadAppBuilder(child: child!)),
            ),
          ),
          initialRoute: '/loading',
          routes: {
            '/loading': (context) => LoadingScreen(),
            '/login': (context) => LoginScreen(),
            '/home': (context) {
              final user = ModalRoute.of(context)!.settings.arguments as User?;
              if (user == null) {
                return LoginScreen();
              }
              return DashboardScreen(user: user);
            },
            '/notifications': (context) => NotificationsScreen(),
          },
        ),
      ),
    );
  }
}

/// Field surface shared by dropdowns and text inputs: a solid card-coloured pill with a visible
/// border and a soft shadow, so it reads on the tinted page instead of blending into it.
ShadDecoration _fieldDecoration(ShadColorScheme scheme, bool dark) {
  final pill = BorderRadius.circular(999);
  return ShadDecoration(
    color: scheme.card,
    border: ShadBorder.all(
      color: dark ? scheme.border : scheme.foreground.withValues(alpha: 0.18),
      width: 1,
      radius: pill,
    ),
    focusedBorder: ShadBorder.all(
      color: scheme.foreground,
      width: 1.5,
      radius: pill,
    ),
    secondaryFocusedBorder: ShadBorder.all(
      color: scheme.ring.withValues(alpha: 0.25),
      width: 4,
      radius: pill,
    ),
    shadows: dark
        ? null
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
  );
}

/// Every ShadSelect picks this up; do not restyle dropdowns per screen.
ShadSelectTheme _selectTheme(ShadColorScheme scheme, bool dark) =>
    ShadSelectTheme(
      decoration: _fieldDecoration(scheme, dark),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    );

/// Every ShadInput / ShadInputFormField picks this up.
ShadInputTheme _inputTheme(ShadColorScheme scheme, bool dark) => ShadInputTheme(
  decoration: _fieldDecoration(scheme, dark),
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
);

/// Circular reveal for the light/dark switch. Just before the theme flips, the current screen is
/// captured as one image and laid over the app; the new theme underneath is then uncovered by a
/// growing circle that starts at the toggle. Animating a single cached image is cheap, so the
/// motion stays smooth instead of re-lerping every widget's colours.
class _ThemeSwitchFade extends StatefulWidget {
  const _ThemeSwitchFade({required this.child});

  final Widget child;

  @override
  State<_ThemeSwitchFade> createState() => _ThemeSwitchFadeState();
}

class _ThemeSwitchFadeState extends State<_ThemeSwitchFade>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..addStatusListener(_onStatus);
  ui.Image? _snapshot;
  Offset _origin = Offset.zero;
  bool _wasDark = AppThemeController.instance.isDark;

  @override
  void initState() {
    super.initState();
    AppThemeController.instance.beforeChange = _capture;
    AppThemeController.instance.addListener(_onThemeChanged);
  }

  Future<void> _capture() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) return;
      final size = boundary.size;
      final origin = AppThemeController.instance.revealOrigin;
      _origin = origin ?? Offset(size.width - 40, 60);
      // 1x is plenty for a 0.5s animation and keeps the capture and GPU upload cheap.
      final image = await boundary.toImage(pixelRatio: 1.0);
      _snapshot?.dispose();
      _snapshot = image;
    } catch (_) {
      _snapshot = null;
    }
  }

  void _onThemeChanged() {
    final dark = AppThemeController.instance.isDark;
    if (dark == _wasDark) return;
    _wasDark = dark;
    if (_snapshot == null) return;
    _controller.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _snapshot?.dispose();
    setState(() => _snapshot = null);
  }

  @override
  void dispose() {
    final controller = AppThemeController.instance;
    controller.removeListener(_onThemeChanged);
    if (controller.beforeChange == _capture) controller.beforeChange = null;
    _controller.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (snapshot != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _RevealPainter(
                      image: snapshot,
                      center: _origin,
                      progress: Curves.easeInOutCubic.transform(
                        _controller.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Paints the old screen with a circular hole that grows from [center], uncovering the new theme.
class _RevealPainter extends CustomPainter {
  _RevealPainter({
    required this.image,
    required this.center,
    required this.progress,
  });

  final ui.Image image;
  final Offset center;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final farthest = [
      center.distance,
      (center - Offset(size.width, 0)).distance,
      (center - Offset(0, size.height)).distance,
      (center - Offset(size.width, size.height)).distance,
    ].reduce((a, b) => a > b ? a : b);
    final rect = Offset.zero & size;
    // Even-odd fill of (screen rect + circle) leaves a hole without a costly boolean path op.
    final clip = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addOval(Rect.fromCircle(center: center, radius: farthest * progress));
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.progress != progress || old.image != image || old.center != center;
}
