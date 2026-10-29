import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'app_config.dart';
import 'json.dart';

/// Usuario en sesión y sus privilegios. La app escucha sus cambios para
/// mostrar el login o el menú principal.
class Session extends ChangeNotifier {
  Session._();
  static final instance = Session._();

  Json? usuario;
  Set<String> privilegios = {};

  /// true cuando la sesión terminó porque el servidor rechazó el token.
  bool expiro = false;

  bool get activa => usuario != null;
  String get nombreUsuario => usuario?.str('nombre_usuario') ?? '';
  String get rol => usuario?.str('rol') ?? '';
  int? get empleadoId => usuario?.entero('empleado_id');

  bool puede(String privilegio) => privilegios.contains(privilegio);
  bool puedeAlguno(Iterable<String> lista) => lista.any(puede);

  /// Restaura la URL del servidor y la sesión guardadas.
  Future<void> restaurar() async {
    final prefs = await SharedPreferences.getInstance();
    api.baseUrl = prefs.getString(AppConfig.prefsBaseUrl) ?? AppConfig.defaultBaseUrl;
    api.token = prefs.getString(AppConfig.prefsToken);
    api.onUnauthorized = _expirar;
    if (api.token == null) return;
    try {
      _asignar(Json.from(await api.get('/auth/me') as Map));
    } on ApiException {
      await _limpiar();
    }
  }

  Future<void> iniciar(String nombreUsuario, String password) async {
    final r = Json.from(await api.post('/auth/login', {
      'nombre_usuario': nombreUsuario.trim(),
      'password': password,
    }) as Map);
    api.token = r.str('access_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefsToken, api.token!);
    expiro = false;
    _asignar(r.obj('usuario')!);
  }

  Future<void> cerrar() async {
    try {
      await api.post('/auth/logout');
    } on ApiException {
      // Aunque falle el servidor, la sesión local se cierra
    }
    await _limpiar();
  }

  Future<void> cambiarServidor(String url) async {
    api.baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefsBaseUrl, api.baseUrl);
  }

  void _asignar(Json datos) {
    usuario = datos;
    privilegios = {for (final p in (datos['privilegios'] as List? ?? [])) '$p'};
    notifyListeners();
  }

  void _expirar() {
    expiro = true;
    _limpiar();
  }

  Future<void> _limpiar() async {
    api.token = null;
    usuario = null;
    privilegios = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.prefsToken);
    notifyListeners();
  }
}

final session = Session.instance;
