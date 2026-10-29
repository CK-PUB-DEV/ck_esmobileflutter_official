import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/user.dart';
import '../schools/api/school_api.dart';
import '../widgets/ui/ui.dart';
import 'dart:convert';

class LoadingScreen extends StatefulWidget {
  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _refreshSchoolVersion(SharedPreferences prefs) async {
    final schoolId = prefs.getInt('selectedSchoolId');
    if (schoolId == null) return;

    try {
      final response = await SchoolApi().getSchoolList();
      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List;
        final school = list.firstWhere(
          (s) => s['id'] == schoolId,
          orElse: () => null,
        );
        if (school != null) {
          final version = (school['system_version'] == 2) ? 'v2' : 'v1';
          await prefs.setString('schoolVersion', version);
        }
      }
    } catch (_) {
      // keep whatever version is already stored
    }
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    await _refreshSchoolVersion(prefs);

    if (!mounted) return;

    if (userJson != null) {
      final user = User.fromJson(jsonDecode(userJson));
      Navigator.pushReplacementNamed(context, '/home', arguments: user);
    } else {
      Navigator.pushReplacementNamed(context, '/schools');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
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
                color: theme.colorScheme.primary,
                borderRadius: theme.radius,
              ),
              child: Icon(
                LucideIcons.graduationCap,
                size: 32,
                color: theme.colorScheme.primaryForeground,
              ),
            ),
            Gap.hLg,
            Text('Essentiel', style: theme.textTheme.h4),
            Gap.hXs,
            Text('Student portal', style: theme.textTheme.muted),
            Gap.hXl,
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
