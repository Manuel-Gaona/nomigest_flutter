import '../core/api_client.dart';

/// Cuenta del usuario: cambio y recuperación de contraseña.
class CuentaService {
  static Future<void> cambiarPassword(String actual, String nuevo) =>
      api.post('/auth/cambiar-password', {'password_actual': actual, 'password_nuevo': nuevo});

  static Future<String> recuperar(String nombreUsuario) async =>
      '${(await api.post('/auth/recuperar', {'nombre_usuario': nombreUsuario}))['mensaje']}';
}
