import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../core/session.dart';
import '../../services/catalogos_service.dart';
import '../../services/nomina_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';
import 'recibo_screen.dart';

/// Nómina por periodo (RF07): tipo de periodo → periodo → empleados → calcular → publicar.
class NominaScreen extends StatefulWidget {
  final int? periodoId;
  final String tipo;
  const NominaScreen({super.key, this.periodoId, this.tipo = 'ordinaria'});

  @override
  State<NominaScreen> createState() => _NominaScreenState();
}

class _NominaScreenState extends State<NominaScreen> {
  static const _periodicidades = [
    ('semanal', 'Semanal'),
    ('catorcenal', 'Catorcenal'),
    ('quincenal', 'Quincenal'),
    ('mensual', 'Mensual'),
  ];

  String _tipoPeriodo = 'quincenal';
  late String _tipo = widget.tipo;
  Json? _vista;
  Set<int> _seleccion = {};
  bool _cargando = true;
  bool _procesando = false;
  String? _error;

  Json? get _periodo => _vista?.obj('periodo');
  Json? get _nomina => _vista?.obj('nomina');
  List<Json> get _filas => _vista?.lista('empleados') ?? [];
  bool get _cerrada => _nomina?.str('estado') == 'cerrada';

  @override
  void initState() {
    super.initState();
    _cargar(periodoId: widget.periodoId);
  }

  Future<void> _cargar({int? periodoId}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final vista = await NominaService.vista(
        tipoPeriodo: _tipoPeriodo,
        periodoId: periodoId ?? _periodo?.entero('id'),
        tipo: _tipo,
      );
      if (mounted) _asignar(vista);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _asignar(Json vista, {bool conservarSeleccion = false}) {
    setState(() {
      _vista = vista;
      _tipoPeriodo = vista.str('tipo_periodo');
      final ids = {for (final f in _filas) f.entero('empleado_id')!};
      _seleccion = conservarSeleccion ? _seleccion.intersection(ids) : ids;
    });
  }

  Future<void> _accion(Future<Json> Function() llamada, String Function(Json r) mensaje) async {
    setState(() => _procesando = true);
    final r = await ejecutar(context, llamada);
    if (mounted) setState(() => _procesando = false);
    if (r == null || !mounted) return;
    _asignar(r.obj('vista')!, conservarSeleccion: true);
    mostrarMensaje(context, mensaje(r));
  }

  String _resumenCalculo(Json r) {
    final res = r.obj('resumen')!;
    final omitidos = res.lista('omitidos');
    return 'Se calcularon ${res.str('calculados')} recibo(s).'
        '${omitidos.isEmpty ? '' : ' Omitidos: ${omitidos.map((o) => '${o.str('empleado')} (${o.str('motivo')})').join(', ')}.'}';
  }

  Future<void> _calcular() async {
    final ok = await confirmar(context,
        titulo: 'Calcular nómina',
        mensaje: 'Se calcularán o recalcularán ${_seleccion.length} recibo(s). '
            'Los recibos ya firmados no se modifican.',
        aceptar: 'Calcular');
    if (!ok) return;
    final periodoId = _periodo!.entero('id')!;
    await _accion(() => NominaService.calcular(periodoId, _tipo, _seleccion.toList()), _resumenCalculo);
  }

  Future<void> _calcularConBruto(Json fila) async {
    final texto = await pedirTexto(
      context,
      titulo: 'Sueldo bruto del periodo',
      descripcion: '${fila.str('nombre')}: el sueldo capturado sustituye al calculado por días '
          '(${moneda(fila.numero('salario_diario'))} diarios).',
      etiqueta: 'Sueldo bruto (\$)',
      boton: 'Calcular ISR',
      lineas: 1,
    );
    final bruto = num.tryParse((texto ?? '').replaceAll(',', ''));
    if (texto == null || !mounted) return;
    if (bruto == null || bruto <= 0) {
      mostrarMensaje(context, 'El sueldo bruto debe ser numérico y mayor a cero.', error: true);
      return;
    }
    final periodoId = _periodo!.entero('id')!;
    await _accion(
      () => NominaService.calcular(periodoId, _tipo, [fila.entero('empleado_id')!], sueldoBruto: bruto),
      _resumenCalculo,
    );
  }

  Future<void> _publicar() async {
    final ok = await confirmar(context,
        titulo: 'Publicar recibos',
        mensaje: 'Los recibos calculados de los empleados seleccionados quedarán disponibles '
            'para que los consulten y firmen.',
        aceptar: 'Publicar');
    if (!ok) return;
    final periodoId = _periodo!.entero('id')!;
    await _accion(() => NominaService.publicar(periodoId, _tipo, _seleccion.toList()),
        (r) => 'Se publicaron ${r.obj('resumen')!.str('publicados')} recibo(s).');
  }

  Future<void> _cerrarOReabrir() async {
    final cerrar = !_cerrada;
    final ok = await confirmar(context,
        titulo: cerrar ? 'Cerrar nómina' : 'Reabrir nómina',
        mensaje: cerrar
            ? 'Al cerrar la nómina ya no podrá recalcularse ni editarse. ¿Continuar?'
            : 'La nómina podrá volver a calcularse y editarse.',
        aceptar: cerrar ? 'Cerrar' : 'Reabrir',
        destructivo: cerrar);
    if (!ok) return;
    final periodoId = _periodo!.entero('id')!;
    await _accion(
      () => cerrar ? NominaService.cerrar(periodoId, _tipo) : NominaService.reabrir(periodoId, _tipo),
      (r) => r.str('mensaje'),
    );
  }

  Future<void> _generarPeriodos() async {
    final mensaje = await ejecutar(context, () => CatalogosService.generarPeriodos(_tipoPeriodo, DateTime.now().year));
    if (mensaje == null || !mounted) return;
    mostrarMensaje(context, mensaje);
    _cargar();
  }

  Future<void> _abrirRecibo(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReciboScreen(reciboId: id)));
    _cargar();
  }

  void _seleccionarPor(String criterio) {
    setState(() {
      _seleccion = {
        for (final f in _filas)
          if (switch (criterio) {
            'todos' => true,
            'sin_calcular' => f['recibo'] == null,
            'calculado' => f.obj('recibo')?.str('estado') == 'calculado',
            _ => false,
          })
            f.entero('empleado_id')!,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final puedeCalcular = session.puede('nomina');
    final hayFilas = _periodo != null && _filas.isNotEmpty;
    return Scaffold(
      bottomNavigationBar: hayFilas && !_cargando
          ? SafeArea(
              child: Container(
                color: NomiColors.card,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: ButtonRow([
                  if (puedeCalcular)
                    NomiButton('Calcular (${_seleccion.length})',
                        icon: Icons.calculate_outlined,
                        outlined: true,
                        onPressed: _cerrada || _seleccion.isEmpty || _procesando ? null : _calcular),
                  NomiButton('Publicar (${_seleccion.length})',
                      icon: Icons.send_outlined,
                      color: NomiColors.darkGreen,
                      loading: _procesando,
                      onPressed: _nomina == null || _seleccion.isEmpty ? null : _publicar),
                ]),
              ),
            )
          : null,
      body: _cuerpo(puedeCalcular),
    );
  }

  Widget _cuerpo(bool puedeCalcular) {
    if (_cargando && _vista == null) return const CargandoView();
    if (_error != null) return ErrorView(_error!, onReintentar: _cargar);
    final periodos = _vista!.lista('periodos');
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _periodicidades)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.$2),
                      selected: _tipoPeriodo == p.$1,
                      selectedColor: NomiColors.blueBg,
                      side: const BorderSide(color: NomiColors.stroke),
                      onSelected: (_) {
                        setState(() {
                          _tipoPeriodo = p.$1;
                          _vista = {..._vista!, 'periodo': null};
                        });
                        _cargar();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (periodos.isEmpty)
            NomiCard(
              child: Column(children: [
                VacioView('No hay periodos ${_tipoPeriodo}es registrados.', icon: Icons.date_range_outlined),
                if (session.puede('catalogos'))
                  NomiButton('Generar periodos ${DateTime.now().year}',
                      icon: Icons.auto_awesome_outlined, onPressed: _generarPeriodos),
              ]),
            )
          else ...[
            NomiCard(
              child: Column(
                children: spaced([
                  NomiSelect<int>(
                    'Periodo de pago',
                    [
                      for (final p in periodos)
                        (p.entero('id')!, '${p.str('nombre')}${p.str('estado') == 'cerrado' ? ' · cerrado' : ''}'),
                    ],
                    value: _periodo?.entero('id'),
                    icon: Icons.date_range_outlined,
                    onChanged: (id) => _cargar(periodoId: id),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'ordinaria', label: Text('Ordinaria')),
                        ButtonSegment(value: 'aguinaldo', label: Text('Aguinaldo')),
                      ],
                      selected: {_tipo},
                      onSelectionChanged: (s) {
                        setState(() => _tipo = s.first);
                        _cargar();
                      },
                    ),
                  ),
                ], 12),
              ),
            ),
            if (_cargando) const LinearProgressIndicator(minHeight: 2),
            ..._resumen(puedeCalcular),
            ..._empleados(puedeCalcular),
          ],
        ],
      ),
    );
  }

  List<Widget> _resumen(bool puedeCalcular) {
    final n = _nomina;
    final total = _filas.length;
    final calculados = _filas.where((f) => f['recibo'] != null).length;
    final publicados = n?.entero('num_publicados') ?? 0;
    final firmados = n?.entero('num_firmados') ?? 0;
    final params = _vista!.obj('parametros');
    return [
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: KpiTile('Percepciones', moneda(n?.numero('total_percepciones')))),
        const SizedBox(width: 8),
        Expanded(child: KpiTile('Deducciones', moneda(n?.numero('total_deducciones')), color: NomiColors.red)),
        const SizedBox(width: 8),
        Expanded(child: KpiTile('Neto', moneda(n?.numero('total_neto')), color: NomiColors.emerald)),
      ]),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Text('$calculados de $total calculados · $publicados por firmar · $firmados firmados',
                style: const TextStyle(fontSize: 12, color: NomiColors.text3)),
          ),
          if (n != null) StatusBadge.nomina(n.str('estado')),
          if (n != null && puedeCalcular)
            IconButton(
              tooltip: _cerrada ? 'Reabrir nómina' : 'Cerrar nómina',
              icon: Icon(_cerrada ? Icons.lock_open_outlined : Icons.lock_outline, size: 20),
              onPressed: _procesando ? null : _cerrarOReabrir,
            ),
        ],
      ),
      const SizedBox(height: 6),
      _BarraAvance(total: total, calculados: calculados, publicados: publicados, firmados: firmados),
      if (params != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Parámetros ${params.str('ejercicio')}: UMA ${moneda(params.numero('uma_diaria'))} · '
            'salario mínimo ${moneda(params.numero('salario_minimo'))} · '
            'subsidio ${moneda(params.numero('subsidio_mensual'))} mensual',
            style: const TextStyle(fontSize: 11, color: NomiColors.text3),
          ),
        ),
    ];
  }

  List<Widget> _empleados(bool puedeCalcular) {
    final todos = _filas.isNotEmpty && _seleccion.length == _filas.length;
    return [
      SectionLabel(
        'Empleados (${_seleccion.length} seleccionados)',
        trailing: _filas.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Seleccionar',
                color: NomiColors.card,
                onSelected: _seleccionarPor,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'todos', child: Text('Todos')),
                  PopupMenuItem(value: 'sin_calcular', child: Text('Sin calcular')),
                  PopupMenuItem(value: 'calculado', child: Text('Calculados (sin publicar)')),
                  PopupMenuItem(value: 'ninguno', child: Text('Ninguno')),
                ],
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(todos ? Icons.check_box : Icons.indeterminate_check_box_outlined,
                      size: 18, color: NomiColors.blue),
                  const SizedBox(width: 4),
                  const Text('Seleccionar', style: TextStyle(color: NomiColors.blue, fontSize: 12)),
                ]),
              ),
      ),
      if (_filas.isEmpty)
        VacioView('No hay empleados con periodicidad $_tipoPeriodo en este periodo.', icon: Icons.people_outline)
      else ...[
        for (final f in _filas) _fila(f, puedeCalcular),
        if (puedeCalcular && !_cerrada)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Mantén presionado un empleado para capturar su sueldo bruto del periodo.',
                style: TextStyle(fontSize: 11.5, color: NomiColors.text3)),
          ),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget _fila(Json f, bool puedeCalcular) {
    final id = f.entero('empleado_id')!;
    final recibo = f.obj('recibo');
    final marcado = _seleccion.contains(id);
    void alternar() => setState(() => marcado ? _seleccion.remove(id) : _seleccion.add(id));
    final detalle = recibo == null
        ? 'No. ${f.str('numero_empleado')} · S.D. ${moneda(f.numero('salario_diario'))}'
        : [
            'No. ${f.str('numero_empleado')}',
            '${numero(recibo.numero('dias_pagados'))} días',
            if (recibo.numero('faltas') > 0) '${recibo.str('faltas')} falta(s)',
            if (recibo.numero('dias_vacaciones') > 0) '${recibo.str('dias_vacaciones')} vac.',
            if (recibo.numero('dias_incapacidad') > 0) '${recibo.str('dias_incapacidad')} incap.',
            if (recibo.numero('aclaraciones_pendientes') > 0) 'aclaración pendiente',
          ].join(' · ');
    return RecordTile(
      title: f.str('nombre'),
      subtitle: detalle,
      accent: recibo == null
          ? NomiColors.text3
          : (recibo.numero('aclaraciones_pendientes') > 0 ? NomiColors.amber : NomiColors.blue),
      leading: Checkbox(value: marcado, activeColor: NomiColors.blue, onChanged: (_) => alternar()),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(recibo == null ? '—' : moneda(recibo.numero('neto')),
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: recibo != null && recibo.numero('neto') < 0 ? NomiColors.red : NomiColors.text1)),
          const SizedBox(height: 4),
          if (recibo != null)
            StatusBadge.recibo(recibo.str('estado'))
          else
            const Text('Sin calcular', style: TextStyle(fontSize: 11, color: NomiColors.text3)),
        ],
      ),
      onTap: recibo == null ? alternar : () => _abrirRecibo(recibo.entero('id')!),
      onLongPress: puedeCalcular && !_cerrada && recibo?.str('estado') != 'firmado' ? () => _calcularConBruto(f) : null,
    );
  }
}

/// Barra de avance: firmados (verde), publicados (ámbar), calculados (azul).
class _BarraAvance extends StatelessWidget {
  final int total;
  final int calculados;
  final int publicados;
  final int firmados;
  const _BarraAvance(
      {required this.total, required this.calculados, required this.publicados, required this.firmados});

  @override
  Widget build(BuildContext context) {
    final t = total == 0 ? 1 : total;
    final segmentos = [
      (firmados, NomiColors.emerald),
      (publicados, NomiColors.amber),
      (calculados - publicados - firmados, NomiColors.blue),
      (total - calculados, NomiColors.stroke),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(children: [
          for (final s in segmentos)
            if (s.$1 > 0) Expanded(flex: (s.$1 * 1000 ~/ t).clamp(1, 1000), child: Container(color: s.$2)),
          if (total == 0) Expanded(child: Container(color: NomiColors.stroke)),
        ]),
      ),
    );
  }
}
