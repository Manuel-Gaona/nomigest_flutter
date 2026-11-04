import '../core/api_client.dart';
import '../core/json.dart';

/// Portal del empleado: sus recibos, firma con PIN, aclaraciones y solicitudes.
class PortalService {
  static Future<Json> perfil() async => Json.from(await api.get('/portal/perfil') as Map);

  static Future<List<Json>> recibos() async => asJsonList((await api.get('/portal/recibos'))['items']);

  static Future<Json> recibo(int id) async => Json.from(await api.get('/portal/recibos/$id') as Map);

  static Future<Json> firmar(int id, String pin) async =>
      Json.from(await api.post('/portal/recibos/$id/firmar', {'pin': pin}) as Map);

  static Future<void> tengoDudas(int id, String mensaje) =>
      api.post('/portal/recibos/$id/aclaraciones', {'mensaje': mensaje});

  static Future<void> guardarPin(String nuevo, {String? actual}) =>
      api.post('/portal/pin', {'pin_nuevo': nuevo, 'pin_actual': ?actual});

  static Future<List<Json>> solicitudes() async => asJsonList((await api.get('/portal/solicitudes'))['items']);

  static Future<Json> solicitar(Json datos) async => Json.from(await api.post('/portal/solicitudes', datos) as Map);

  static Future<void> cancelarSolicitud(int id) => api.delete('/portal/solicitudes/$id');
}

class SolicitudesService {
  static Future<Json> aprobar(int id, {String? comentario}) async =>
      Json.from(await api.post('/solicitudes/$id/aprobar', {'comentario': comentario}) as Map);

  static Future<Json> rechazar(int id, {String? comentario}) async =>
      Json.from(await api.post('/solicitudes/$id/rechazar', {'comentario': comentario}) as Map);
}
