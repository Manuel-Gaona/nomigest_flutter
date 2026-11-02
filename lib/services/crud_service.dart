import '../core/api_client.dart';
import '../core/json.dart';

/// Operaciones estándar de un catálogo de la API (`/api/<recurso>`).
class CrudService {
  final String path;
  const CrudService(this.path);

  Future<List<Json>> listar({String? q, bool inactivos = false, Map<String, dynamic>? filtros}) async {
    final r = await api.get(path, query: {'q': q, if (inactivos) 'inactivos': 1, ...?filtros});
    return asJsonList(r['items']);
  }

  Future<Json> obtener(int id) async => Json.from(await api.get('$path/$id') as Map);

  Future<Json> crear(Json datos) async => Json.from(await api.post(path, datos) as Map);

  Future<Json> modificar(int id, Json datos) async => Json.from(await api.put('$path/$id', datos) as Map);

  /// Baja lógica (estatus Inactivo) o eliminación, según el recurso.
  Future<dynamic> eliminar(int id) => api.delete('$path/$id');

  Future<Json> reactivar(int id) async => Json.from(await api.post('$path/$id/reactivar') as Map);
}

const usuariosService = CrudService('/usuarios');
const rolesService = CrudService('/roles');
const empleadosService = CrudService('/empleados');
const departamentosService = CrudService('/departamentos');
const horariosService = CrudService('/horarios');
const periodosService = CrudService('/periodos');
const conceptosService = CrudService('/conceptos');
const festivosService = CrudService('/festivos');
const movimientosService = CrudService('/movimientos');
const infonavitService = CrudService('/infonavit');
const solicitudesService = CrudService('/solicitudes');
const incidenciasService = CrudService('/incidencias');
