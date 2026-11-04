import '../core/api_client.dart';
import '../core/json.dart';

/// Nómina por periodo y recibos (vista de Recursos Humanos / Contabilidad).
class NominaService {
  /// Vista completa de un periodo: periodos, nómina, empleados con su recibo.
  static Future<Json> vista({String? tipoPeriodo, int? periodoId, String tipo = 'ordinaria'}) async {
    final r = await api.get('/nomina', query: {
      if (periodoId != null) 'periodo_id': periodoId else 'tipo_periodo': tipoPeriodo,
      'tipo': tipo,
    });
    return Json.from(r as Map);
  }

  static Json _cuerpo(int periodoId, String tipo, List<int>? empleadoIds, [num? sueldoBruto]) => {
        'periodo_id': periodoId,
        'tipo': tipo,
        'empleado_ids': ?empleadoIds,
        'sueldo_bruto': ?sueldoBruto,
      };

  /// Devuelve {"resumen": {...}, "vista": {...}}
  static Future<Json> calcular(int periodoId, String tipo, List<int>? empleadoIds, {num? sueldoBruto}) async =>
      Json.from(await api.post('/nomina/calcular', _cuerpo(periodoId, tipo, empleadoIds, sueldoBruto)) as Map);

  static Future<Json> publicar(int periodoId, String tipo, List<int>? empleadoIds) async =>
      Json.from(await api.post('/nomina/publicar', _cuerpo(periodoId, tipo, empleadoIds)) as Map);

  static Future<Json> cerrar(int periodoId, String tipo) async =>
      Json.from(await api.post('/nomina/cerrar', _cuerpo(periodoId, tipo, null)) as Map);

  static Future<Json> reabrir(int periodoId, String tipo) async =>
      Json.from(await api.post('/nomina/reabrir', _cuerpo(periodoId, tipo, null)) as Map);

  static Future<List<Json>> historial({int? ejercicio}) async =>
      asJsonList((await api.get('/nomina/historial', query: {'ejercicio': ejercicio}))['items']);

  static Future<Json> simular(num sueldoBruto, String tipoPeriodo) async =>
      Json.from(await api.post('/nomina/simular', {'sueldo_bruto': sueldoBruto, 'tipo_periodo': tipoPeriodo}) as Map);
}

class RecibosService {
  static Future<Json> obtener(int id) async => Json.from(await api.get('/recibos/$id') as Map);

  static Future<List<Json>> listar({int? empleadoId, int? periodoId}) async =>
      asJsonList((await api.get('/recibos', query: {'empleado_id': empleadoId, 'periodo_id': periodoId}))['items']);

  static Future<Json> agregarLinea(int id, Json datos) async =>
      Json.from(await api.post('/recibos/$id/detalles', datos) as Map);

  static Future<Json> editarLinea(int id, int detalleId, Json datos) async =>
      Json.from(await api.put('/recibos/$id/detalles/$detalleId', datos) as Map);

  static Future<Json> eliminarLinea(int id, int detalleId) async =>
      Json.from(await api.delete('/recibos/$id/detalles/$detalleId') as Map);

  static Future<Json> recalcularImpuestos(int id) async =>
      Json.from(await api.post('/recibos/$id/recalcular-impuestos') as Map);

  static Future<Json> recalcular(int id) async => Json.from(await api.post('/recibos/$id/recalcular') as Map);

  static Future<Json> publicar(int id) async => Json.from(await api.post('/recibos/$id/publicar') as Map);

  static Future<void> quitar(int id) => api.delete('/recibos/$id');
}

class AclaracionesService {
  static Future<List<Json>> listar({String? estado}) async =>
      asJsonList((await api.get('/aclaraciones', query: {'estado': estado}))['items']);

  static Future<Json> responder(int id, String respuesta) async =>
      Json.from(await api.post('/aclaraciones/$id/responder', {'respuesta': respuesta}) as Map);
}
