import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/shared/utils/school_utils.dart';
import 'package:pushtrial/shared/widgets/ui/ui.dart';
import 'dart:convert';

class LoadingScreen extends StatefulWidget {
  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _warmSchoolColor();
    _checkLoginStatus();
  }

  /// The splash and the screen after it use the school's own colour from the first frame.
  Future<void> _warmSchoolColor() async {
    await SchoolUtils.warmFromDisk();
    if (mounted) setState(() {});
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(Duration(seconds: 2));
    await SchoolUtils.warmFromDisk();

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (!mounted) return;

    if (userJson != null) {
      final user = User.fromJson(jsonDecode(userJson));
      Navigator.pushReplacementNamed(context, '/home', arguments: user);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    // The school's colour once known; the theme colour only for a school never opened before.
    final accent = SchoolUtils.lastColor ?? theme.colorScheme.primary;
    final onAccent = accent.computeLuminance() > 0.55
        ? const Color(0xFF111111)
        : Colors.white;
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(AppRadius.card - 8),
              ),
              child: Icon(
                LucideIcons.graduationCap,
                size: 32,
                color: onAccent,
              ),
            ),
            Gap.hLg,
            Text('Essentiel', style: theme.textTheme.h4),
            Gap.hXs,
            Text('Student portal', style: theme.textTheme.muted),
            Gap.hXl,
            Semantics(
              label: 'Loading',
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
