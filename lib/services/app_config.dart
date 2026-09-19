import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get backendBaseUrl {
    if (!dotenv.isInitialized) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return dotenv.env['BACKEND_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1';
  }

  static String get googleMapsApiKey {
    if (!dotenv.isInitialized) {
      return '';
    }
    return dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  }

  static bool get hasGoogleMapsKey {
    return googleMapsApiKey.trim().isNotEmpty;
  }
}
