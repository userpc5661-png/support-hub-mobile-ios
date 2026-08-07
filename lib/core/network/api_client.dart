import '../../core/localization/app_locale_controller.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'event_stream_transport.dart';

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this.storage, {http.Client? client})
      : _client = client ?? http.Client();

  final TokenStorage storage;
  final http.Client _client;

  Future<Map<String, dynamic>> getMap(String path) async =>
      _asMap(await _request('GET', path));
  Future<Map<String, dynamic>?> getOptionalMap(String path) async {
    final value = await _request('GET', path);
    if (value == null) return null;
    return _asMap(value);
  }

  Future<List<Map<String, dynamic>>> getList(String path) async =>
      _asList(await _request('GET', path));
  Future<Map<String, dynamic>> postMap(String path,
          [Map<String, dynamic>? body]) async =>
      _asMap(await _request('POST', path,
          body: body ?? const <String, dynamic>{}));
  Future<Map<String, dynamic>> patchMap(
          String path, Map<String, dynamic> body) async =>
      _asMap(await _request('PATCH', path, body: body));
  Future<Map<String, dynamic>> putMap(
          String path, Map<String, dynamic> body) async =>
      _asMap(await _request('PUT', path, body: body));
  Future<Map<String, dynamic>> deleteMap(String path,
          [Map<String, dynamic>? body]) async =>
      _asMap(await _request('DELETE', path, body: body));

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    Map<String, String> fields = const {},
  }) async {
    final token = await storage.read();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}$path'),
    )
      ..headers['Accept'] = 'application/json'
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    try {
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 180));
      final response = await http.Response.fromStream(streamed);
      final parsed = _decodeResponse(response);
      _throwForStatus(response, parsed);
      return _asMap(parsed);
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(
          tr('تعذر رفع الملف. تحقق من اتصال الإنترنت وحاول مرة أخرى.'), 0);
    }
  }

  Future<AuthenticatedMediaRequest> mediaRequest(String value) async {
    var raw = value.trim();
    final apiUri = Uri.parse(ApiConfig.baseUrl);

    while (raw.startsWith('/api/')) {
      raw = raw.substring(4);
    }
    final uri = raw.startsWith('http://') || raw.startsWith('https://')
        ? Uri.parse(raw)
        : Uri.parse(
            '${ApiConfig.baseUrl}${raw.startsWith('/') ? raw : '/$raw'}');
    final sameApi = uri.scheme == apiUri.scheme &&
        uri.host == apiUri.host &&
        uri.port == apiUri.port;
    if (sameApi && uri.path.endsWith('/media')) {
      final ticket = await getMap('${raw.startsWith('/') ? raw : '/$raw'}/ticket');
      final ticketPath = ticket['url']?.toString() ?? '';
      if (ticketPath.isEmpty) {
        throw ApiException(tr('تعذر تجهيز ملف الوسائط للتشغيل.'), 500);
      }
      final ticketUrl = ticketPath.startsWith('http://') ||
              ticketPath.startsWith('https://')
          ? ticketPath
          : '${ApiConfig.baseUrl}${ticketPath.startsWith('/') ? ticketPath : '/$ticketPath'}';
      return AuthenticatedMediaRequest(url: ticketUrl, headers: const {});
    }
    final token = sameApi ? await storage.read() : null;
    return AuthenticatedMediaRequest(
      url: uri.toString(),
      headers: token == null ? const {} : {'Authorization': 'Bearer $token'},
    );
  }

  Stream<Map<String, dynamic>> eventStream(String path,
      {String? lastEventId}) async* {
    final token = await storage.read();
    if (token == null) throw ApiException(tr('الجلسة غير صالحة.'), 401);
    final stream = openEventTextStream(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Authorization': 'Bearer $token',
        if (lastEventId != null && lastEventId.isNotEmpty)
          'Last-Event-ID': lastEventId,
      },
    );
    await for (final line in stream.transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final raw = line.substring(5).trim();
      if (raw.isEmpty) continue;
      final value = jsonDecode(raw);
      if (value is Map) yield Map<String, dynamic>.from(value);
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw ApiException(tr('استجابة الخادم غير متوقعة.'), 200);
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is List) {
      return value
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    throw ApiException(tr('استجابة الخادم غير متوقعة.'), 200);
  }

  Future<Object?> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final token = await storage.read();
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    late http.Response response;
    try {
      response = switch (method) {
        'GET' => await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 30)),
        'POST' => await _client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 60)),
        'PATCH' => await _client
            .patch(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 30)),
        'PUT' => await _client
            .put(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 30)),
        'DELETE' => await _client
            .delete(uri,
                headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(const Duration(seconds: 30)),
        _ => throw StateError('Unsupported HTTP method: $method'),
      };
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(
          tr('تعذر الاتصال بالخادم. تأكد أن Docker والـAPI شغالان.'), 0);
    }

    final parsed = _decodeResponse(response);
    if (response.statusCode == 401) {
      // In this project, 401 usually means token expired or invalid.
      // We check if it's a platform session vs support session in storage if needed,
      // but the immediate action is often to re-auth.
      // For now, we propagate the error and the controller will handle logout if it's 'auth/me' or similar.
    }
    _throwForStatus(response, parsed);
    return parsed;
  }

  Object? _decodeResponse(http.Response response) {
    try {
      return response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return <String, dynamic>{'message': response.body};
    }
  }

  void _throwForStatus(http.Response response, Object? parsed) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final message = parsed is Map
        ? (parsed['message'] is List
            ? (parsed['message'] as List).join('\n')
            : parsed['message']?.toString())
        : null;
    throw ApiException(
      tr(message ?? tr('حدث خطأ في الاتصال بالخادم.')),
      response.statusCode,
    );
  }
}

class AuthenticatedMediaRequest {
  const AuthenticatedMediaRequest({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;
}
