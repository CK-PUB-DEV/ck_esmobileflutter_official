// class Payments {
//   final int id;
//   final String queingcode;
//   final int paymentType;
//   final String picUrl;
//   final String amount;
//   final int isapproved;
//   final String paymentDate;
//   final String refNum;
//   String? bankName;
//   final String TransDate;
//   int? updatedby;
//   int? chrngtransid;
//   final int syid;
//   final int semid;
//   final String opcontact;
//   final String description;

//   Payments({
//     required this.id,
//     required this.queingcode,
//     required this.paymentType,
//     required this.picUrl,
//     required this.isapproved,
//     required this.amount,
//     required this.paymentDate,
//     required this.refNum,
//     this.bankName,
//     required this.TransDate,
//     required this.updatedby,
//     required this.chrngtransid,
//     required this.syid,
//     required this.semid,
//     required this.opcontact,
//     required this.description,
//   });

//   factory Payments.fromJson(Map<String, dynamic> json) {
//     return Payments(
//       id: json['id'] ?? 0,
//       queingcode: json['queingcode'] ?? '',
//       paymentType: json['paymentType'] ?? 0,
//       picUrl: json['picUrl'] ?? '',
//       amount: json['amount'] ?? '',
//       isapproved: json['isapproved'] ?? 0,
//       paymentDate: json['paymentDate'] ?? '',
//       refNum: json['refNum'] ?? '',
//       bankName: json['bankName'] ?? '',
//       TransDate: json['TransDate'] ?? '',
//       updatedby: json['updatedby'] ?? 0,
//       chrngtransid: json['chrngtransid'] ?? 0,
//       syid: json['syid'] ?? 0,
//       semid: json['semid'] ?? 0,
//       opcontact: json['opcontact'] ?? '',
//       description: json['description'] ?? '',
//     );
//   }

//   String getStatus() {
//     switch (isapproved) {
//       case 0:
//         return 'On Process';
//       case 1:
//         return 'Approved';
//       case 2:
//         return 'Not Approved';
//       case 3:
//         return 'Canceled';
//       case 5:
//         return 'Processed';
//       default:
//         return 'Unknown';
//     }
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'queingcode': queingcode,
//       'paymentType': paymentType,
//       'picUrl': picUrl,
//       'amount': amount,
//       'isapproved': isapproved,
//       'paymentDate': paymentDate,
//       'refNum': refNum,
//       'bankName': bankName,
//       'TransDate': TransDate,
//       'updatedby': updatedby,
//       'chrngtransid': chrngtransid,
//       'syid': syid,
//       'semid': semid,
//       'opcontact': opcontact,
//       'description': description
//     };
//   }

//   @override
//   String toString() {
//     return 'Payments(id: $id,queingcode: $queingcode, paymentType: $paymentType, picUrl: $picUrl, amount: $amount, isapprove: $isapproved, paymentDate: $paymentDate, refNum: $refNum, bankName: $bankName, TransDate: $TransDate, updatedby: $updatedby, chrngtransid: $chrngtransid, syid: $syid, semid: $semid, opcontact: $opcontact, description: $description)';
//   }
// }

import 'dart:convert';

int parseInt(dynamic value) {
  final jsonValue = jsonDecode(jsonEncode(value));
  return jsonValue is int ? jsonValue : int.tryParse(jsonValue.toString()) ?? 0;
}

class Payments {
  final int id;
  final String queingcode;
  final int paymentType;
  final String picUrl;
  final String amount;
  final int isapproved;
  final String paymentDate;
  final String refNum;
  String? bankName;
  final String TransDate;
  int? updatedby;
  int? chrngtransid;
  final int syid;
  final int semid;
  final String opcontact;
  final String description;

  Payments({
    required this.id,
    required this.queingcode,
    required this.paymentType,
    required this.picUrl,
    required this.isapproved,
    required this.amount,
    required this.paymentDate,
    required this.refNum,
    this.bankName,
    required this.TransDate,
    required this.updatedby,
    required this.chrngtransid,
    required this.syid,
    required this.semid,
    required this.opcontact,
    required this.description,
  });

  factory Payments.fromJson(Map<String, dynamic> json) {
    return Payments(
      id: parseInt(json['id']),
      queingcode: json['queingcode'] ?? '',
      paymentType: parseInt(json['paymentType']),
      picUrl: json['picUrl'] ?? '',
      amount: json['amount'] ?? '',
      isapproved: parseInt(json['isapproved']),
      paymentDate: json['paymentDate'] ?? '',
      refNum: json['refNum'] ?? '',
      bankName: json['bankName'] ?? '',
      TransDate: json['TransDate'] ?? '',
      updatedby: parseInt(json['updatedby']),
      chrngtransid: parseInt(json['chrngtransid']),
      syid: parseInt(json['syid']),
      semid: parseInt(json['semid']),
      opcontact: json['opcontact'] ?? '',
      description: json['description'] ?? '',
    );
  }

  String getStatus() {
    switch (isapproved) {
      case 0:
        return 'On Process';
      case 1:
        return 'Approved';
      case 2:
        return 'Not Approved';
      case 3:
        return 'Canceled';
      case 5:
        return 'Processed';
      default:
        return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'queingcode': queingcode,
      'paymentType': paymentType,
      'picUrl': picUrl,
      'amount': amount,
      'isapproved': isapproved,
      'paymentDate': paymentDate,
      'refNum': refNum,
      'bankName': bankName,
      'TransDate': TransDate,
      'updatedby': updatedby,
      'chrngtransid': chrngtransid,
      'syid': syid,
      'semid': semid,
      'opcontact': opcontact,
      'description': description
    };
  }

  @override
  String toString() {
    return 'Payments(id: $id,queingcode: $queingcode, paymentType: $paymentType, picUrl: $picUrl, amount: $amount, isapprove: $isapproved, paymentDate: $paymentDate, refNum: $refNum, bankName: $bankName, TransDate: $TransDate, updatedby: $updatedby, chrngtransid: $chrngtransid, syid: $syid, semid: $semid, opcontact: $opcontact, description: $description)';
  }
}
