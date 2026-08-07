import 'package:flutter/foundation.dart';

class ApiConfig {
  static const productionBaseUrl = 'https://go-wasl.com/api';

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      if (kIsWeb && configured.startsWith('/')) {
        return '${Uri.base.origin}$configured';
      }
      return configured;
    }
    return productionBaseUrl;
  }
}
