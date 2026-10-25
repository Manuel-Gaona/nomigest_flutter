import 'package:flutter/foundation.dart';

/// Configuración de conexión con la API.
class AppConfig {
  /// URL por defecto del servidor Flask. El emulador de Android llega a la
  /// computadora anfitriona por 10.0.2.2; en un teléfono físico use la IP de la PC
  /// (se puede cambiar desde el ícono de engrane en la pantalla de inicio de sesión).
  static String get defaultBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://127.0.0.1:5000';
  }

  static const prefsBaseUrl = 'api_base_url';
  static const prefsToken = 'api_token';
}
