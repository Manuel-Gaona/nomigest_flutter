import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../core/session.dart';
import '../../services/catalogos_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';

/// Tablero de inicio con los pendientes del usuario según su rol.
class InicioScreen extends StatelessWidget {
  final void Function(String id) onNavegar;
  const InicioScreen({super.key, required this.onNavegar});

  @override
  Widget build(BuildContext context) {
    return Carga<Json>(
      cargar: CatalogosService.tablero,
      builder: (context, t, recargar) {
        final tiles = <Widget>[
          if (t.containsKey('recibos_por_firmar'))
            KpiTile('Recibos por firmar', t.str('recibos_por_firmar'),
                icon: Icons.draw_outlined,
                color: t.numero('recibos_por_firmar') > 0 ? NomiColors.amber : NomiColors.text1,
                onTap: () => onNavegar('mis_recibos')),
          if (t.containsKey('empleados_activos'))
            KpiTile('Empleados activos', t.str('empleados_activos'),
                icon: Icons.badge_outlined, onTap: () => onNavegar('empleados')),
          if (t.containsKey('solicitudes_pendientes'))
            KpiTile('Solicitudes pendientes', t.str('solicitudes_pendientes'),
                icon: Icons.beach_access_outlined,
                color: t.numero('solicitudes_pendientes') > 0 ? NomiColors.amber : NomiColors.text1,
                onTap: () => onNavegar('vacaciones')),
          if (t.containsKey('aclaraciones_pendientes'))
            KpiTile('Aclaraciones', t.str('aclaraciones_pendientes'),
                icon: Icons.question_answer_outlined,
                color: t.numero('aclaraciones_pendientes') > 0 ? NomiColors.amber : NomiColors.text1,
                onTap: () => onNavegar('aclaraciones')),
          if (t.containsKey('restablecer_password'))
            KpiTile('Restablecer contraseña', t.str('restablecer_password'),
                icon: Icons.lock_reset,
                color: t.numero('restablecer_password') > 0 ? NomiColors.amber : NomiColors.text1,
                onTap: () => onNavegar('usuarios')),
        ];
        final nomina = t.obj('ultima_nomina');
        return RefreshIndicator(
          onRefresh: recargar,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NomiCard(
                gradient: const LinearGradient(colors: [NomiColors.navy, NomiColors.blue]),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const NomiLogo(size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hola, ${session.nombreUsuario}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(session.rol, style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (tiles.isNotEmpty) ...[
                const SectionLabel('Pendientes'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2,
                  children: tiles,
                ),
              ],
              if (nomina != null) ...[
                const SectionLabel('Última nómina'),
                NomiCard(
                  onTap: () => onNavegar('nomina'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(nomina.str('periodo'),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        StatusBadge.nomina(nomina.str('estado')),
                      ]),
                      const SizedBox(height: 12),
                      ...spaced([
                        KvRow('Empleados', nomina.str('num_empleados')),
                        KvRow('Percepciones', moneda(nomina.numero('total_percepciones'))),
                        KvRow('Deducciones', '-${moneda(nomina.numero('total_deducciones'))}',
                            color: NomiColors.red),
                        KvRow('Firmados', '${nomina.str('num_firmados')} de ${nomina.str('num_empleados')}'),
                      ], 8),
                      const NomiDivider(),
                      KvRow('Neto pagado', moneda(nomina.numero('total_neto')),
                          color: NomiColors.emerald, bold: true),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
