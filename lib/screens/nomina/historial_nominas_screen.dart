import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../services/nomina_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';
import 'nomina_screen.dart';

/// Nóminas calculadas, de la más reciente a la más antigua.
class HistorialNominasScreen extends StatelessWidget {
  const HistorialNominasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Carga<List<Json>>(
      cargar: NominaService.historial,
      builder: (context, nominas, recargar) => RefreshIndicator(
        onRefresh: recargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (nominas.isEmpty)
              const VacioView('Aún no hay nóminas calculadas.', icon: Icons.history)
            else
              for (final n in nominas)
                RecordTile(
                  title: n.str('periodo'),
                  subtitle: '${capitalizar(n.str('tipo'))} · ${n.str('num_empleados')} empleados · '
                      '${n.str('num_firmados')} firmados',
                  accent: n.str('estado') == 'cerrada' ? NomiColors.text3 : NomiColors.blue,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(moneda(n.numero('total_neto')), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      StatusBadge.nomina(n.str('estado')),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text('Nómina ${n.str('tipo')}')),
                        body: NominaScreen(periodoId: n.entero('periodo_id'), tipo: n.str('tipo')),
                      ),
                    ));
                    recargar();
                  },
                ),
          ],
        ),
      ),
    );
  }
}
