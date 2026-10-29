// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:io';

// class CallApi {
//   final String _mainDomain = "https://app-ldcu.essentiel.ph/";
//   // final String _mainDomain = "http://192.168.50.13:8000/";
//   // final String _mainDomain = "https://assure.essentiel.ph/";

//   final String _esDomain = "api/mobile/api_login";
//   final String _enrollmentInfo = "api/mobile/api_enrollmentinfo";
//   final String _enrollmentData = "api/mobile/api_enrollmentdata";
//   final String _billingInfo = "/api/mobile/api_billinginfo";
//   final String _studLedger = "/api/mobile/api_studledger";
//   final String _picUrl = "api/mobile/api_picurl";
//   final String _sf9Attendance = "api/mobile/api_sf9attendance";
//   final String _studGrade = "api/mobile/api_getgrade";
//   final String _getSchedule = "api/mobile/api_getschedule";
//   final String _events = "/api/mobile/api_get_events";
//   final String _attendance = "api/mobile/student_attendance";
//   final String _studeObservedValues = "api/mobile/student_observedvalues";
//   final String _schoolinfo = "api/mobile/schoolinfo";

//   final String _updatePushStatus = "api/mobile/api_update_pushstatus";
//   final String _transactions = "api/mobile/api_get_transactions";
//   final String _saveToken = "api/mobile/api_save_fcmtoken";
//   final String _deleteToken = "api/mobile/deleteFcmToken";
//   final String _onlinePaymentsOptions =
//       "api/mobile/api_get_onlinepaymentoptions";
//   final String _sendPayment = "api/mobile/api_send_payment";
//   final String _onlinePayments = "api/mobile/api_get_onlinepayments";
//   final String _smsBunker = "api/mobile/api_get_smsbunker";
//   final String _reportCardBE = "/api/mobile/api_enrollment_reportcard";
//   final String _studentAttendance = "/api/mobile/api_attendance";
//   final String _observedValues = "/api/mobile/api_observedvalues";
//   final String _scholarshipSetup = "/api/mobile/api_getscholarshipsetup";
//   final String _scholarhip = "/api/mobile/api_getscholarship";
//   final String _requirement = "/api/mobile/api_getrequirement";
//   final String _deleteScholarship = "/api/mobile/api_delscholarship";

//   getDeleteScholarship(id) async {
//     var fullUrl = '$_mainDomain$_deleteScholarship?id=$id';
//     return await http.post(
//       Uri.parse(fullUrl),
//     );
//   }

//   getRequirement(id) async {
//     var fullUrl = '$_mainDomain$_requirement?id=$id';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getScholarshipSetup() async {
//     var fullUrl = '$_mainDomain$_scholarshipSetup';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getScholarship(studid) async {
//     var fullUrl = '$_mainDomain$_scholarhip?studid=$studid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getObservedValues(studid) async {
//     var fullUrl = '$_mainDomain$_observedValues?studid=$studid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getStudentAttendance(studid) async {
//     var fullUrl = '$_mainDomain$_studentAttendance?studid=$studid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getReportCardBE(studid, syid) async {
//     var fullUrl = '$_mainDomain$_reportCardBE?studid=$studid&syid=$syid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getSchoolInfo() async {
//     var fullUrl = '$_mainDomain$_schoolinfo';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getSmsBunker(studid) async {
//     var fullUrl = '$_mainDomain$_smsBunker?studid=$studid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getOnlinePayments(sid) async {
//     var fullUrl = '$_mainDomain$_onlinePayments?sid=$sid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   Future<http.StreamedResponse> getSendPayment(
//     String studid,
//     String paymentType,
//     String amount,
//     String transDate,
//     String refNum,
//     String opcontact,
//     String syid,
//     String semid,
//     File? receiptImageFile,
//   ) async {
//     var fullUrl = Uri.parse('$_mainDomain$_sendPayment');

//     var request = http.MultipartRequest('POST', fullUrl);

//     request.fields['studid'] = studid;
//     request.fields['paymentType'] = paymentType;
//     request.fields['amount'] = amount;
//     request.fields['transDate'] = transDate;
//     request.fields['refNum'] = refNum;
//     request.fields['opcontact'] = opcontact;
//     request.fields['syid'] = syid;
//     request.fields['semid'] = semid;

//     if (receiptImageFile != null) {
//       request.files.add(await http.MultipartFile.fromPath(
//         'recieptImage',
//         receiptImageFile.path,
//       ));
//     }

//     return await request.send();
//   }

//   getOnlinePaymentsOptions(id) async {
//     var fullUrl = '$_mainDomain$_onlinePaymentsOptions?id=$id';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getDeleteToken(studid, type, fcmtoken) async {
//     var fullUrl =
//         '$_mainDomain$_deleteToken?studid=$studid&type=$type&fcmtoken=$fcmtoken';
//     return await http.post(
//       Uri.parse(fullUrl),
//     );
//   }

//   getSaveToken(int studid, int type, String fcmtoken) async {
//     var fullUrl =
//         '$_mainDomain$_saveToken?studid=$studid&type=$type&fcmtoken=$fcmtoken';
//     return await http.post(
//       Uri.parse(fullUrl),
//     );
//   }

//   getUpdatePushStatus(id, studid, pushstatus) async {
//     var fullUrl =
//         '$_mainDomain$_updatePushStatus?id=$id&studid=$studid&pushstatus=$pushstatus';
//     return await http.post(
//       Uri.parse(fullUrl),
//     );
//   }

//   getTransactions(studid) async {
//     var fullUrl = '$_mainDomain$_transactions?studid=$studid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getAttendance(
//     studid,
//     syid,
//     levelid,
//   ) async {
//     var fullUrl =
//         '$_mainDomain$_attendance?studid=$studid&syid=$syid&levelid=$levelid&semid=1';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getStudentObservedValues(syid, studid, levelid) async {
//     var fullUrl =
//         '$_mainDomain$_studeObservedValues?syid=$syid&studid=$studid&levelid=$levelid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getEvents(syid) async {
//     var fullUrl = '$_mainDomain$_events?syid=$syid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getStudGrade(studid, gradelevel, syid, sectionid, strand, semid) async {
//     var fullUrl =
//         '$_mainDomain$_studGrade?studid=$studid&gradelevel=$gradelevel&syid=$syid&sectionid=$sectionid&strand=$strand&semid=$semid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getPicURL(studid) async {
//     var fullUrl = '$_mainDomain$_picUrl?studid=$studid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getSF9Attendance(studid, syid, gradelevel, sectionid, strand) async {
//     var fullUrl =
//         '$_mainDomain$_sf9Attendance?studid=$studid&syid=$syid&gradelevel=$gradelevel&sectionid=$sectionid&strand=$strand';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getStudLedger(studid, syid, semid) async {
//     var fullUrl =
//         '$_mainDomain$_studLedger?studid=$studid&syid=$syid&semid=$semid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getEnrollmentInfo(studid) async {
//     var fullUrl = '$_mainDomain$_enrollmentInfo?studid=$studid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getEnrollmentData(studid, syid, semid) async {
//     var fullUrl =
//         '$_mainDomain$_enrollmentData?studid=$studid&syid=$syid&semid=$semid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getBillingInfo(String studid) async {
//     var fullUrl =
//         '$_mainDomain$_billingInfo?studid=$studid&syid=1&semid=1&monthid=10';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getSchedule(
//     studid,
//     syid,
//     semid,
//     sectionid,
//     levelid,
//   ) async {
//     var fullUrl =
//         '$_mainDomain$_getSchedule?studid=$studid&syid=$syid&semid=$semid&sectionid=$sectionid&levelid=$levelid';
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }

//   getImage() {
//     return _mainDomain;
//   }

//   postData(data, apiUrl) async {}

//   login(username, pword) async {
//     var fullUrl = '$_mainDomain$_esDomain?&username=$username&pword=$pword';
//     return await http.get(Uri.parse(fullUrl));
//   }

//   getToken() async {
//     SharedPreferences localStorage = await SharedPreferences.getInstance();
//     var token = localStorage.getString('token');
//     print('Retrieved token: $token');
//     return token;
//   }

//   getDomain() async {
//     return _mainDomain;
//   }

//   getPublicData(apiUrl) async {
//     var fullUrl = _esDomain + apiUrl;
//     return await http.get(
//       Uri.parse(fullUrl),
//     );
//   }
// }

import 'package:pushtrial/api/authed_http.dart' as http;
import 'package:pushtrial/api/auth_token.dart';
import 'package:pushtrial/api/api_version.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'dart:convert';

class CallApi {
  String? _mainDomain = '';

  /// True when this school's server has the v2 API (see ApiVersion). Set by
  /// [_ensureDomainInitialized], which every request awaits first; false (v1) until known, which
  /// works on every server.
  bool _v2 = false;

  /// An endpoint's address for the version in use. v1 keeps the address exactly as it was; v2 puts
  /// `v2/` after `api/mobile/` (the server carries these endpoints over unchanged).
  String _p(String path) {
    if (!_v2) return path;
    final lead = path.startsWith('/') ? '/' : '';
    return '${lead}api/mobile/v2/${path.replaceFirst(RegExp(r'^/?api/mobile/'), '')}';
  }

  // v1 only (never carried to v2): the login's v1 form, the older push-status, SMS and push-token
  // endpoints, used only against a server that has no v2.
  final String _esDomain = "api/mobile/api_login";
  String get _enrollmentInfo => _p("/api/mobile/api_enrollmentinfo");
  String get _enrollmentData => _p("/api/mobile/api_enrollmentdata");
  String get _studLedger => _p("/api/mobile/api_studledger");
  String get _picUrl => _p("/api/mobile/api_picurl");
  String get _sf9Attendance => _p("api/mobile/api_sf9attendance");
  String get _studGrade => _p("/api/mobile/api_getgrade");
  String get _getSchedule => _p("/api/mobile/api_getschedule");
  String get _events => _p("/api/mobile/api_get_events");
  String get _attendance => _p("/api/mobile/student_attendance");
  String get _studeObservedValues => _p("/api/mobile/student_observedvalues");
  String get _schoolinfo => _p("/api/mobile/schoolinfo");

  final String _updatePushStatus = "/api/mobile/api_update_pushstatus";
  String get _transactions => _p("/api/mobile/api_get_transactions");
  final String _saveToken = "/api/mobile/api_save_fcmtoken";
  String get _deleteToken => _p("/api/mobile/deleteFcmToken");
  String get _onlinePaymentsOptions =>
      _p("/api/mobile/api_get_onlinepaymentoptions");
  String get _sendPayment => _p("/api/mobile/api_send_payment");
  String get _onlinePayments => _p("/api/mobile/api_get_onlinepayments");
  final String _smsBunker = "/api/mobile/api_get_smsbunker";
  String get _reportCardBE => _p("/api/mobile/api_enrollment_reportcard");
  String get _studentAttendance => _p("/api/mobile/api_attendance");
  String get _observedValues => _p("/api/mobile/api_observedvalues");
  String get _scholarshipSetup => _p("/api/mobile/api_getscholarshipsetup");
  String get _scholarhip => _p("/api/mobile/api_getscholarship");
  String get _requirement => _p("/api/mobile/api_getrequirement");
  String get _deleteScholarship => _p("/api/mobile/api_delscholarship");
  String get _saveScholarship => _p("/api/mobile/api_savescholarship");
  String get _uploadRequirement => _p("/api/mobile/api_uploadrequirement");
  String get _yearSem => _p("/api/mobile/api_sysem");
  String get _enrolledStud => _p("/api/mobile/api_enrolledstud");
  String get _tapHistory => _p("/api/mobile/api_get_taphistory");

  CallApi() {
    _initializeMainDomain();
    _ensureDomainInitialized();
  }

  Future<void> _initializeMainDomain() async {
    final prefs = await SharedPreferences.getInstance();
    _mainDomain = prefs.getString('selectedSchool');
  }

  Future<void> _ensureDomainInitialized() async {
    if (_mainDomain == null || _mainDomain!.isEmpty) {
      await _initializeMainDomain();
      if (_mainDomain == null) {
        print('Main domain not initialized');
      }
    }
    // Which version of the API this school's server speaks: asked once per school per run. Unknown
    // (offline and never answered) stays on v1, which every server has.
    final domain = _mainDomain;
    if (domain != null && domain.isNotEmpty) {
      _v2 = (await ApiVersion.of(domain)) == 2;
    }
  }

  getUploadRequirement(file) async {
    await _ensureDomainInitialized();
    var url = '$_mainDomain$_uploadRequirement';

    Dio dio = Dio();

    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path,
          filename: file.path.split('/').last),
    });

    await AuthToken.ensureLoaded();
    var response = await dio.post(
      url,
      data: formData,
      options: Options(headers: AuthToken.headersFor(Uri.parse(url))),
    );
    return response;
  }

  getSaveScholarship(int scholarshipId, int semesterId, int studId,
      List<Map<String, dynamic>> requirementsArray, String remarks) async {
    await _ensureDomainInitialized();
    var url = '$_mainDomain$_saveScholarship';

    Map<String, dynamic> data = {
      'scholarship_id': scholarshipId.toString(),
      'semesterid': semesterId.toString(),
      'studid': studId.toString(),
      'requirementsArray': jsonEncode(requirementsArray),
      'remarks': remarks
    };

    return await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
  }

  getEnrolledStud(studid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_enrolledStud?studid=$studid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getYearandSem() async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_yearSem';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getDeleteScholarship(id) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_deleteScholarship?id=$id';
    return await http.post(
      Uri.parse(fullUrl),
    );
  }

  getRequirement(id) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_requirement?id=$id';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getScholarshipSetup() async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_scholarshipSetup';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getScholarship(studid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_scholarhip?studid=$studid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getObservedValues(studid, syid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_observedValues?studid=$studid&syid=$syid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getStudentAttendance(studid, syid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_studentAttendance?studid=$studid&syid=$syid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getReportCardBE(studid, syid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_reportCardBE?studid=$studid&syid=$syid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getSchoolInfo() async {
    await _ensureDomainInitialized();
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_schoolinfo';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getSmsBunker(studid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_smsBunker?studid=$studid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  /// Messages sent to this person's phone number in the last [days] days, for the Notifications
  /// page. [type] is the login type: 9 = parent, otherwise student.
  getMessages(studid, type, {int days = 30}) async {
    await _ensureDomainInitialized();
    // Only a v2 server has this. Callers that may meet a v1 server use MessagesRepository.
    var fullUrl = '${_mainDomain}api/mobile/v2/messages?studid=$studid&type=$type&days=$days';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getOnlinePayments(sid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_onlinePayments?sid=$sid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  Future<http.StreamedResponse> getSendPayment(
    String studid,
    String paymentType,
    String amount,
    String transDate,
    String refNum,
    String opcontact,
    String syid,
    String semid,
    File? receiptImageFile,
  ) async {
    await _ensureDomainInitialized();
    var fullUrl = Uri.parse('$_mainDomain$_sendPayment');

    var request = http.MultipartRequest('POST', fullUrl);

    request.fields['studid'] = studid;
    request.fields['paymentType'] = paymentType;
    request.fields['amount'] = amount;
    request.fields['transDate'] = transDate;
    request.fields['refNum'] = refNum;
    request.fields['opcontact'] = opcontact;
    request.fields['syid'] = syid;
    request.fields['semid'] = semid;

    if (receiptImageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'recieptImage',
        receiptImageFile.path,
      ));
    }

    return await request.send();
  }

  getOnlinePaymentsOptions(id) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_onlinePaymentsOptions?id=$id';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getDeleteToken(studid, type, fcmtoken) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain$_deleteToken?studid=$studid&type=$type&fcmtoken=$fcmtoken';
    return await http.post(
      Uri.parse(fullUrl),
    );
  }

  getSaveToken(int studid, int type, String fcmtoken) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain$_saveToken?studid=$studid&type=$type&fcmtoken=$fcmtoken';
    return await http.post(
      Uri.parse(fullUrl),
    );
  }

  getUpdatePushStatus(id, studid, pushstatus) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain$_updatePushStatus?id=$id&studid=$studid&pushstatus=$pushstatus';
    return await http.post(
      Uri.parse(fullUrl),
    );
  }

  getTransactions(studid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_transactions?studid=$studid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getAttendance(
    studid,
    syid,
    levelid,
  ) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain$_attendance?studid=$studid&syid=$syid&levelid=$levelid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getStudentObservedValues(syid, studid, levelid) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain$_studeObservedValues?syid=$syid&studid=$studid&levelid=$levelid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getEvents(syid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_events?syid=$syid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getTapHistory(studid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_tapHistory?studid=$studid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getStudGrade(studid, gradelevel, syid, sectionid, strand, semid) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain$_studGrade?studid=$studid&gradelevel=$gradelevel&syid=$syid&sectionid=$sectionid&strand=$strand&semid=$semid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getPicURL(studid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_picUrl?studid=$studid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getSF9Attendance(studid, syid, gradelevel, sectionid, strand) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain$_sf9Attendance?studid=$studid&syid=$syid&gradelevel=$gradelevel&sectionid=$sectionid&strand=$strand';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getStudLedger(studid, syid, semid) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain$_studLedger?studid=$studid&syid=$syid&semid=$semid';
        print('fullUrl: $fullUrl');
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getV2ClassSchedule(studid, syid, semid) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain${_p('api/mobile/api_class_schedule_v2')}?studid=$studid&syid=$syid&semid=$semid&type=today';
    print('V2 class schedule url: $fullUrl');
    return await http.get(Uri.parse(fullUrl));
  }

  /// Grading periods of a grade level (quarters, terms...). Only v2 servers have it: null on v1.
  getGradingSetup(syid, levelid) async {
    await _ensureDomainInitialized();
    if (!_v2) return null;
    return await http.get(
      Uri.parse('$_mainDomain${_p('api/mobile/grading_setup')}?syid=$syid&levelid=$levelid'),
    );
  }

  getV2ReportCard(studid, syid, semid) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain${_p('api/mobile/api_reportcard_v2')}?studid=$studid&syid=$syid&semid=$semid&type=today';
    print('V2 report card url: $fullUrl');
    return await http.get(Uri.parse(fullUrl));
  }

  getV2StudLedger(studid, syid, semid) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain${_p('api/mobile/api_student_ledger_v2')}?studid=$studid&syid=$syid&semid=$semid';
    print('V2 ledger url: $fullUrl');
    return await http.get(Uri.parse(fullUrl));
  }

  getEnrollmentInfo(studid) async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain$_enrollmentInfo?studid=$studid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getEnrollmentData(studid, syid, semid) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain$_enrollmentData?studid=$studid&syid=$syid&semid=$semid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getSchedule(
    studid,
    syid,
    semid,
    sectionid,
    levelid,
  ) async {
    await _ensureDomainInitialized();
    var fullUrl =
        '$_mainDomain$_getSchedule?studid=$studid&syid=$syid&semid=$semid&sectionid=$sectionid&levelid=$levelid';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  // getImage() async {
  //   return _mainDomain;
  // }

  Future<String?> getImage() async {
    if (_mainDomain == null) {
      await _ensureDomainInitialized();
    }
    return _mainDomain;
  }

  postData(data, apiUrl) async {}

  /// Signs in. Against a v2 server the credentials go in a POST body, never in the address, so they
  /// don't end up in a server's access log or a proxy. A server that hasn't been updated has only
  /// the original v1 login, which takes them in the address; that is the only form it understands.
  login(username, pword) async {
    await _ensureDomainInitialized();

    if (_v2) {
      return await http.post(
        Uri.parse('${_mainDomain}api/mobile/v2/login'),
        headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'username': username, 'pword': pword}),
      );
    }
    final v1 = Uri.parse('$_mainDomain$_esDomain')
        .replace(queryParameters: {'username': username, 'pword': pword});
    return await http.get(v1);
  }

  getToken() async {
    await _ensureDomainInitialized();
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    var token = localStorage.getString('token');
    print('Retrieved token: $token');
    return token;
  }

  getDomain() async {
    await _ensureDomainInitialized();
    var fullUrl = '$_mainDomain';
    return fullUrl;
  }

  getPublicData(apiUrl) async {
    await _ensureDomainInitialized();
    var fullUrl = _esDomain + apiUrl;
    return await http.get(
      Uri.parse(fullUrl),
    );
  }
}
