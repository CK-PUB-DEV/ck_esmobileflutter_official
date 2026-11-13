import 'dart:convert';

import 'package:pushtrial/models/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserDataLogin {
  static late SharedPreferences _preferences;
  static const _keyUser = 'userlogin';

  static Login myUserLogin = Login(
    id: 0,
    name: 'name',
    email: 'email',
    type: 0,
  );

  static Future init() async =>
      _preferences = await SharedPreferences.getInstance();

  static Future setUser(Login user) async {
    final json = jsonEncode(user.toJson());

    await _preferences.setString(_keyUser, json);
  }

  static Future<Login> getUser() async {
    _preferences = await SharedPreferences.getInstance();
    final json = _preferences.getString(_keyUser);

    return json == null ? myUserLogin : Login.fromJson(jsonDecode(json));
  }
}
