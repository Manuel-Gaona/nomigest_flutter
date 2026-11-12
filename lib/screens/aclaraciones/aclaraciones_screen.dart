import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../services/nomina_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';
import '../nomina/recibo_screen.dart';

/// Dudas de los empleados sobre sus recibos ("Tengo dudas", RDF0802).
class AclaracionesScreen extends StatefulWidget {
  const AclaracionesScreen({super.key});

  @override
  State<AclaracionesScreen> createState() => _AclaracionesScreenState();
}

class _AclaracionesScreenState extends State<AclaracionesScreen> {
  String _estado = 'pendiente';
  final _carga = GlobalKey<CargaState<List<Json>>>();

  Future<void> _atender(Json a) async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.str('empleado'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('${a.str('periodo')} · Neto ${moneda(a.numero('neto'))}',
                style: const TextStyle(color: NomiColors.text3, fontSize: 12.5)),
            const SizedBox(height: 14),
            NomiCard(color: NomiColors.bg, child: Text(a.str('mensaje'))),
            const SizedBox(height: 18),
            ButtonRow([
              NomiButton('Ver recibo', outlined: true, icon: Icons.receipt_long_outlined,
                  onPressed: () => Navigator.pop(ctx, 'recibo')),
              NomiButton('Responder', color: NomiColors.emerald, icon: Icons.reply,
                  onPressed: () => Navigator.pop(ctx, 'responder')),
            ]),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (opcion == 'recibo') {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ReciboScreen(reciboId: a.entero('recibo_id')!)));
    } else if (opcion == 'responder') {
      final respuesta = await pedirTexto(context,
          titulo: 'Responder aclaración',
          descripcion: 'Si corregiste el recibo, recuerda publicarlo de nuevo para que el empleado lo firme.',
          etiqueta: 'Respuesta',
          boton: 'Enviar respuesta',
          color: NomiColors.emerald);
      if (respuesta == null || !mounted) return;
      await ejecutar(context, () => AclaracionesService.responder(a.entero('id')!, respuesta),
          exito: 'Respuesta enviada al empleado.');
    }
    _carga.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'pendiente', label: Text('Pendientes')),
                ButtonSegment(value: 'atendida', label: Text('Atendidas')),
              ],
              selected: {_estado},
              onSelectionChanged: (s) {
                setState(() => _estado = s.first);
                _carga.currentState?.recargar();
              },
            ),
          ),
        ),
        Expanded(
          child: Carga<List<Json>>(
            key: _carga,
            cargar: () => AclaracionesService.listar(estado: _estado),
            builder: (context, aclaraciones, recargar) => RefreshIndicator(
              onRefresh: recargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (aclaraciones.isEmpty)
                    VacioView(_estado == 'pendiente' ? 'No hay dudas pendientes.' : 'No hay aclaraciones atendidas.',
                        icon: Icons.question_answer_outlined)
                  else
                    for (final a in aclaraciones)
                      RecordTile(
                        title: '${a.str('empleado')} · ${a.str('periodo')}',
                        subtitle: a.str('estado') == 'atendida'
                            ? '“${a.str('mensaje')}”\nRespuesta: ${a.str('respuesta')}'
                            : '“${a.str('mensaje')}” · ${fechaHora(a.str('creado_en'))}',
                        accent: a.str('estado') == 'atendida' ? NomiColors.emerald : NomiColors.amber,
                        trailing: a.str('estado') == 'atendida'
                            ? const StatusBadge('Atendida', NomiColors.emerald, NomiColors.emeraldBg)
                            : StatusBadge.pendiente(),
                        onTap: a.str('estado') == 'pendiente' ? () => _atender(a) : null,
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
