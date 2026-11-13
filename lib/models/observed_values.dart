// class RatingValues {
//   final int id;
//   final String sort;
//   final int gsid;
//   final String description;
//   final String value;

//   RatingValues({
//     required this.id,
//     required this.sort,
//     required this.gsid,
//     required this.description,
//     required this.value,
//   });

//   factory RatingValues.fromJson(Map<String, dynamic> json) {
//     return RatingValues(
//       id: json['id'] ?? 0,
//       sort: json['sort'] ?? '',
//       gsid: json['gsid'] ?? 0,
//       description: json['description'] ?? '',
//       value: json['value'] ?? '',
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'sort': sort,
//       'gsid': gsid,
//       'description': description,
//       'value': value,
//     };
//   }

//   @override
//   String toString() {
//     return 'ratingvalues(id: $id, sort: $sort, gsid: $gsid, description: $description, value: $value)';
//   }
// }

// class Setup {
//   final String description;
//   final int id;
//   final String group;
//   final String sort;
//   final int syid;
//   final int levelid;
//   final int headerid;
//   final int value;

//   Setup({
//     required this.description,
//     required this.id,
//     required this.group,
//     required this.sort,
//     required this.syid,
//     required this.levelid,
//     required this.headerid,
//     required this.value,
//   });

//   factory Setup.fromJson(Map<String, dynamic> json) {
//     return Setup(
//       description: json['description'] ?? '',
//       id: json['id'] ?? 0,
//       group: json['group'] ?? '',
//       sort: json['sort'] ?? '',
//       syid: json['syid'] ?? 0,
//       levelid: json['levelid'] ?? 0,
//       headerid: json['headerid'] ?? 0,
//       value: json['value'] ?? 0,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'description': description,
//       'id': id,
//       'group': group,
//       'sort': sort,
//       'syid': syid,
//       'levelid': levelid,
//       'headerid': headerid,
//       'value': value,
//     };
//   }

//   @override
//   String toString() {
//     return 'setup(description: $description, id: $id, group: $group, sort: $sort, syid: $syid, levelid: $levelid, headerid: $headerid, value: $value)';
//   }
// }

// class StudentObservedValues {
//   final int gsdid;
//   final int q1eval;
//   final int q2eval;
//   final int q3eval;
//   final int q4eval;

//   StudentObservedValues({
//     required this.gsdid,
//     required this.q1eval,
//     required this.q2eval,
//     required this.q3eval,
//     required this.q4eval,
//   });

//   factory StudentObservedValues.fromJson(Map<String, dynamic> json) {
//     return StudentObservedValues(
//       gsdid: json['gsdid'] ?? 0,
//       q1eval: json['q1eval'] ?? 0,
//       q2eval: json['q2eval'] ?? 0,
//       q3eval: json['q3eval'] ?? 0,
//       q4eval: json['q4eval'] ?? 0,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'gsdid': gsdid,
//       'q1eval': q1eval,
//       'q2eval': q2eval,
//       'q3eval': q3eval,
//       'q4eval': q4eval,
//     };
//   }

//   @override
//   String toString() {
//     return 'studentobservedvalues(gsdid: $gsdid, q1eval: $q1eval, q2eval: $q2eval, q3eval: $q3eval, q4eval: $q4eval)';
//   }
// }

import 'dart:convert';

int parseInt(dynamic value) {
  final jsonValue = jsonDecode(jsonEncode(value));
  return jsonValue is int ? jsonValue : int.tryParse(jsonValue.toString()) ?? 0;
}

class RatingValues {
  final int id;
  final String sort;
  final int gsid;
  final String description;
  final String value;

  RatingValues({
    required this.id,
    required this.sort,
    required this.gsid,
    required this.description,
    required this.value,
  });

  factory RatingValues.fromJson(Map<String, dynamic> json) {
    return RatingValues(
      id: parseInt(json['id']),
      sort: json['sort'] ?? '',
      gsid: parseInt(json['gsid']),
      description: json['description'] ?? '',
      value: json['value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sort': sort,
      'gsid': gsid,
      'description': description,
      'value': value,
    };
  }

  @override
  String toString() {
    return 'ratingvalues(id: $id, sort: $sort, gsid: $gsid, description: $description, value: $value)';
  }
}

class Setup {
  final String description;
  final int id;
  final String group;
  final String sort;
  final int syid;
  final int levelid;
  final int headerid;
  final int value;

  Setup({
    required this.description,
    required this.id,
    required this.group,
    required this.sort,
    required this.syid,
    required this.levelid,
    required this.headerid,
    required this.value,
  });

  factory Setup.fromJson(Map<String, dynamic> json) {
    return Setup(
      description: json['description'] ?? '',
      id: parseInt(json['id']),
      group: json['group'] ?? '',
      sort: json['sort'] ?? '',
      syid: parseInt(json['syid']),
      levelid: parseInt(json['levelid']),
      headerid: parseInt(json['headerid']),
      value: parseInt(json['value']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'id': id,
      'group': group,
      'sort': sort,
      'syid': syid,
      'levelid': levelid,
      'headerid': headerid,
      'value': value,
    };
  }

  @override
  String toString() {
    return 'setup(description: $description, id: $id, group: $group, sort: $sort, syid: $syid, levelid: $levelid, headerid: $headerid, value: $value)';
  }
}

class StudentObservedValues {
  final int gsdid;
  final int q1eval;
  final int q2eval;
  final int q3eval;
  final int q4eval;

  StudentObservedValues({
    required this.gsdid,
    required this.q1eval,
    required this.q2eval,
    required this.q3eval,
    required this.q4eval,
  });

  factory StudentObservedValues.fromJson(Map<String, dynamic> json) {
    return StudentObservedValues(
      gsdid: parseInt(json['gsdid']),
      q1eval: parseInt(json['q1eval']),
      q2eval: parseInt(json['q2eval']),
      q3eval: parseInt(json['q3eval']),
      q4eval: parseInt(json['q4eval']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gsdid': gsdid,
      'q1eval': q1eval,
      'q2eval': q2eval,
      'q3eval': q3eval,
      'q4eval': q4eval,
    };
  }

  @override
  String toString() {
    return 'studentobservedvalues(gsdid: $gsdid, q1eval: $q1eval, q2eval: $q2eval, q3eval: $q3eval, q4eval: $q4eval)';
  }
}
