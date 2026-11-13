import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/school_info.dart';
import 'package:pushtrial/core/api/api.dart';

class SchoolUtils {
  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7 || hexString.length == 9) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

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

      final color = hexToColor(schoolInfo[0].schoolcolor);
      final picurl = schoolInfo[0].picurl;

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
