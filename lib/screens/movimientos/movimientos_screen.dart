import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../core/session.dart';
import '../../services/catalogos_service.dart';
import '../../services/crud_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/formulario.dart';
import '../../widgets/nomi_widgets.dart';

/// Percepciones (RF05), deducciones y préstamos (RF06) y créditos Infonavit (RDF0603).
class MovimientosScreen extends StatefulWidget {
  /// 'percepcion', 'deduccion' o 'infonavit'
  final String inicial;
  const MovimientosScreen({super.key, this.inicial = 'percepcion'});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  late String _tab = widget.inicial;
  int? _periodoId;
  List<Opcion<int>> _periodos = [];
  List<Json> _registros = [];
  bool _cargando = true;
  String? _error;

  List<(String, String)> get _tabs => [
        if (session.puede('percepciones')) ('percepcion', 'Percepción'),
        if (session.puede('deducciones')) ...[('deduccion', 'Deducción'), ('infonavit', 'Infonavit')],
      ];

  @override
  void initState() {
    super.initState();
    if (!_tabs.any((t) => t.$1 == _tab) && _tabs.isNotEmpty) _tab = _tabs.first.$1;
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      _periodos = await CatalogosService.periodos();
    } on ApiException {
      _periodos = [];
    }
    await _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final registros = _tab == 'infonavit'
          ? await infonavitService.listar()
          : await movimientosService.listar(filtros: {'tipo': _tab, 'periodo_id': _periodoId});
      if (mounted) setState(() => _registros = registros);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrir([Json? registro]) async {
    final Widget pantalla;
    if (_tab == 'infonavit') {
      pantalla = _formInfonavit(registro);
    } else {
      final conceptos = await ejecutar(context, () => CatalogosService.conceptosCapturables(_tab));
      if (conceptos == null || !mounted) return;
      pantalla = _formMovimiento(registro, conceptos);
    }
    final cambio = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
    if (cambio != null) {
      if (mounted) mostrarMensaje(context, 'Cambios guardados.');
      _cargar();
    }
  }

  Widget _formMovimiento(Json? registro, List<Json> conceptos) {
    final calculo = {for (final c in conceptos) c.entero('id'): c.str('tipo_calculo')};
    String tipoCalculo(Json v) => calculo[v['concepto_id']] ?? 'importe';
    final id = registro?.entero('id');
    final esPercepcion = _tab == 'percepcion';
    return FormularioScreen(
      titulo: '${id == null ? 'Registrar' : 'Editar'} ${esPercepcion ? 'percepción' : 'deducción'}',
      inicial: registro,
      valoresPorDefecto: {'recurrente': false, 'periodo_id': _periodoId, 'cantidad': 1},
      campos: [
        CampoDef('empleado_id', 'Empleado',
            icono: Icons.badge_outlined, tipo: TipoCampo.seleccion, cargarOpciones: CatalogosService.empleados),
        CampoDef('concepto_id', 'Concepto',
            icono: Icons.edit_note,
            tipo: TipoCampo.seleccion,
            opciones: [
              for (final c in conceptos)
                Opcion(c.entero('id'), [
                  c.str('nombre'),
                  if (c['fraccion_art110'] != null) '(art. 110 fr. ${c.str('fraccion_art110')})',
                ].join(' ')),
            ]),
        const CampoDef('recurrente', 'Aplicar en todas las nóminas',
            tipo: TipoCampo.booleano, requerido: false, icono: Icons.repeat,
            ayuda: 'Si no es recurrente se aplica solo en el periodo elegido.'),
        CampoDef('periodo_id', 'Periodo',
            icono: Icons.date_range_outlined,
            tipo: TipoCampo.seleccion,
            opciones: _periodos,
            visibleSi: (v) => v['recurrente'] != true),
        CampoDef('cantidad', 'Horas extra',
            icono: Icons.more_time,
            tipo: TipoCampo.decimal,
            visibleSi: (v) => tipoCalculo(v) == 'horas_extra',
            ayuda: 'Se pagan dobles con el salario por hora del empleado.'),
        CampoDef('monto', 'Monto (\$)',
            icono: Icons.attach_money,
            tipo: TipoCampo.decimal,
            visibleSi: (v) => tipoCalculo(v) != 'horas_extra',
            etiquetaSi: (v) => tipoCalculo(v) == 'porcentaje' ? 'Porcentaje (%)' : 'Monto (\$)',
            validar: (t) => (num.tryParse(t) ?? 0) <= 0 ? 'Debe ser mayor a cero.' : null),
        const CampoDef('descripcion', 'Descripción', icono: Icons.notes, requerido: false),
      ],
      guardar: (datos) => id == null ? movimientosService.crear(datos) : movimientosService.modificar(id, datos),
      eliminar: id == null || registro!['activo'] == false ? null : () => movimientosService.eliminar(id),
      textoEliminar: 'Cancelar movimiento',
      confirmacionEliminar: 'El movimiento dejará de aplicarse en las nóminas que se calculen después.',
    );
  }

  Widget _formInfonavit(Json? registro) {
    final id = registro?.entero('id');
    return FormularioScreen(
      titulo: id == null ? 'Registrar descuento Infonavit' : 'Editar crédito Infonavit',
      inicial: registro,
      valoresPorDefecto: {'tipo_descuento': 'cuota_fija', 'fecha_inicio': isoFecha(DateTime.now())},
      campos: [
        CampoDef('empleado_id', 'Empleado',
            icono: Icons.badge_outlined, tipo: TipoCampo.seleccion, cargarOpciones: CatalogosService.empleados),
        CampoDef('numero_credito', 'Número de crédito Infonavit',
            icono: Icons.numbers, maxLength: 20, formatos: [FilteringTextInputFormatter.digitsOnly]),
        CampoDef('tipo_descuento', 'Tipo de descuento',
            icono: Icons.percent,
            tipo: TipoCampo.seleccion,
            cargarOpciones: () => CatalogosService.opciones('tipos_descuento_infonavit')),
        CampoDef('valor_descuento', 'Valor del descuento',
            icono: Icons.attach_money,
            tipo: TipoCampo.decimal,
            etiquetaSi: (v) => switch (v['tipo_descuento']) {
                  'porcentaje' => 'Porcentaje del SBC (%)',
                  'factor_uma' => 'Factor (veces UMA)',
                  _ => 'Cuota fija mensual (\$)',
                },
            validar: (t) => (num.tryParse(t) ?? 0) <= 0 ? 'Debe ser mayor a cero.' : null),
        const CampoDef('fecha_inicio', 'Inicio del descuento', tipo: TipoCampo.fecha),
      ],
      guardar: (datos) => id == null ? infonavitService.crear(datos) : infonavitService.modificar(id, datos),
      eliminar: id == null || registro!['activo'] == false ? null : () => infonavitService.eliminar(id),
      textoEliminar: 'Suspender descuento',
      confirmacionEliminar: 'El descuento dejará de aplicarse (por ejemplo, al liquidarse el crédito).',
    );
  }

  Widget _monto(String texto, Color color) =>
      Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14));

  Widget _tile(Json r) {
    if (_tab == 'infonavit') {
      return RecordTile(
        title: 'Crédito ${r.str('numero_credito')}',
        subtitle: '${r.str('empleado')} · ${r.str('tipo_descuento_nombre')}',
        accent: r['activo'] == false ? NomiColors.text3 : NomiColors.amber,
        trailing: r['activo'] == false
            ? StatusBadge.inactivo()
            : _monto('-${moneda(r.numero('descuento_periodo'))}', NomiColors.red),
        onTap: () => _abrir(r),
      );
    }
    final percepcion = r.str('tipo') == 'percepcion';
    final color = percepcion ? NomiColors.emerald : NomiColors.red;
    final valor = switch (r.str('tipo_calculo')) {
      'horas_extra' => '${numero(r.numero('cantidad'))} h',
      'porcentaje' => '${numero(r.numero('monto'))}%',
      _ => '${percepcion ? '+' : '-'}${moneda(r.numero('monto') * r.numero('cantidad'))}',
    };
    return RecordTile(
      title: r.str('concepto'),
      subtitle: '${r.str('empleado')} · ${r.flag('recurrente') ? 'Recurrente' : r.str('periodo')}',
      accent: color,
      trailing: _monto(valor, color),
      onTap: () => _abrir(r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (boton, lista) = switch (_tab) {
      'deduccion' => ('Registrar Deducción', 'Historial de deducciones y préstamos'),
      'infonavit' => ('Registrar Descuento Infonavit', 'Créditos Infonavit activos'),
      _ => ('Registrar Percepción', 'Historial de percepciones'),
    };
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(),
        backgroundColor: _tab == 'percepcion' ? NomiColors.darkGreen : NomiColors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(boton),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_tabs.length > 1)
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final t in _tabs)
                      ButtonSegment(value: t.$1, label: Text(t.$2, style: const TextStyle(fontSize: 12))),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) {
                    setState(() => _tab = s.first);
                    _cargar();
                  },
                ),
              ),
            if (_tab != 'infonavit') ...[
              const SizedBox(height: 16),
              NomiSelect<int?>(
                'Periodo',
                [(null, 'Todos los periodos'), for (final p in _periodos) (p.valor, p.texto)],
                value: _periodoId,
                icon: Icons.date_range_outlined,
                onChanged: (v) {
                  setState(() => _periodoId = v);
                  _cargar();
                },
              ),
            ],
            SectionLabel(lista),
            if (_cargando)
              const CargandoView()
            else if (_error != null)
              ErrorView(_error!, onReintentar: _cargar)
            else if (_registros.isEmpty)
              const VacioView('No hay registros.', icon: Icons.receipt_outlined)
            else
              for (final r in _registros) _tile(r),
          ],
        ),
      ),
    );
  }
}
