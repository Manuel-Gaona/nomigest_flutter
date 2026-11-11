import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../services/catalogos_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/formulario.dart';
import '../../widgets/nomi_widgets.dart';

/// Formulario de solicitud de vacaciones o permiso (RDF0901). RH elige al
/// empleado; en el portal se usa el del usuario en sesión.
FormularioScreen formularioSolicitud({
  required bool conEmpleado,
  required Future<Json> Function(Json datos) guardar,
}) {
  final hoy = isoFecha(DateTime.now());
  return FormularioScreen(
    titulo: 'Nueva solicitud',
    textoGuardar: 'Registrar solicitud',
    valoresPorDefecto: {'tipo': 'vacaciones', 'fecha_inicial': hoy, 'fecha_final': hoy},
    campos: [
      if (conEmpleado)
        CampoDef('empleado_id', 'Empleado',
            icono: Icons.badge_outlined, tipo: TipoCampo.seleccion, cargarOpciones: CatalogosService.empleados),
      CampoDef('tipo', 'Tipo',
          icono: Icons.beach_access_outlined,
          tipo: TipoCampo.seleccion,
          cargarOpciones: () => CatalogosService.opciones('tipos_solicitud')),
      const CampoDef('fecha_inicial', 'Desde', tipo: TipoCampo.fecha),
      const CampoDef('fecha_final', 'Hasta', tipo: TipoCampo.fecha,
          ayuda: 'Se cuentan solo los días laborables del horario, sin días festivos.'),
      const CampoDef('motivo', 'Motivo / comentarios', icono: Icons.notes, tipo: TipoCampo.multilinea, requerido: false),
    ],
    guardar: guardar,
  );
}

