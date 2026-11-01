import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/json.dart';
import '../services/catalogos_service.dart';
import '../theme/nomi_theme.dart';
import 'feedback.dart';
import 'nomi_widgets.dart';

enum TipoCampo { texto, entero, decimal, password, seleccion, fecha, hora, booleano, multilinea, diasSemana, seccion }

/// Definición de un campo de formulario. La [clave] es el nombre del campo en la API.
class CampoDef {
  final String clave;
  final String etiqueta;
  final IconData? icono;
  final TipoCampo tipo;
  final bool requerido;

  /// Solo obligatorio al crear (p. ej. la contraseña); al editar, vacío = no cambiar.
  final bool soloAlCrear;

  /// false: se muestra pero no se puede modificar al editar (p. ej. identificadores).
  final bool editable;
  final List<Opcion<dynamic>>? opciones;
  final Future<List<Opcion<dynamic>>> Function()? cargarOpciones;
  final bool Function(Json valores)? visibleSi;
  final String Function(Json valores)? etiquetaSi;
  final String? ayuda;
  final int? maxLength;
  final List<TextInputFormatter>? formatos;
  final String? Function(String valor)? validar;

  const CampoDef(
    this.clave,
    this.etiqueta, {
    this.icono,
    this.tipo = TipoCampo.texto,
    this.requerido = true,
    this.soloAlCrear = false,
    this.editable = true,
    this.opciones,
    this.cargarOpciones,
    this.visibleSi,
    this.etiquetaSi,
    this.ayuda,
    this.maxLength,
    this.formatos,
    this.validar,
  });

  /// Encabezado de sección dentro del formulario.
  const CampoDef.seccion(this.etiqueta)
      : clave = '',
        icono = null,
        tipo = TipoCampo.seccion,
        requerido = false,
        soloAlCrear = false,
        editable = true,
        opciones = null,
        cargarOpciones = null,
        visibleSi = null,
        etiquetaSi = null,
        ayuda = null,
        maxLength = null,
        formatos = null,
        validar = null;

  bool get esTexto => const {
        TipoCampo.texto,
        TipoCampo.entero,
        TipoCampo.decimal,
        TipoCampo.password,
        TipoCampo.multilinea,
      }.contains(tipo);
}

/// Pantalla de alta / edición construida a partir de [CampoDef].
///
/// Si [inicial] es null es un alta; si no, una edición del registro.
class FormularioScreen extends StatefulWidget {
  final String titulo;
  final List<CampoDef> campos;
  final Json? inicial;
  final Json valoresPorDefecto;
  final Future<Json> Function(Json datos) guardar;
  final Future<void> Function()? eliminar;
  final String textoEliminar;
  final String? confirmacionEliminar;
  final Future<void> Function()? reactivar;
  final String textoGuardar;
  final Widget Function(BuildContext context, Json registro)? extra;

  const FormularioScreen({
    super.key,
    required this.titulo,
    required this.campos,
    required this.guardar,
    this.inicial,
    this.valoresPorDefecto = const {},
    this.eliminar,
    this.textoEliminar = 'Eliminar',
    this.confirmacionEliminar,
    this.reactivar,
    this.textoGuardar = 'Guardar',
    this.extra,
  });

  bool get editando => inicial != null;

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _opciones = <String, List<Opcion<dynamic>>>{};
  late final Json _valores;
  Map<String, String> _errores = {};
  bool _guardando = false;
  bool _cargandoOpciones = true;

  @override
  void initState() {
    super.initState();
    _valores = {...widget.valoresPorDefecto, ...?widget.inicial};
    for (final c in widget.campos.where((c) => c.esTexto)) {
      final v = _valores[c.clave];
      final texto = c.tipo == TipoCampo.password || v == null ? '' : _textoInicial(v);
      _controllers[c.clave] = TextEditingController(text: texto);
    }
    _cargarOpciones();
  }

  String _textoInicial(dynamic v) => v is double && v == v.roundToDouble() ? v.toStringAsFixed(2) : '$v';

  Future<void> _cargarOpciones() async {
    try {
      for (final c in widget.campos) {
        if (c.opciones != null) _opciones[c.clave] = c.opciones!;
        if (c.cargarOpciones != null) _opciones[c.clave] = await c.cargarOpciones!();
      }
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.message, error: true);
    }
    if (mounted) setState(() => _cargandoOpciones = false);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _visible(CampoDef c) => c.visibleSi == null || c.visibleSi!(_valores);

  bool _bloqueado(CampoDef c) => widget.editando && !c.editable;

  bool _obligatorio(CampoDef c) => c.requerido && !(c.soloAlCrear && widget.editando);

  Json _datos() {
    final datos = <String, dynamic>{};
    for (final c in widget.campos) {
      if (c.tipo == TipoCampo.seccion || !_visible(c) || _bloqueado(c)) continue;
      dynamic valor;
      if (c.esTexto) {
        final texto = _controllers[c.clave]!.text.trim();
        if (texto.isEmpty && c.soloAlCrear && widget.editando) continue;
        valor = switch (c.tipo) {
          _ when texto.isEmpty => null,
          TipoCampo.entero => int.tryParse(texto) ?? texto,
          TipoCampo.decimal => num.tryParse(texto.replaceAll(',', '')) ?? texto,
          _ => texto,
        };
      } else {
        valor = _valores[c.clave];
      }
      datos[c.clave] = valor;
    }
    return datos;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _errores = {});
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final resultado = await widget.guardar(_datos());
      if (mounted) Navigator.pop(context, resultado);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errores = e.errores);
      mostrarMensaje(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _accion(Future<void> Function() accion, String exito) async {
    final ok = await ejecutar(context, () async {
      await accion();
      return true;
    }, exito: exito);
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _eliminar() async {
    final ok = await confirmar(
      context,
      titulo: widget.textoEliminar,
      mensaje: widget.confirmacionEliminar ?? '¿Deseas continuar?',
      aceptar: widget.textoEliminar,
      destructivo: true,
    );
    if (ok && mounted) await _accion(widget.eliminar!, 'Registro actualizado.');
  }

  Future<void> _elegirFecha(CampoDef c) async {
    final actual = DateTime.tryParse('${_valores[c.clave] ?? ''}') ?? DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (elegida != null) setState(() => _valores[c.clave] = isoFecha(elegida));
  }

  Future<void> _elegirHora(CampoDef c) async {
    final partes = '${_valores[c.clave] ?? '08:00'}'.split(':');
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(partes[0]) ?? 8, minute: int.tryParse(partes.last) ?? 0),
      builder: (ctx, child) =>
          MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (elegida != null) {
      setState(() => _valores[c.clave] =
          '${elegida.hour.toString().padLeft(2, '0')}:${elegida.minute.toString().padLeft(2, '0')}');
    }
  }

  String? _validarTexto(CampoDef c, String? v) {
    final texto = (v ?? '').trim();
    if (texto.isEmpty) return _obligatorio(c) ? 'Campo obligatorio.' : null;
    if (c.tipo == TipoCampo.entero && int.tryParse(texto) == null) return 'Debe ser un número entero.';
    if (c.tipo == TipoCampo.decimal && num.tryParse(texto.replaceAll(',', '')) == null) {
      return 'Debe ser un valor numérico.';
    }
    return c.validar?.call(texto);
  }

  Widget _campo(CampoDef c) {
    final etiqueta = c.etiquetaSi?.call(_valores) ?? c.etiqueta;
    final error = _errores[c.clave];
    final bloqueado = _bloqueado(c);
    switch (c.tipo) {
      case TipoCampo.seccion:
        return SectionLabel(c.etiqueta, top: 6);
      case TipoCampo.texto:
      case TipoCampo.entero:
      case TipoCampo.decimal:
      case TipoCampo.password:
      case TipoCampo.multilinea:
        final numerico = c.tipo == TipoCampo.entero || c.tipo == TipoCampo.decimal;
        return NomiField(
          etiqueta,
          icon: c.icono,
          controller: _controllers[c.clave],
          obscure: c.tipo == TipoCampo.password,
          maxLines: c.tipo == TipoCampo.multilinea ? 3 : 1,
          maxLength: c.maxLength,
          enabled: !bloqueado,
          keyboard: numerico
              ? TextInputType.numberWithOptions(decimal: c.tipo == TipoCampo.decimal)
              : (c.tipo == TipoCampo.multilinea ? TextInputType.multiline : null),
          formatters: c.formatos,
          helper: c.ayuda ?? (c.soloAlCrear && widget.editando ? 'Déjalo vacío para conservar el actual.' : null),
          errorText: error,
          validator: (v) => _validarTexto(c, v),
        );
      case TipoCampo.seleccion:
        final opciones = _opciones[c.clave] ?? const [];
        return NomiSelect<dynamic>(
          etiqueta,
          [
            if (!_obligatorio(c)) (null, 'Ninguno'),
            for (final o in opciones) (o.valor, o.texto),
          ],
          value: _valores[c.clave],
          icon: c.icono,
          hint: _cargandoOpciones ? 'Cargando...' : null,
          errorText: error,
          validator: (v) => _obligatorio(c) && v == null ? 'Selecciona una opción.' : null,
          onChanged: bloqueado ? null : (v) => setState(() => _valores[c.clave] = v),
        );
      case TipoCampo.fecha:
      case TipoCampo.hora:
        final esFecha = c.tipo == TipoCampo.fecha;
        final valor = '${_valores[c.clave] ?? ''}';
        return NomiField(
          etiqueta,
          key: ValueKey('${c.clave}-$valor'),
          icon: c.icono ?? (esFecha ? Icons.calendar_month_outlined : Icons.schedule),
          initial: esFecha ? fecha(valor) : valor,
          readOnly: true,
          enabled: !bloqueado,
          suffix: Icons.arrow_drop_down,
          helper: c.ayuda,
          errorText: error,
          validator: (_) => _obligatorio(c) && valor.isEmpty ? 'Campo obligatorio.' : null,
          onTap: bloqueado ? null : () => esFecha ? _elegirFecha(c) : _elegirHora(c),
        );
      case TipoCampo.booleano:
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: NomiColors.stroke),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            value: _valores[c.clave] == true,
            onChanged: bloqueado ? null : (v) => setState(() => _valores[c.clave] = v),
            title: Text(etiqueta, style: const TextStyle(fontSize: 15)),
            subtitle: c.ayuda == null
                ? null
                : Text(c.ayuda!, style: const TextStyle(fontSize: 12, color: NomiColors.text3)),
            secondary: c.icono == null ? null : Icon(c.icono, size: 20, color: NomiColors.text3),
            activeThumbColor: NomiColors.emerald,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      case TipoCampo.diasSemana:
        return _DiasSemana(
          etiqueta: etiqueta,
          valor: '${_valores[c.clave] ?? ''}',
          error: error,
          onChanged: (v) => setState(() => _valores[c.clave] = v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inicial = widget.inicial;
    final inactivo = inicial != null && inicial['activo'] == false;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (inactivo)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NomiCard(
                  color: NomiColors.redBg,
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: NomiColors.red, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Este registro está inactivo.')),
                    if (widget.reactivar != null)
                      TextButton(
                        onPressed: () => _accion(widget.reactivar!, 'Registro reactivado.'),
                        child: const Text('Reactivar'),
                      ),
                  ]),
                ),
              ),
            NomiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spaced([for (final c in widget.campos) if (_visible(c)) _campo(c)]),
              ),
            ),
            if (widget.extra != null && inicial != null) widget.extra!(context, inicial),
            const SizedBox(height: 16),
            NomiButton(widget.textoGuardar,
                color: NomiColors.darkGreen,
                height: 52,
                icon: Icons.save_outlined,
                loading: _guardando,
                onPressed: _guardar),
            if (widget.eliminar != null && !inactivo) ...[
              const SizedBox(height: 10),
              NomiButton(widget.textoEliminar,
                  color: NomiColors.red, outlined: true, icon: Icons.delete_outline, onPressed: _eliminar),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Selector de días laborales (1 = lunes ... 7 = domingo) guardado como "1,2,3,4,5".
class _DiasSemana extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String? error;
  final ValueChanged<String> onChanged;

  const _DiasSemana({required this.etiqueta, required this.valor, required this.onChanged, this.error});

  static const _dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final seleccion = valor.split(',').where((d) => d.isNotEmpty).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(color: NomiColors.text3, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (int i = 0; i < 7; i++)
              FilterChip(
                label: Text(_dias[i]),
                showCheckmark: false,
                selected: seleccion.contains('${i + 1}'),
                selectedColor: NomiColors.blueBg,
                side: const BorderSide(color: NomiColors.stroke),
                onSelected: (s) {
                  final nueva = {...seleccion};
                  s ? nueva.add('${i + 1}') : nueva.remove('${i + 1}');
                  onChanged((nueva.toList()..sort()).join(','));
                },
              ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error!, style: const TextStyle(color: NomiColors.red, fontSize: 12)),
          ),
      ],
    );
  }
}
