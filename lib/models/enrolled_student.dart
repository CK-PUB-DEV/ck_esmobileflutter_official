// class EnrolledStud {
//   final int id;
//   final int studid;
//   final int syid;
//   final int semid;
//   final String dateenrolled;
//   final int levelid;
//   final int sectionid;
//   final int strandid;
//   final int studstatus;
//   final String levelname;
//   final String strandname;
//   final String description;
//   final String courseDesc;
//   final String semester;
//   final String sectionname;
//   final String sydesc;

//   EnrolledStud({
//     required this.id,
//     required this.studid,
//     required this.syid,
//     required this.semid,
//     required this.dateenrolled,
//     required this.levelid,
//     required this.sectionid,
//     required this.strandid,
//     required this.studstatus,
//     required this.levelname,
//     required this.strandname,
//     required this.description,
//     required this.courseDesc,
//     required this.semester,
//     required this.sectionname,
//     required this.sydesc,
//   });

//   factory EnrolledStud.fromJson(Map<String, dynamic> json) {
//     return EnrolledStud(
//       id: json['id'] ?? 0,
//       studid: json['studid'] ?? 0,
//       syid: json['syid'] ?? 0,
//       semid: json['semid'] ?? 0,
//       dateenrolled: json['dateenrolled'] ?? '',
//       levelid: json['levelid'] ?? 0,
//       sectionid: json['sectionid'] ?? 0,
//       strandid: json['strandid'] ?? 0,
//       studstatus: json['studstatus'] ?? 0,
//       levelname: json['levelname'] ?? '',
//       strandname: json['strandname'] ?? '',
//       description: json['description'] ?? '',
//       courseDesc: json['courseDesc'] ?? '',
//       semester: json['semester'] ?? '',
//       sectionname: json['sectionname'] ?? '',
//       sydesc: json['sydesc'] ?? '',
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'studid': studid,
//       'syid': syid,
//       'semid': semid,
//       'dateenrolled': dateenrolled,
//       'levelid': levelid,
//       'sectionid': sectionid,
//       'strandid': strandid,
//       'studstatus': studstatus,
//       'levelname': levelname,
//       'strandname': strandname,
//       'description': description,
//       'courseDesc': courseDesc,
//       'semester': semester,
//       'sectionname': sectionname,
//       'sydesc': sydesc
//     };
//   }

//   @override
//   String toString() {
//     return 'EnrolledStud{id: $id, studid: $studid, syid: $syid, semid: $semid, dateenrolled: $dateenrolled, levelid: $levelid, sectionid: $sectionid, strandid: $strandid, studstatus: $studstatus, levelname: $levelname, strandname: $strandname, description: $description, courseDesc: $courseDesc, semester: $semester, sectionname: $sectionname, sydesc: $sydesc}';
//   }
// }

import 'dart:convert';

int parseInt(dynamic value) {
  final jsonValue = jsonDecode(jsonEncode(value));
  return jsonValue is int ? jsonValue : int.tryParse(jsonValue.toString()) ?? 0;
}

class EnrolledStud {
  final int id;
  final int studid;
  final int syid;
  final int semid;
  final String dateenrolled;
  final int levelid;
  final int sectionid;
  final int strandid;
  final int studstatus;
  final String levelname;
  final String strandname;
  final String description;
  final String courseDesc;
  final String semester;
  final String sectionname;
  final String sydesc;

  EnrolledStud({
    required this.id,
    required this.studid,
    required this.syid,
    required this.semid,
    required this.dateenrolled,
    required this.levelid,
    required this.sectionid,
    required this.strandid,
    required this.studstatus,
    required this.levelname,
    required this.strandname,
    required this.description,
    required this.courseDesc,
    required this.semester,
    required this.sectionname,
    required this.sydesc,
  });

  factory EnrolledStud.fromJson(Map<String, dynamic> json) {
    return EnrolledStud(
      id: parseInt(json['id']),
      studid: parseInt(json['studid']),
      syid: parseInt(json['syid']),
      semid: parseInt(json['semid']),
      dateenrolled: json['dateenrolled'] ?? '',
      levelid: parseInt(json['levelid']),
      sectionid: parseInt(json['sectionid']),
      strandid: parseInt(json['strandid']),
      studstatus: parseInt(json['studstatus']),
      levelname: json['levelname'] ?? '',
      strandname: json['strandname'] ?? '',
      description: json['description'] ?? '',
      courseDesc: json['courseDesc'] ?? '',
      semester: json['semester'] ?? '',
      sectionname: json['sectionname'] ?? '',
      sydesc: json['sydesc'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studid': studid,
      'syid': syid,
      'semid': semid,
      'dateenrolled': dateenrolled,
      'levelid': levelid,
      'sectionid': sectionid,
      'strandid': strandid,
      'studstatus': studstatus,
      'levelname': levelname,
      'strandname': strandname,
      'description': description,
      'courseDesc': courseDesc,
      'semester': semester,
      'sectionname': sectionname,
      'sydesc': sydesc
    };
  }

  @override
  String toString() {
    return 'EnrolledStud{id: $id, studid: $studid, syid: $syid, semid: $semid, dateenrolled: $dateenrolled, levelid: $levelid, sectionid: $sectionid, strandid: $strandid, studstatus: $studstatus, levelname: $levelname, strandname: $strandname, description: $description, courseDesc: $courseDesc, semester: $semester, sectionname: $sectionname, sydesc: $sydesc}';
  }
}
