import 'package:http/http.dart' as http;

class SchoolApi {
  final String _mainDomain = "https://esvault.essentiel.ph/";
  final String _esDomain = "api/getSchoolList";
  final String _searchPath = "api/schools/search";

  /// The whole directory. Kept only for a directory server that has no [searchSchools] yet, and
  /// for apps already installed. Once the server has search, nothing in the app calls this.
  getSchoolList() async {
    var fullUrl = '$_mainDomain$_esDomain';
    return await http.get(
      Uri.parse(fullUrl),
    );
  }

  /// Up to five schools whose code or name matches [query]. The server answers 404 until it has
  /// this endpoint; the finder then falls back to [getSchoolList].
  Future<http.Response> searchSchools(String query) {
    final uri = Uri.parse('$_mainDomain$_searchPath')
        .replace(queryParameters: {'q': query.trim()});
    return http.get(uri, headers: const {'Accept': 'application/json'});
  }

  getImage() {
    return _mainDomain;
  }
}
