import '../core/api_client.dart';
import '../core/json.dart';

/// Opción de una lista desplegable.
class Opcion<T> {
  final T valor;
  final String texto;
  const Opcion(this.valor, this.texto);
}

/// Endpoints auxiliares de los catálogos y listas para formularios.
class CatalogosService {
  static Json? _opciones;

  /// Listas fijas (/api/opciones); se guardan en memoria tras la primera consulta.
  static Future<List<Opcion<String>>> opciones(String nombre) async {
    _opciones ??= Json.from(await api.get('/opciones') as Map);
    return [for (final o in _opciones!.lista(nombre)) Opcion(o.str('valor'), o.str('nombre'))];
  }

  static Future<List<Opcion<int>>> empleados({bool soloActivos = true}) async {
    final r = await api.get('/empleados', query: {if (!soloActivos) 'inactivos': 1});
    return [
      for (final e in asJsonList(r['items']))
        Opcion(e.entero('id')!, '${e.str('numero_empleado')} · ${e.str('nombre_completo')}'),
    ];
  }

  static Future<List<Opcion<int>>> departamentos() => _activos('/departamentos', 'nombre');

  static Future<List<Opcion<int>>> horarios() => _activos('/horarios', 'nombre');

  static Future<List<Opcion<int>>> roles() => _activos('/roles', 'nombre');

  static Future<List<Opcion<int>>> periodos({String? tipoPeriodo}) async {
    final r = await api.get('/periodos', query: {'tipo_periodo': tipoPeriodo});
    return [for (final p in asJsonList(r['items'])) Opcion(p.entero('id')!, p.str('nombre'))];
  }

  /// Conceptos que se capturan a mano (?tipo=percepcion|deduccion).
  static Future<List<Json>> conceptosCapturables(String tipo) async {
    final r = await api.get('/conceptos', query: {'tipo': tipo, 'capturables': 1});
    return asJsonList(r['items']);
  }

  static Future<List<Opcion<int>>> _activos(String path, String campo) async {
    final r = await api.get(path);
    return [for (final e in asJsonList(r['items'])) Opcion(e.entero('id')!, e.str(campo))];
  }

  static Future<List<Json>> privilegios() async => asJsonList((await api.get('/roles/privilegios'))['items']);

  static Future<String> generarPeriodos(String tipo, int ejercicio) async {
    final r = await api.post('/periodos/generar', {'tipo_periodo': tipo, 'ejercicio': ejercicio});
    return '${r['mensaje']}';
  }

  static Future<String> cargarFestivosLft(int ejercicio) async {
    final r = await api.post('/festivos/cargar-lft', {'ejercicio': ejercicio});
    return '${r['mensaje']}';
  }

  static Future<Json> saldoVacaciones(int empleadoId) async =>
      Json.from(await api.get('/empleados/$empleadoId/saldo-vacaciones') as Map);

  static Future<Json> tablero() async => Json.from(await api.get('/tablero') as Map);
}
