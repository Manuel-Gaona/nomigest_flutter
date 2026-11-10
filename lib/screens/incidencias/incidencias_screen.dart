import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../services/catalogos_service.dart';
import '../../services/crud_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/formulario.dart';
import '../../widgets/nomi_widgets.dart';

/// Faltas e incapacidades: reducen los días pagados en la nómina.
class IncidenciasScreen extends StatefulWidget {
  const IncidenciasScreen({super.key});

  @override
  State<IncidenciasScreen> createState() => _IncidenciasScreenState();
}

class _IncidenciasScreenState extends State<IncidenciasScreen> {
  String? _tipo;
  final _carga = GlobalKey<CargaState<List<Json>>>();

  static final _campos = [
    CampoDef('empleado_id', 'Empleado',
        icono: Icons.badge_outlined, tipo: TipoCampo.seleccion, cargarOpciones: CatalogosService.empleados),
    CampoDef('tipo', 'Tipo',
        icono: Icons.event_busy_outlined,
        tipo: TipoCampo.seleccion,
        cargarOpciones: () => CatalogosService.opciones('tipos_incidencia')),
    const CampoDef('fecha_inicial', 'Fecha inicial', tipo: TipoCampo.fecha),
    const CampoDef('dias', 'Número de días', icono: Icons.numbers, tipo: TipoCampo.entero),
    CampoDef('justificada', 'Falta justificada',
        tipo: TipoCampo.booleano,
        requerido: false,
        visibleSi: (v) => v['tipo'] == 'falta',
        ayuda: 'Las faltas justificadas no se descuentan.'),
    CampoDef('tipo_incapacidad', 'Tipo de incapacidad',
        icono: Icons.local_hospital_outlined,
        tipo: TipoCampo.seleccion,
        visibleSi: (v) => v['tipo'] == 'incapacidad',
        cargarOpciones: () => CatalogosService.opciones('tipos_incapacidad')),
    CampoDef('folio', 'Folio IMSS', icono: Icons.tag, maxLength: 20, visibleSi: (v) => v['tipo'] == 'incapacidad'),
    const CampoDef('observaciones', 'Observaciones', icono: Icons.notes, tipo: TipoCampo.multilinea, requerido: false),
  ];

  Future<void> _abrir([Json? registro]) async {
    final id = registro?.entero('id');
    final r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FormularioScreen(
        titulo: id == null ? 'Registrar falta o incapacidad' : 'Editar registro',
        campos: _campos,
        inicial: registro,
        valoresPorDefecto: {'tipo': 'falta', 'dias': 1, 'justificada': false, 'fecha_inicial': isoFecha(DateTime.now())},
        guardar: (datos) => id == null ? incidenciasService.crear(datos) : incidenciasService.modificar(id, datos),
        eliminar: id == null ? null : () => incidenciasService.eliminar(id),
        confirmacionEliminar: 'El registro se eliminará y dejará de descontarse en nóminas que se calculen después.',
      ),
    ));
    if (r != null && mounted) {
      mostrarMensaje(context, 'Cambios guardados.');
      _carga.currentState?.recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrir,
        backgroundColor: NomiColors.darkGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String?>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: null, label: Text('Todas')),
                  ButtonSegment(value: 'falta', label: Text('Faltas')),
                  ButtonSegment(value: 'incapacidad', label: Text('Incapacidades')),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) {
                  setState(() => _tipo = s.first);
                  _carga.currentState?.recargar();
                },
              ),
            ),
          ),
          Expanded(
            child: Carga<List<Json>>(
              key: _carga,
              cargar: () => incidenciasService.listar(filtros: {'tipo': _tipo}),
              builder: (context, registros, recargar) => RefreshIndicator(
                onRefresh: recargar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    const SectionLabel('Registros', top: 8),
                    if (registros.isEmpty)
                      const VacioView('No hay faltas ni incapacidades registradas.', icon: Icons.event_busy_outlined)
                    else
                      for (final r in registros)
                        RecordTile(
                          title: r.str('empleado'),
                          subtitle: [
                            r.str('tipo') == 'incapacidad' ? r.str('tipo_incapacidad_nombre') : 'Falta',
                            r.str('dias') == '1'
                                ? fechaCorta(r.str('fecha_inicial'))
                                : '${fechaCorta(r.str('fecha_inicial'))} - ${fechaCorta(r.str('fecha_final'))}',
                            if (r['folio'] != null) 'Folio ${r.str('folio')}',
                          ].join(' · '),
                          accent: r.str('tipo') == 'incapacidad' ? NomiColors.blue : NomiColors.red,
                          trailing: r.flag('justificada')
                              ? const StatusBadge('Justificada', NomiColors.emerald, NomiColors.emeraldBg)
                              : Text('${r.str('dias')} día(s)', style: const TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () => _abrir(r),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
