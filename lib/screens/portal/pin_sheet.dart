import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/nomi_theme.dart';
import '../../widgets/nomi_widgets.dart';

/// Hoja inferior con PIN de seguridad de 4 dígitos (enmascarado).
/// Devuelve el PIN capturado o null si se cierra.
class PinSheet extends StatefulWidget {
  final String titulo;
  final String descripcion;
  final String boton;
  const PinSheet({
    super.key,
    this.titulo = 'PIN de Seguridad',
    this.descripcion = 'Ingresa tu PIN de 4 dígitos para firmar el recibo.',
    this.boton = 'Confirmar y Firmar',
  });

  static Future<String?> mostrar(BuildContext context,
          {String titulo = 'PIN de Seguridad',
          String descripcion = 'Ingresa tu PIN de 4 dígitos para firmar el recibo.',
          String boton = 'Confirmar y Firmar'}) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => PinSheet(titulo: titulo, descripcion: descripcion, boton: boton),
      );

  @override
  State<PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<PinSheet> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focos = List.generate(4, (_) => FocusNode());
  String? _error;

  String get _pin => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focos) {
      f.dispose();
    }
    super.dispose();
  }

  void _confirmar() {
    if (_pin.length != 4) {
      setState(() => _error = 'Captura los 4 dígitos.');
      return;
    }
    Navigator.pop(context, _pin);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(widget.descripcion, style: const TextStyle(fontSize: 12.5, color: NomiColors.text3)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                _PinBox(
                  controller: _controllers[i],
                  focusNode: _focos[i],
                  autofocus: i == 0,
                  onChanged: (v) {
                    setState(() => _error = null);
                    if (v.isNotEmpty && i < 3) _focos[i + 1].requestFocus();
                    if (v.isEmpty && i > 0) _focos[i - 1].requestFocus();
                    if (v.isNotEmpty && i == 3) FocusScope.of(context).unfocus();
                  },
                ),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Center(child: Text(_error!, style: const TextStyle(color: NomiColors.red, fontSize: 12.5))),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: NomiButton(widget.boton, color: NomiColors.emerald, height: 56, onPressed: _confirmar),
          ),
        ],
      ),
    );
  }
}

class _PinBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final ValueChanged<String> onChanged;

  const _PinBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 62,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textAlign: TextAlign.center,
        obscureText: true,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        onChanged: onChanged,
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: NomiColors.bg,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: NomiColors.blue, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: NomiColors.emerald, width: 2),
          ),
        ),
      ),
    );
  }
}
