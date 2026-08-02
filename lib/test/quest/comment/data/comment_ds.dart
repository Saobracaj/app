import 'package:http/http.dart' as http;

import '../../../../flavor.dart';

final commentDataSource = CommentDataSource();

class CommentDataSource {
  final String baseUrl;

  CommentDataSource({String? baseUrl})
    : baseUrl = baseUrl ?? FlavorConfig.instance.apiBaseUrl;

  Future<String?> fetchComment(int questionId) async {
    final url = Uri.parse('$baseUrl/comment?qid=$questionId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return response.body;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load comment: \\${response.statusCode}');
    }
  }
}
