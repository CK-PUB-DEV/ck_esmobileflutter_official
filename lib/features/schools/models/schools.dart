class School {
  final int id;
  final String eslink;
  final String schoolabrv;
  final String schoolname;
  final String schoollogo;
  final String anydesk;
  final String schoolVersion;

  School({
    required this.id,
    required this.eslink,
    required this.schoolabrv,
    required this.schoolname,
    required this.schoollogo,
    required this.anydesk,
    this.schoolVersion = 'v1',
  });

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'] ?? 0,
      eslink: json['eslink'] ?? '',
      schoolabrv: json['schoolabrv'] ?? '',
      schoolname: json['schoolname'] ?? '',
      schoollogo: json['schoollogo'] ?? '',
      anydesk: json['anydesk'] ?? '',
      schoolVersion: (json['system_version'] == 2) ? 'v2' : 'v1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eslink': eslink,
      'schoolabrv': schoolabrv,
      'schoolname': schoolname,
      'schoollogo': schoollogo,
      'anydesk': anydesk,
      'school_version': schoolVersion,
    };
  }

  @override
  String toString() {
    return 'School(id: $id,eslink: $eslink,schoolabrv: $schoolabrv,schoolname: $schoolname,schoollogo: $schoollogo,anydesk: $anydesk,schoolVersion: $schoolVersion)';
  }
}
