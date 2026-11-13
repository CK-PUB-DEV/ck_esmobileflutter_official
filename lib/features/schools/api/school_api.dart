import 'package:http/http.dart' as http;

class SchoolApi {
  final String _mainDomain = "https://esvault.essentiel.ph/";
  final String _esDomain = "api/getSchoolList";

  getSchoolList() async {
    var fullUrl = '$_mainDomain$_esDomain';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  getImage() {
    return _mainDomain;
  }
}
