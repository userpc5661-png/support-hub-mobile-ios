import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<bool> openMediaFile({
  required String url,
  required Map<String, String> headers,
  required String fileName,
}) async {
  final response = await http.get(Uri.parse(url), headers: headers);
  if (response.statusCode < 200 || response.statusCode >= 300) return false;
  final safeName = fileName
      .replaceAll(RegExp(r'[^a-zA-Z0-9._\-\u0600-\u06FF]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/${safeName.isEmpty ? 'wasl-file' : safeName}');
  await file.writeAsBytes(response.bodyBytes, flush: true);
  final result = await OpenFilex.open(file.path);
  return result.type == ResultType.done;
}
