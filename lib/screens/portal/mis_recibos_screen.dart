import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../core/session.dart';
import '../../services/portal_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';
import 'recibo_empleado_screen.dart';

/// Recibos publicados del empleado en sesión.
class MisRecibosScreen extends StatelessWidget {
  const MisRecibosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (session.empleadoId == null) {
      return const VacioView('Tu usuario no está vinculado a un empleado. Pide al administrador que lo vincule.',
          icon: Icons.link_off);
    }
    return Carga<List<Json>>(
      cargar: PortalService.recibos,
      builder: (context, recibos, recargar) => RefreshIndicator(
        onRefresh: recargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (recibos.isEmpty)
              const VacioView('Aún no tienes recibos publicados.', icon: Icons.receipt_long_outlined)
            else ...[
              _UltimoRecibo(recibos.first, onAbrir: () => _abrir(context, recibos.first, recargar)),
              const SectionLabel('Historial de recibos'),
              for (final r in recibos)
                RecordTile(
                  title: r.str('periodo'),
                  subtitle: '${capitalizar(r.str('tipo_nomina'))} · Pago ${fecha(r.str('fecha_pago'))}',
                  accent: r.str('estado') == 'firmado' ? NomiColors.emerald : NomiColors.amber,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(moneda(r.numero('neto')), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      StatusBadge.recibo(r.str('estado')),
                    ],
                  ),
                  onTap: () => _abrir(context, r, recargar),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _abrir(BuildContext context, Json recibo, Future<void> Function() recargar) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ReciboEmpleadoScreen(reciboId: recibo.entero('id')!)));
    recargar();
  }
}

class _UltimoRecibo extends StatelessWidget {
  final Json recibo;
  final VoidCallback onAbrir;
  const _UltimoRecibo(this.recibo, {required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    return NomiCard(
      color: NomiColors.navy,
      padding: const EdgeInsets.all(20),
      onTap: onAbrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('ÚLTIMO SUELDO NETO',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: Color(0xFFBFDBFE))),
            ),
            StatusBadge.recibo(recibo.str('estado')),
          ]),
          const SizedBox(height: 4),
          Text(moneda(recibo.numero('neto')),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Periodo: ${recibo.str('periodo')}', style: const TextStyle(fontSize: 13, color: Color(0xFFBFDBFE))),
          if (recibo.str('estado') == 'publicado') ...[
            const SizedBox(height: 10),
            const Text('Toca para revisarlo y firmarlo →',
                style: TextStyle(fontSize: 12.5, color: NomiColors.emerald, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
