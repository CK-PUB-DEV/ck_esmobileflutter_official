import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pushtrial/config/theme_controller.dart';
import 'package:pushtrial/auth/login.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.instance.load();
  runApp(
    AnimatedBuilder(
      animation: AppThemeController.instance,
      builder: (context, child) => ShadApp.custom(
        themeMode: AppThemeController.instance.mode,
        theme: ShadThemeData(colorScheme: const ShadRedColorScheme.light()),
        darkTheme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadRedColorScheme.dark(),
        ),
        appBuilder: (context) => MaterialApp(
          theme: Theme.of(context),
          darkTheme: Theme.of(context),
          themeMode: AppThemeController.instance.mode,
          localizationsDelegates: const [
            GlobalShadLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (context, child) => ShadAppBuilder(child: child!),
          home: const LoginScreen(),
        ),
      ),
    ),
  );
}
