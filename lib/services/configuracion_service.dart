import '../core/api_client.dart';
import '../core/json.dart';

/// Datos de la empresa, parámetros fiscales anuales y tarifa de ISR.
class ConfiguracionService {
  static Future<Json> empresa() async => Json.from(await api.get('/configuracion') as Map);

  static Future<Json> guardarEmpresa(Json datos) async => Json.from(await api.put('/configuracion', datos) as Map);

  static Future<List<Json>> parametros() async => asJsonList((await api.get('/configuracion/parametros'))['items']);

  static Future<Json> crearParametro(Json datos) async =>
      Json.from(await api.post('/configuracion/parametros', datos) as Map);

  static Future<Json> modificarParametro(int id, Json datos) async =>
      Json.from(await api.put('/configuracion/parametros/$id', datos) as Map);

  static Future<Json> tarifaIsr({int? ejercicio}) async =>
      Json.from(await api.get('/configuracion/tarifa-isr', query: {'ejercicio': ejercicio}) as Map);
}
