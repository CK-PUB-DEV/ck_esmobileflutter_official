import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pushtrial/api/auth_token.dart';
import 'package:pushtrial/push_notifications.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pushtrial/schools/screens/schools.dart';
import 'package:pushtrial/config/app_config.dart';
import 'package:pushtrial/config/theme_controller.dart';
import 'package:pushtrial/services/firebase_push.dart';
import 'package:pushtrial/services/school_alerts.dart';
import 'package:screen_protector/screen_protector.dart';
import '../models/user.dart';
import 'auth/login.dart';
import 'screens/loading.dart';
import 'screens/notifications.dart';
import 'screens/dashboard.dart';
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
  showDialog(
    context: navigatorKey.currentContext!,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text("Ok"),
        ),
      ],
    ),
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
      const SnackBar(content: Text('Your session ended. Please sign in again.')),
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
  // release builds stay protected.
  if (!kIsWeb && !kDebugMode) {
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

  /// shadcn text styles carry no colour of their own, so `textTheme.muted` would render as plain
  /// foreground text. Bake the muted colour in so every `muted` label really looks muted.
  ///
  /// shadcn's `small` also has a line height of 1, which crowds wrapped lines, so give it 1.4.
  ShadTextTheme _textTheme(ShadColorScheme scheme) => ShadTextTheme(
    muted: ShadTextDefaultTheme.muted(
      family: kDefaultFontFamily,
    ).copyWith(color: scheme.mutedForeground),
    small: ShadTextDefaultTheme.small(
      family: kDefaultFontFamily,
    ).copyWith(height: 1.4),
  );

  ThemeData _materialTheme(BuildContext context) {
    final base = Theme.of(context);
    final shad = ShadTheme.of(context).colorScheme;
    final dark = base.brightness == Brightness.dark;
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
          fontSize: 18,
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: TextStyle(color: shad.foreground, fontSize: 12),
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
        theme: ShadThemeData(
          brightness: Brightness.light,
          colorScheme: const ShadRedColorScheme.light(),
          textTheme: _textTheme(const ShadRedColorScheme.light()),
          radius: BorderRadius.circular(12),
        ),
        darkTheme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadRedColorScheme.dark(),
          textTheme: _textTheme(const ShadRedColorScheme.dark()),
          radius: BorderRadius.circular(12),
        ),
        appBuilder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          title: 'Student Portal',
          themeMode: AppThemeController.instance.mode,
          theme: _materialTheme(context),
          darkTheme: _materialTheme(context),
          localizationsDelegates: const [
            GlobalShadLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (context, child) => ShadAppBuilder(child: child!),
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
            '/schools': (context) => SchoolScreen(),
            '/notifications': (context) => NotificationsScreen(),
          },
        ),
      ),
    );
  }
}
