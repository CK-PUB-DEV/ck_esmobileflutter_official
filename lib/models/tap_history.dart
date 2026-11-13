// class TapHistory {
//   final int id;
//   final int studid;
//   final String tdate;
//   final String ttime;
//   final String tapstate;

//   TapHistory({
//     required this.id,
//     required this.studid,
//     required this.tdate,
//     required this.ttime,
//     required this.tapstate,
//   });

//   factory TapHistory.fromJson(Map<String, dynamic> json) {
//     return TapHistory(
//       id: json['id'] ?? 0,
//       studid: json['studid'] ?? 0,
//       tdate: json['tdate'] ?? '',
//       ttime: json['ttime'] ?? '',
//       tapstate: json['tapstate'] ?? '',
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'studid': studid,
//       'tdate': tdate,
//       'ttime': ttime,
//       'tapstate': tapstate,
//     };
//   }

//   @override
//   String toString() {
//     return 'TapHistory(id=$id, studid=$studid, tdate: $tdate, ttime: $ttime, tapstate: $tapstate)';
//   }
// }

import 'dart:convert';

int parseInt(dynamic value) {
  final jsonValue = jsonDecode(jsonEncode(value));
  return jsonValue is int ? jsonValue : int.tryParse(jsonValue.toString()) ?? 0;
}

class TapHistory {
  final int id;
  final int studid;
  final String tdate;
  final String ttime;
  final String tapstate;

  TapHistory({
    required this.id,
    required this.studid,
    required this.tdate,
    required this.ttime,
    required this.tapstate,
  });

  factory TapHistory.fromJson(Map<String, dynamic> json) {
    return TapHistory(
      id: parseInt(json['id']),
      studid: parseInt(json['studid']),
      tdate: json['tdate'] ?? '',
      ttime: json['ttime'] ?? '',
      tapstate: json['tapstate'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studid': studid,
      'tdate': tdate,
      'ttime': ttime,
      'tapstate': tapstate,
    };
  }

  @override
  String toString() {
    return 'TapHistory(id=$id, studid=$studid, tdate: $tdate, ttime: $ttime, tapstate: $tapstate)';
  }
}
