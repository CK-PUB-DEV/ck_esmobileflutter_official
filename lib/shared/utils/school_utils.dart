import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/core/api/api.dart';

class SchoolUtils {
  /// The colour of the school the user is logged in to. It is never hard-coded: it comes from
  /// that school's own info (`schoolcolor`), is remembered per school domain, and screens fall
  /// back to the theme colour while it is unknown. Do not default a screen to a brand colour.
  static Color? lastColor;
  static String? _colorDomain;

  static String _colorKey(String domain) => 'schoolColor:$domain';

  /// Parses `#RGB`, `#RRGGBB` or `#AARRGGBB` (the `#` is optional). Null when empty, malformed or
  /// fully transparent, so callers can fall back instead of showing a wrong colour.
  static Color? parseColor(String? raw) {
    var hex = (raw ?? '').trim().replaceFirst('#', '');
    if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8 || !RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(hex)) return null;
    final color = Color(int.parse(hex, radix: 16));
    return color.a == 0 ? null : color;
  }

  /// Forget the remembered colour. Call when the school changes or the user logs out, so the
  /// next school never shows the previous school's colour.
  static void reset() {
    lastColor = null;
    _colorDomain = null;
  }

  /// Keeps [color] as the current school's colour, in memory and on disk under that school.
  static Future<void> remember(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final domain = prefs.getString('selectedSchool');
    if (domain == null || domain.isEmpty) return;
    lastColor = color;
    _colorDomain = domain;
    await prefs.setString(_colorKey(domain), '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}');
  }

  /// The logged-in school's colour, or null when unknown (use the theme colour then).
  /// Served from memory or disk for the current school; fetched once when neither has it.
  static Future<Color?> schoolColor({bool refresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final domain = prefs.getString('selectedSchool');
    if (domain == null || domain.isEmpty) return null;
    if (_colorDomain != domain) {
      lastColor = parseColor(prefs.getString(_colorKey(domain)));
      _colorDomain = domain;
    }
    if (lastColor != null && !refresh) return lastColor;
    try {
      await getSchoolInfoData();
    } catch (_) {
      // Callers fall back to the theme colour.
    }
    return lastColor;
  }

  static Color hexToColor(String hexString) =>
      parseColor(hexString) ?? const Color.fromARGB(0, 0, 0, 0);

  static Future<String?> getSchool() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selectedSchool');
  }

  static Future<String?> loadSelectedSchool() async {
    String? selectedSchool = await getSchool();
    if (selectedSchool != null) {
      print('Loaded school eslink: $selectedSchool');
    } else {
      print('No school found in preferences.');
    }
    return selectedSchool;
  }

  static Future<Map<String, dynamic>> getSchoolInfoData() async {
    final response = await CallApi().getSchoolInfo();
    final parsedResponse = json.decode(response.body);

    if (parsedResponse is List) {
      final schoolInfo = parsedResponse
          .map((model) => SchoolInfo.fromJson(model))
          .toList()
          .cast<SchoolInfo>();

      final parsed = parseColor(schoolInfo[0].schoolcolor);
      final color = parsed ?? const Color.fromARGB(0, 0, 0, 0);
      final picurl = schoolInfo[0].picurl;
      if (parsed != null) await remember(parsed);

      return {'schoolColor': color, 'picurl': picurl, 'schoolInfo': schoolInfo};
    } else {
      return {
        'schoolColor': const Color.fromARGB(0, 0, 0, 0),
        'picurl': null,
        'schoolInfo': [],
      };
    }
  }
}
