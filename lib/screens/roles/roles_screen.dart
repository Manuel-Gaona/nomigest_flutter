import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/json.dart';
import '../../services/catalogos_service.dart';
import '../../services/crud_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';

/// Configuración de los privilegios de cada rol (RF03).
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<Json> _roles = [];
  List<Json> _privilegios = [];
  int? _rolId;
  Set<String> _marcados = {};
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  Json? get _rol => _roles.where((r) => r.entero('id') == _rolId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({int? seleccionar}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final roles = await rolesService.listar();
      final privilegios = await CatalogosService.privilegios();
      setState(() {
        _roles = roles;
        _privilegios = privilegios;
        final id = seleccionar ?? _rolId;
        final rol = roles.where((r) => r.entero('id') == id).firstOrNull ??
            roles.where((r) => !r.flag('es_sistema')).firstOrNull ??
            roles.firstOrNull;
        _seleccionar(rol);
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _seleccionar(Json? rol) {
    _rolId = rol?.entero('id');
    _marcados = {for (final p in (rol?['privilegios'] as List? ?? [])) '$p'};
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final r = await ejecutar(
      context,
      () => rolesService.modificar(_rolId!, {'privilegios': _marcados.toList()}),
      exito: 'Configuración guardada. Los usuarios del rol verán el menú actualizado al volver a entrar.',
    );
    if (mounted) setState(() => _guardando = false);
    if (r != null) _cargar();
  }

  Future<void> _nuevoRol() async {
    final nombre = await pedirTexto(context,
        titulo: 'Nuevo rol', etiqueta: 'Nombre del rol', boton: 'Crear rol', lineas: 1, color: NomiColors.darkGreen);
    if (nombre == null || !mounted) return;
    final r = await ejecutar(context, () => rolesService.crear({'nombre': nombre, 'privilegios': []}),
        exito: 'Rol creado. Marca sus privilegios y guarda.');
    if (r != null) _cargar(seleccionar: r.entero('id'));
  }

  Future<void> _eliminarRol() async {
    final ok = await confirmar(context,
        titulo: 'Eliminar rol',
        mensaje: 'El rol "${_rol?.str('nombre')}" pasará a inactivo. No debe tener usuarios activos.',
        aceptar: 'Eliminar',
        destructivo: true);
    if (!ok || !mounted) return;
    final r = await ejecutar(context, () => rolesService.eliminar(_rolId!), exito: 'Rol eliminado.');
    if (r != null) {
      _rolId = null;
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const CargandoView();
    if (_error != null) return ErrorView(_error!, onReintentar: _cargar);
    final rol = _rol;
    final sistema = rol?.flag('es_sistema') ?? false;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NomiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SELECCIONAR ROL A CONFIGURAR',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: NomiColors.text3)),
              const SizedBox(height: 12),
              NomiSelect<int>(
                'Rol',
                [for (final r in _roles) (r.entero('id')!, r.str('nombre'))],
                value: _rolId,
                icon: Icons.admin_panel_settings_outlined,
                onChanged: (id) => setState(() => _seleccionar(_roles.firstWhere((r) => r.entero('id') == id))),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                      onPressed: _nuevoRol, icon: const Icon(Icons.add, size: 18), label: const Text('Nuevo rol')),
                  if (rol != null && !sistema)
                    TextButton.icon(
                      onPressed: _eliminarRol,
                      style: TextButton.styleFrom(foregroundColor: NomiColors.red),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        NomiCard(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 4),
                child: Text('PERMISOS DE PANTALLA / ACCESOS',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: NomiColors.text3)),
              ),
              if (sistema)
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Text('El rol Administrador siempre tiene acceso total.',
                      style: TextStyle(color: NomiColors.amber, fontSize: 12.5)),
                ),
              for (final p in _privilegios)
                CheckboxListTile(
                  value: sistema || _marcados.contains(p.str('clave')),
                  onChanged: sistema
                      ? null
                      : (v) => setState(() =>
                          v == true ? _marcados.add(p.str('clave')) : _marcados.remove(p.str('clave'))),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: NomiColors.blue,
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(p.str('nombre'), style: const TextStyle(fontSize: 14)),
                  subtitle: Text(p.str('descripcion'),
                      style: const TextStyle(fontSize: 12, color: NomiColors.text3)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: NomiButton('Guardar Configuración',
              color: NomiColors.emerald,
              height: 52,
              loading: _guardando,
              onPressed: rol == null || sistema ? null : _guardar),
        ),
      ],
    );
  }
}
