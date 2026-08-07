import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

Stream<String> openEventTextStream(
    Uri uri, Map<String, String> headers) async* {
  final client = http.Client();
  try {
    final request = http.Request('GET', uri)..headers.addAll(headers);
    final response =
        await client.send(request).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Event stream failed with status ${response.statusCode}');
    }
    yield* response.stream.transform(utf8.decoder);
  } finally {
    client.close();
  }
}
