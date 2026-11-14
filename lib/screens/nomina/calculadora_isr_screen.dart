import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/json.dart';
import '../../services/nomina_service.dart';
import '../../theme/nomi_theme.dart';
import '../../widgets/feedback.dart';
import '../../widgets/nomi_widgets.dart';

/// Cálculo rápido de ISR, subsidio e IMSS para un sueldo bruto (RDF0702, RDF0703).
class CalculadoraIsrScreen extends StatefulWidget {
  const CalculadoraIsrScreen({super.key});

  @override
  State<CalculadoraIsrScreen> createState() => _CalculadoraIsrScreenState();
}

class _CalculadoraIsrScreenState extends State<CalculadoraIsrScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bruto = TextEditingController();
  String _tipoPeriodo = 'quincenal';
  Json? _resultado;
  bool _calculando = false;

  @override
  void dispose() {
    _bruto.dispose();
    super.dispose();
  }

  Future<void> _calcular() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _calculando = true);
    final r = await ejecutar(context, () => NominaService.simular(num.parse(_bruto.text.replaceAll(',', '')), _tipoPeriodo));
    if (!mounted) return;
    setState(() {
      _calculando = false;
      _resultado = r ?? _resultado;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultado;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NomiCard(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                ...spaced([
                  NomiSelect<String>(
                    'Periodo de pago',
                    const [
                      ('semanal', 'Semanal'),
                      ('catorcenal', 'Catorcenal'),
                      ('quincenal', 'Quincenal'),
                      ('mensual', 'Mensual'),
                    ],
                    value: _tipoPeriodo,
                    icon: Icons.date_range_outlined,
                    onChanged: (v) => setState(() => _tipoPeriodo = v ?? _tipoPeriodo),
                  ),
                  NomiField(
                    'Sueldo bruto del periodo (\$)',
                    icon: Icons.attach_money,
                    controller: _bruto,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = num.tryParse((v ?? '').replaceAll(',', ''));
                      return n == null || n <= 0 ? 'Debe ser numérico y mayor a cero.' : null;
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: NomiButton('Calcular ISR',
                      color: NomiColors.blue, height: 52, loading: _calculando, onPressed: _calcular),
                ),
              ],
            ),
          ),
        ),
        if (r != null) ...[
