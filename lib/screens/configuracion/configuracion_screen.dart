import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../services/catalogos_service.dart';
import '../../services/configuracion_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/formulario.dart';
import '../../widgets/nomi_widgets.dart';

/// Datos de la empresa, parámetros fiscales por ejercicio y tarifa de ISR.
class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _carga = GlobalKey<CargaState<(Json, List<Json>, Json)>>();

  Future<(Json, List<Json>, Json)> _cargar() async => (
        await ConfiguracionService.empresa(),
        await ConfiguracionService.parametros(),
        await ConfiguracionService.tarifaIsr(),
      );

  static final _camposEmpresa = [
    const CampoDef('razon_social', 'Razón social', icono: Icons.business_outlined),
    const CampoDef('rfc', 'RFC', icono: Icons.fingerprint, requerido: false, maxLength: 13),
    const CampoDef('registro_patronal', 'Registro patronal IMSS', icono: Icons.tag, requerido: false),
    CampoDef('zona_salario', 'Zona de salario mínimo',
        icono: Icons.map_outlined,
        tipo: TipoCampo.seleccion,
        cargarOpciones: () => CatalogosService.opciones('zonas_salario')),
    const CampoDef('dias_aguinaldo', 'Días de aguinaldo', icono: Icons.card_giftcard, tipo: TipoCampo.entero,
        ayuda: 'Mínimo 15 días (LFT art. 87).'),
    const CampoDef('prima_vacacional_pct', 'Prima vacacional (%)', icono: Icons.percent, tipo: TipoCampo.decimal,
        ayuda: 'Mínimo 25% (LFT art. 80).'),
  ];

  static const _camposParametro = [
    CampoDef('ejercicio', 'Ejercicio', icono: Icons.calendar_today_outlined, tipo: TipoCampo.entero),
    CampoDef('uma_diaria', 'UMA diaria (\$)', icono: Icons.attach_money, tipo: TipoCampo.decimal),
    CampoDef('salario_minimo', 'Salario mínimo general (\$)', icono: Icons.attach_money, tipo: TipoCampo.decimal),
    CampoDef('salario_minimo_frontera', 'Salario mínimo frontera norte (\$)',
        icono: Icons.attach_money, tipo: TipoCampo.decimal),
    CampoDef('subsidio_pct_uma', 'Subsidio al empleo (% de UMA mensual)', icono: Icons.percent, tipo: TipoCampo.decimal),
    CampoDef('subsidio_limite_mensual', 'Límite de ingreso para subsidio (\$ mensual)',
        icono: Icons.attach_money, tipo: TipoCampo.decimal),
  ];

  Future<void> _editar(Widget pantalla) async {
    final r = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
    if (r != null && mounted) {
      mostrarMensaje(context, 'Cambios guardados.');
      _carga.currentState?.recargar();
    }
  }

  void _editarEmpresa(Json empresa) => _editar(FormularioScreen(
        titulo: 'Datos de la empresa',
        campos: _camposEmpresa,
        inicial: empresa,
        guardar: ConfiguracionService.guardarEmpresa,
      ));

  void _editarParametro([Json? p]) {
    final id = p?.entero('id');
    _editar(FormularioScreen(
      titulo: id == null ? 'Nuevo ejercicio fiscal' : 'Parámetros ${p!.str('ejercicio')}',
      campos: _camposParametro,
      inicial: p,
      valoresPorDefecto: {'ejercicio': DateTime.now().year},
      guardar: (datos) =>
          id == null ? ConfiguracionService.crearParametro(datos) : ConfiguracionService.modificarParametro(id, datos),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Carga<(Json, List<Json>, Json)>(
      key: _carga,
      cargar: _cargar,
      builder: (context, datos, recargar) {
        final (empresa, parametros, tarifa) = datos;
        return RefreshIndicator(
          onRefresh: recargar,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionLabel('Empresa',
                  top: 0,
                  trailing: TextButton(onPressed: () => _editarEmpresa(empresa), child: const Text('Editar'))),
              NomiCard(
                onTap: () => _editarEmpresa(empresa),
                child: Column(
                  children: spaced([
                    KvRow('Razón social', empresa.str('razon_social')),
                    KvRow('RFC', empresa['rfc'] == null ? '—' : empresa.str('rfc')),
                    KvRow('Registro patronal', empresa['registro_patronal'] == null ? '—' : empresa.str('registro_patronal')),
                    KvRow('Zona salarial', empresa.str('zona_salario') == 'frontera' ? 'Frontera norte' : 'General'),
                    KvRow('Días de aguinaldo', empresa.str('dias_aguinaldo')),
                    KvRow('Prima vacacional', '${numero(empresa.numero('prima_vacacional_pct'))}%'),
                  ], 8),
                ),
              ),
              SectionLabel('Parámetros por ejercicio',
                  trailing: TextButton(onPressed: _editarParametro, child: const Text('Agregar'))),
              for (final p in parametros)
                RecordTile(
                  title: 'Ejercicio ${p.str('ejercicio')}',
                  subtitle: 'UMA ${moneda(p.numero('uma_diaria'))} · S.M. ${moneda(p.numero('salario_minimo'))} · '
                      'Subsidio ${numero(p.numero('subsidio_pct_uma'))}% UMA',
                  onTap: () => _editarParametro(p),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Valida los valores de cada año contra el DOF (INEGI, CONASAMI y decreto de subsidio).',
                    style: TextStyle(fontSize: 11.5, color: NomiColors.amber)),
              ),
              SectionLabel('Tarifa mensual ISR (art. 96 LISR) · ${tarifa.str('ejercicio')}'),
              NomiCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  children: [
                    const _FilaTarifa('Límite inferior', 'Cuota fija', '% excedente', encabezado: true),
                    for (final t in tarifa.lista('renglones'))
                      _FilaTarifa(moneda(t.numero('limite_inferior')), moneda(t.numero('cuota_fija')),
                          '${numero(t.numero('porcentaje'))}%'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text('Para cargar una tarifa nueva usa PUT /api/configuracion/tarifa-isr (ver README de la API).',
                  style: TextStyle(fontSize: 11.5, color: NomiColors.text3)),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _FilaTarifa extends StatelessWidget {
  final String a;
  final String b;
  final String c;
  final bool encabezado;
  const _FilaTarifa(this.a, this.b, this.c, {this.encabezado = false});

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: encabezado ? 11 : 12.5,
      fontWeight: encabezado ? FontWeight.w700 : FontWeight.w400,
      color: encabezado ? NomiColors.text3 : NomiColors.text1,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(flex: 4, child: Text(a, style: estilo)),
        Expanded(flex: 4, child: Text(b, style: estilo, textAlign: TextAlign.right)),
        Expanded(flex: 3, child: Text(c, style: estilo, textAlign: TextAlign.right)),
      ]),
    );
  }
}
