import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/json.dart';
import '../../core/session.dart';
import '../../services/crud_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/formulario.dart';
import '../../widgets/nomi_widgets.dart';

/// Acción adicional de un catálogo (p. ej. "Generar periodos"). Devuelve true si
/// hay que recargar la lista.
class AccionCatalogo {
  final String texto;
  final IconData icono;
  final Future<bool> Function(BuildContext context) ejecutar;
  const AccionCatalogo(this.texto, this.icono, this.ejecutar);
}

/// Describe un catálogo: servicio, campos del formulario y cómo se ve cada fila.
class CatalogoDef {
  final String singular;
  final CrudService servicio;
  final String buscar;
  final List<CampoDef> campos;
  final String Function(Json) tituloDe;
  final String Function(Json) subtituloDe;
  final Widget? Function(Json)? insigniaDe;

  /// Privilegio necesario para agregar, modificar o eliminar.
  final String privilegio;

  /// true: eliminar = baja lógica (Inactivo) y se puede ver/reactivar inactivos.
  final bool bajaLogica;
  final Json valoresPorDefecto;
  final Map<String, dynamic> filtros;
  final List<AccionCatalogo> acciones;
  final Widget Function(BuildContext, Json)? extraFormulario;
  final IconData icono;

  const CatalogoDef({
    required this.singular,
    required this.servicio,
    required this.buscar,
    required this.campos,
    required this.tituloDe,
    required this.subtituloDe,
    this.insigniaDe,
    this.privilegio = 'catalogos',
    this.bajaLogica = true,
    this.valoresPorDefecto = const {},
    this.filtros = const {},
    this.acciones = const [],
    this.extraFormulario,
    this.icono = Icons.list_alt,
  });
}

/// Lista de un catálogo con búsqueda, filtro de inactivos y botón para agregar.
/// Alta y edición se hacen en una pantalla aparte ([FormularioScreen]).
class CatalogoScreen extends StatefulWidget {
  final CatalogoDef def;
  const CatalogoScreen({super.key, required this.def});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _buscar = TextEditingController();
  Timer? _espera;
  bool _inactivos = false;
  bool _cargando = true;
  String? _error;
  List<Json> _registros = [];

  CatalogoDef get def => widget.def;
  bool get _puedeEditar => session.puede(def.privilegio);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final registros = await def.servicio.listar(
        q: _buscar.text.trim(),
        inactivos: _inactivos,
        filtros: def.filtros,
      );
      if (mounted) setState(() => _registros = registros);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), _cargar);
  }

  Future<void> _abrir([Json? registro]) async {
    final id = registro?.entero('id');
    final activo = registro == null || registro['activo'] != false;
    final cambio = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FormularioScreen(
        titulo: registro == null ? 'Nuevo ${def.singular}' : 'Editar ${def.singular}',
        campos: def.campos,
        inicial: registro,
        valoresPorDefecto: def.valoresPorDefecto,
        guardar: (datos) => id == null ? def.servicio.crear(datos) : def.servicio.modificar(id, datos),
        eliminar: id == null || !activo ? null : () => def.servicio.eliminar(id),
        textoEliminar: def.bajaLogica ? 'Dar de baja' : 'Eliminar',
        confirmacionEliminar: def.bajaLogica
            ? 'El registro pasará a estatus Inactivo. Podrás reactivarlo después.'
            : 'El registro se eliminará definitivamente.',
        reactivar: id == null || !def.bajaLogica ? null : () => def.servicio.reactivar(id),
        extra: def.extraFormulario,
      ),
    ));
    if (cambio != null) {
      if (mounted) mostrarMensaje(context, 'Cambios guardados.');
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _puedeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _abrir(),
              backgroundColor: NomiColors.darkGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            NomiField(def.buscar, icon: Icons.search, controller: _buscar, onChanged: _alEscribir),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (def.bajaLogica)
                  FilterChip(
                    label: const Text('Mostrar inactivos'),
                    selected: _inactivos,
                    selectedColor: NomiColors.blueBg,
                    side: const BorderSide(color: NomiColors.stroke),
                    onSelected: (v) {
                      setState(() => _inactivos = v);
                      _cargar();
                    },
                  ),
                if (_puedeEditar)
                  for (final a in def.acciones)
                    TextButton.icon(
                      icon: Icon(a.icono, size: 18),
                      label: Text(a.texto),
                      onPressed: () async {
                        if (await a.ejecutar(context)) _cargar();
                      },
                    ),
              ],
            ),
            SectionLabel('Registros (${_registros.length})', top: 8),
            if (_cargando)
              const CargandoView()
            else if (_error != null)
              ErrorView(_error!, onReintentar: _cargar)
            else if (_registros.isEmpty)
              VacioView('No hay registros${_buscar.text.isEmpty ? '' : ' que coincidan con la búsqueda'}.',
                  icon: def.icono)
            else
              for (final r in _registros)
                RecordTile(
                  title: def.tituloDe(r),
                  subtitle: def.subtituloDe(r),
                  accent: r['activo'] == false ? NomiColors.text3 : NomiColors.blue,
                  trailing: def.insigniaDe?.call(r) ??
                      (def.bajaLogica ? StatusBadge.estatus(r['activo'] != false) : null),
                  onTap: _puedeEditar ? () => _abrir(r) : null,
                ),
          ],
        ),
      ),
    );
  }
}
