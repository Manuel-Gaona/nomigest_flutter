import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../core/session.dart';
import '../../services/crud_service.dart';
import '../../services/nomina_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';

/// Recibo de un empleado (vista de RH): desglose, edición de líneas,
/// recálculo de impuestos y publicación.
class ReciboScreen extends StatefulWidget {
  final int reciboId;
  const ReciboScreen({super.key, required this.reciboId});

  @override
  State<ReciboScreen> createState() => _ReciboScreenState();
}

class _ReciboScreenState extends State<ReciboScreen> {
  Json? _recibo;
  String? _error;
  bool _procesando = false;

  bool get _editable => (_recibo?.flag('editable') ?? false) && session.puede('nomina');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await RecibosService.obtener(widget.reciboId);
      if (mounted) {
        setState(() {
          _recibo = r;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _aplicar(Future<Json> Function() accion, String exito) async {
    setState(() => _procesando = true);
    final r = await ejecutar(context, accion, exito: exito);
    if (!mounted) return;
    setState(() {
      _procesando = false;
      if (r != null) _recibo = r;
    });
  }

  Future<void> _menu(String opcion) async {
    final id = widget.reciboId;
    switch (opcion) {
      case 'publicar':
        await _aplicar(() => RecibosService.publicar(id), 'Recibo publicado para el empleado.');
      case 'recalcular':
        final ok = await confirmar(context,
            titulo: 'Recalcular desde cero',
            mensaje: 'Se descartarán los cambios manuales y se recalculará el recibo.',
            aceptar: 'Recalcular');
        if (ok) await _aplicar(() => RecibosService.recalcular(id), 'Recibo recalculado.');
      case 'quitar':
        final ok = await confirmar(context,
            titulo: 'Quitar de la nómina',
            mensaje: '¿Quitar a ${_recibo!.str('empleado')} de esta nómina?',
            aceptar: 'Quitar',
            destructivo: true);
        if (!ok || !mounted) return;
        final r = await ejecutar(context, () async {
          await RecibosService.quitar(id);
          return true;
        }, exito: 'Empleado quitado de la nómina.');
        if (r == true && mounted) Navigator.pop(context);
    }
  }

  Future<void> _editarLinea(Json linea) async {
    final resultado = await showModalBottomSheet<_ResultadoLinea>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LineaSheet(linea: linea),
    );
    if (resultado == null) return;
    final id = widget.reciboId;
    final detalleId = linea.entero('id')!;
    if (resultado.eliminar) {
      await _aplicar(() => RecibosService.eliminarLinea(id, detalleId), 'Línea eliminada.');
    } else {
      await _aplicar(() => RecibosService.editarLinea(id, detalleId, resultado.datos), 'Línea actualizada.');
    }
  }

  Future<void> _agregarLinea() async {
    final conceptos = await ejecutar(context, () => conceptosService.listar());
    if (conceptos == null || !mounted) return;
    final disponibles = conceptos.where((c) => !const ['ISR', 'IMSS'].contains(c['codigo'])).toList();
    final resultado = await showModalBottomSheet<_ResultadoLinea>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LineaSheet(conceptos: disponibles),
    );
    if (resultado == null) return;
    await _aplicar(() => RecibosService.agregarLinea(widget.reciboId, resultado.datos), 'Línea agregada.');
  }

  @override
  Widget build(BuildContext context) {
    final r = _recibo;
    return Scaffold(
      appBar: AppBar(
        title: Text(r == null ? 'Recibo' : 'Recibo ${r.str('numero_empleado')}'),
        actions: [
          if (r != null && (_editable || (r.str('estado') == 'calculado' && session.puedeAlguno(['nomina', 'recibos']))))
            PopupMenuButton<String>(
              color: NomiColors.card,
              onSelected: _menu,
              itemBuilder: (_) => [
                if (r.str('estado') == 'calculado')
                  const PopupMenuItem(value: 'publicar', child: Text('Publicar al empleado')),
                if (_editable) ...[
                  const PopupMenuItem(value: 'recalcular', child: Text('Recalcular desde cero')),
                  const PopupMenuItem(
                      value: 'quitar', child: Text('Quitar de la nómina', style: TextStyle(color: NomiColors.red))),
                ],
              ],
            ),
        ],
      ),
      body: r == null
          ? (_error == null ? const CargandoView() : ErrorView(_error!, onReintentar: _cargar))
          : RefreshIndicator(onRefresh: _cargar, child: _contenido(r)),
    );
  }

  Widget _contenido(Json r) {
    final neto = r.numero('neto');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_procesando) const LinearProgressIndicator(minHeight: 2),
        NomiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.str('empleado'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('No. ${r.str('numero_empleado')} · ${r.str('departamento')}',
                          style: const TextStyle(color: NomiColors.text3, fontSize: 12)),
                      Text('${r.str('periodo')} · ${capitalizar(r.str('tipo_nomina'))}',
                          style: const TextStyle(color: NomiColors.text3, fontSize: 12)),
                    ]),
                  ),
                  StatusBadge.recibo(r.str('estado')),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(child: Text('Neto a pagar', style: TextStyle(color: NomiColors.text3))),
                  Text(moneda(neto),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: neto < 0 ? NomiColors.red : NomiColors.emerald)),
                ],
              ),
              if (neto < 0) _aviso('El neto es negativo: revisa las deducciones.', NomiColors.amber),
              if (r.str('estado') == 'firmado')
                _aviso('Firmado por el empleado el ${fechaHora(r.str('firmado_en'))}. Ya no puede modificarse.',
                    NomiColors.emerald, Icons.verified_outlined),
              if (r.numero('aclaraciones_pendientes') > 0)
                _aviso('El empleado tiene dudas sobre este recibo. Atiéndelas en Aclaraciones.', NomiColors.amber,
                    Icons.question_answer_outlined),
              if (!r.flag('editable') && r.str('estado') != 'firmado')
                _aviso('La nómina está cerrada.', NomiColors.text3, Icons.lock_outline),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.7,
          children: [
            KpiTile('Días pagados', numero(r.numero('dias_pagados'))),
            KpiTile('S.D.', moneda(r.numero('salario_diario'))),
            KpiTile('SDI', moneda(r.numero('sdi'))),
            KpiTile('Faltas', r.str('faltas')),
            KpiTile('Incapacidad', r.str('dias_incapacidad')),
            KpiTile('Vacaciones', r.str('dias_vacaciones')),
          ],
        ),
        _seccion('Percepciones', r.lista('percepciones'), r.numero('total_percepciones'), true),
        _seccion('Deducciones', r.lista('deducciones'), r.numero('total_deducciones'), false),
        const SizedBox(height: 8),
        Text(
          'Base gravable ${moneda(r.numero('total_gravado'))} · Exento ${moneda(r.numero('total_exento'))} · '
          'ISR causado ${moneda(r.numero('isr_causado'))} · Subsidio causado ${moneda(r.numero('subsidio_causado'))} '
          '(aplicado ${moneda(r.numero('subsidio_aplicado'))})',
          style: const TextStyle(fontSize: 11.5, color: NomiColors.text3),
        ),
        if (_editable) ...[
          const SizedBox(height: 16),
          ButtonRow([
            NomiButton('Agregar línea', icon: Icons.add, outlined: true, onPressed: _procesando ? null : _agregarLinea),
            NomiButton('Recalcular ISR/IMSS',
                icon: Icons.refresh,
                onPressed: _procesando
                    ? null
                    : () => _aplicar(() => RecibosService.recalcularImpuestos(widget.reciboId), 'Impuestos recalculados.')),
          ]),
          const SizedBox(height: 8),
          const Text('Toca una línea para editarla. Después de modificar percepciones usa '
              'Recalcular ISR/IMSS para actualizar los impuestos.',
              style: TextStyle(fontSize: 11.5, color: NomiColors.text3)),
        ],
        if (r.lista('aclaraciones').isNotEmpty) ...[
          const SectionLabel('Aclaraciones del empleado'),
          for (final a in r.lista('aclaraciones'))
            RecordTile(
              title: a.str('mensaje'),
              subtitle: a.str('estado') == 'atendida'
                  ? 'Respuesta: ${a.str('respuesta')}'
                  : 'Enviada el ${fechaHora(a.str('creado_en'))}',
              accent: a.str('estado') == 'atendida' ? NomiColors.emerald : NomiColors.amber,
              trailing: a.str('estado') == 'atendida'
                  ? const StatusBadge('Atendida', NomiColors.emerald, NomiColors.emeraldBg)
                  : StatusBadge.pendiente(),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _aviso(String texto, Color color, [IconData icono = Icons.warning_amber_outlined]) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 12.5, color: color))),
        ]),
      );

  Widget _seccion(String titulo, List<Json> lineas, num total, bool percepcion) {
    final color = percepcion ? NomiColors.emerald : NomiColors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(titulo,
            trailing: Text(moneda(total),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
        if (lineas.isEmpty)
          Text('Sin ${titulo.toLowerCase()}.', style: const TextStyle(color: NomiColors.text3, fontSize: 13))
        else
          for (final d in lineas)
            RecordTile(
              title: d.str('nombre'),
              subtitle: [
                '${d.str('clave')} · SAT ${d['clave_sat'] ?? '—'}',
                if (d.numero('cantidad') > 0) 'cant. ${numero(d.numero('cantidad'))}',
                if (percepcion) '\nGravado ${moneda(d.numero('gravado'))} · Exento ${moneda(d.numero('exento'))}',
              ].join(' · ').replaceAll(' · \n', '\n'),
              accent: color,
              trailing: Text(moneda(d.numero('importe')), style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: _editable && !_procesando ? () => _editarLinea(d) : null,
            ),
      ],
    );
  }
}

class _ResultadoLinea {
  final Json datos;
  final bool eliminar;
  const _ResultadoLinea(this.datos, {this.eliminar = false});
}

/// Hoja para agregar (con [conceptos]) o editar (con [linea]) una línea del recibo.
class _LineaSheet extends StatefulWidget {
  final Json? linea;
  final List<Json>? conceptos;
  const _LineaSheet({this.linea, this.conceptos});

  @override
  State<_LineaSheet> createState() => _LineaSheetState();
}

class _LineaSheetState extends State<_LineaSheet> {
  final _formKey = GlobalKey<FormState>();
  int? _conceptoId;
  late final _cantidad = TextEditingController(text: _txt('cantidad', '1'));
  late final _gravado = TextEditingController(text: _txt('gravado', ''));
  late final _exento = TextEditingController(text: _txt('exento', ''));
  late final _importe = TextEditingController(text: _txt('importe', ''));

  String _txt(String campo, String defecto) {
    final v = widget.linea?[campo];
    return v == null ? defecto : (v as num).toStringAsFixed(2);
  }

  String get _tipo {
    if (widget.linea != null) return widget.linea!.str('tipo');
    final c = widget.conceptos!.where((c) => c.entero('id') == _conceptoId).firstOrNull;
    return c?.str('tipo') ?? 'percepcion';
  }

  String? _numero(String? v, {bool requerido = false}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return requerido ? 'Obligatorio.' : null;
    final n = num.tryParse(t);
    return n == null || n < 0 ? 'Valor inválido.' : null;
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final datos = <String, dynamic>{
      if (_conceptoId != null) 'concepto_id': _conceptoId,
      'cantidad': num.tryParse(_cantidad.text) ?? 1,
      if (_tipo == 'percepcion') ...{
        'gravado': num.tryParse(_gravado.text) ?? 0,
        'exento': num.tryParse(_exento.text) ?? 0,
      } else
        'importe': num.tryParse(_importe.text),
    };
    Navigator.pop(context, _ResultadoLinea(datos));
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.linea != null;
    final percepcion = _tipo == 'percepcion';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(editando ? widget.linea!.str('nombre') : 'Agregar percepción o deducción',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            if (!editando) ...[
              NomiSelect<int>(
                'Concepto',
                [
                  for (final c in widget.conceptos!)
                    (c.entero('id')!, '${c.str('tipo') == 'percepcion' ? '+' : '−'} ${c.str('clave')} · ${c.str('nombre')}'),
                ],
                value: _conceptoId,
                icon: Icons.edit_note,
                validator: (v) => v == null ? 'Selecciona un concepto.' : null,
                onChanged: (v) => setState(() => _conceptoId = v),
              ),
              const SizedBox(height: 14),
            ],
            NomiField('Cantidad',
                controller: _cantidad, keyboard: const TextInputType.numberWithOptions(decimal: true),
                validator: _numero),
            const SizedBox(height: 14),
            if (percepcion)
              Row(children: [
                Expanded(
                  child: NomiField('Gravado',
                      controller: _gravado,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                      validator: _numero),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NomiField('Exento',
                      controller: _exento,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                      validator: _numero),
                ),
              ])
            else
              NomiField('Importe (\$)',
                  controller: _importe,
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _numero(v, requerido: true)),
            const SizedBox(height: 18),
            ButtonRow([
              if (editando)
                NomiButton('Eliminar',
                    color: NomiColors.red,
                    outlined: true,
                    icon: Icons.delete_outline,
                    onPressed: () => Navigator.pop(context, const _ResultadoLinea({}, eliminar: true))),
              NomiButton(editando ? 'Guardar' : 'Agregar', color: NomiColors.darkGreen, onPressed: _guardar),
            ]),
          ],
        ),
      ),
    );
  }
}
