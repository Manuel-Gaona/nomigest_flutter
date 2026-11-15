import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../services/portal_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';
import 'pin_sheet.dart';

/// Vista del empleado: Sueldo Neto + desglose + Tengo Dudas / De Acuerdo (firma con PIN).
class ReciboEmpleadoScreen extends StatefulWidget {
  final int reciboId;
  const ReciboEmpleadoScreen({super.key, required this.reciboId});

  @override
  State<ReciboEmpleadoScreen> createState() => _ReciboEmpleadoScreenState();
}

class _ReciboEmpleadoScreenState extends State<ReciboEmpleadoScreen> {
  final _carga = GlobalKey<CargaState<Json>>();

  Future<void> _tengoDudas() async {
    final mensaje = await pedirTexto(
      context,
      titulo: 'Tengo dudas',
      descripcion: 'Describe tu duda; Recursos Humanos la revisará. Podrás firmar cuando te respondan.',
      etiqueta: 'Mensaje',
      boton: 'Enviar a Recursos Humanos',
    );
    if (mensaje == null || !mounted) return;
    final ok = await ejecutar(context, () async {
      await PortalService.tengoDudas(widget.reciboId, mensaje);
      return true;
    }, exito: 'Tu duda se envió a Recursos Humanos.');
    if (ok == true) _carga.currentState?.recargar();
  }

  Future<void> _deAcuerdo() async {
    final pin = await PinSheet.mostrar(context);
    if (pin == null || !mounted) return;
    try {
      await PortalService.firmar(widget.reciboId, pin);
      if (!mounted) return;
      mostrarMensaje(context, 'Recibo firmado. ¡Gracias!');
      _carga.currentState?.recargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 428) {
        await _crearPin();
      } else {
        mostrarMensaje(context, e.message, error: true);
      }
    }
  }

  /// Primera firma: el empleado aún no tiene PIN.
  Future<void> _crearPin() async {
    final nuevo = await PinSheet.mostrar(context,
        titulo: 'Crea tu PIN', descripcion: 'Aún no tienes PIN. Elige 4 dígitos que solo tú conozcas.', boton: 'Continuar');
    if (nuevo == null || !mounted) return;
    final confirmacion = await PinSheet.mostrar(context,
        titulo: 'Confirma tu PIN', descripcion: 'Escribe de nuevo los 4 dígitos.', boton: 'Guardar PIN');
    if (confirmacion == null || !mounted) return;
    if (confirmacion != nuevo) {
      mostrarMensaje(context, 'Los PIN no coinciden. Intenta de nuevo.', error: true);
      return;
    }
    final ok = await ejecutar(context, () async {
      await PortalService.guardarPin(nuevo);
      return true;
    }, exito: 'PIN guardado. Ahora firma tu recibo.');
    if (ok == true && mounted) _deAcuerdo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Recibo de Nómina')),
      body: Carga<Json>(
        key: _carga,
        cargar: () => PortalService.recibo(widget.reciboId),
        builder: (context, r, recargar) => RefreshIndicator(onRefresh: recargar, child: _contenido(r)),
      ),
    );
  }

  Widget _contenido(Json r) {
    final firmado = r.str('estado') == 'firmado';
    final pendiente = r.numero('aclaraciones_pendientes') > 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NomiCard(
          color: NomiColors.navy,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SUELDO NETO',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: Color(0xFFBFDBFE))),
              const SizedBox(height: 4),
              Text(moneda(r.numero('neto')),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Periodo: ${r.str('periodo')}', style: const TextStyle(fontSize: 13, color: Color(0xFFBFDBFE))),
              Text('Días pagados: ${numero(r.numero('dias_pagados'))} · Pago ${fecha(r.str('fecha_pago'))}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFFBFDBFE))),
            ],
          ),
        ),
        const SectionLabel('Percepciones'),
        _desglose(r.lista('percepciones'), 'Total percepciones', r.numero('total_percepciones'), true),
        const SectionLabel('Deducciones'),
        _desglose(r.lista('deducciones'), 'Total deducciones', r.numero('total_deducciones'), false),
        if (r.lista('aclaraciones').isNotEmpty) ...[
          const SectionLabel('Mis aclaraciones'),
          for (final a in r.lista('aclaraciones'))
            RecordTile(
              title: a.str('mensaje'),
              subtitle: a.str('estado') == 'atendida'
                  ? 'Respuesta de RH: ${a.str('respuesta')}'
                  : 'En revisión por Recursos Humanos',
              accent: a.str('estado') == 'atendida' ? NomiColors.emerald : NomiColors.amber,
              trailing: a.str('estado') == 'atendida'
                  ? const StatusBadge('Atendida', NomiColors.emerald, NomiColors.emeraldBg)
                  : StatusBadge.pendiente(),
            ),
        ],
        const SizedBox(height: 24),
        if (firmado)
          NomiCard(
            color: NomiColors.emeraldBg,
            child: Row(children: [
              const Icon(Icons.verified_outlined, color: NomiColors.emerald),
              const SizedBox(width: 10),
              Expanded(child: Text('Firmaste este recibo el ${fechaHora(r.str('firmado_en'))}.')),
            ]),
          )
        else ...[
          if (pendiente)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Podrás firmar cuando Recursos Humanos responda tu duda.',
                  style: TextStyle(color: NomiColors.amber, fontSize: 12.5)),
            ),
          ButtonRow([
            NomiButton('Tengo Dudas', outlined: true, height: 52, onPressed: _tengoDudas),
            NomiButton('De Acuerdo', color: NomiColors.emerald, height: 52, onPressed: pendiente ? null : _deAcuerdo),
          ]),
        ],
      ],
    );
  }

  Widget _desglose(List<Json> lineas, String etiquetaTotal, num total, bool percepcion) {
    return NomiCard(
      child: Column(
        children: [
          if (lineas.isEmpty)
            const Text('Sin conceptos.', style: TextStyle(color: NomiColors.text3))
          else
            ...spaced([
              for (final d in lineas)
                KvRow(d.str('nombre'), '${percepcion ? '' : '-'}${moneda(d.numero('importe'))}',
                    color: percepcion ? NomiColors.text1 : NomiColors.red),
            ], 10),
          const NomiDivider(),
          KvRow(etiquetaTotal, '${percepcion ? '' : '-'}${moneda(total)}',
              color: percepcion ? NomiColors.text1 : NomiColors.red, bold: true),
        ],
      ),
    );
  }
}
