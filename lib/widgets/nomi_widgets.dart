import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/nomi_theme.dart';

/// Separa una lista de widgets con un espacio vertical.
List<Widget> spaced(List<Widget> items, [double gap = 14]) => [
      for (int i = 0; i < items.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        items[i],
      ],
    ];

/// Tarjeta oscura redondeada.
class NomiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const NomiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = NomiColors.card,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Se pinta sobre un Material para que los ListTile y efectos de toque internos se vean
    final radius = BorderRadius.circular(16);
    Widget content = SizedBox(width: double.infinity, child: Padding(padding: padding, child: child));
    if (onTap != null) content = InkWell(borderRadius: radius, onTap: onTap, child: content);
    if (gradient != null) {
      content = Ink(decoration: BoxDecoration(gradient: gradient, borderRadius: radius), child: content);
    }
    return Material(
      color: gradient == null ? color : Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

/// Título de sección en mayúsculas.
class SectionLabel extends StatelessWidget {
  final String text;
  final double top;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.top = 20, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 8, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: NomiColors.text3,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Campo de texto con borde redondeado. Los campos de contraseña incluyen el
/// botón para mostrar u ocultar el texto.
class NomiField extends StatefulWidget {
  final String label;
  final IconData? icon;
  final IconData? suffix;
  final bool obscure;
  final bool readOnly;
  final bool enabled;
  final String? initial;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboard;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String? hint;
  final String? helper;
  final String? errorText;
  final List<TextInputFormatter>? formatters;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;

  const NomiField(
    this.label, {
    super.key,
    this.icon,
    this.suffix,
    this.obscure = false,
    this.readOnly = false,
    this.enabled = true,
    this.initial,
    this.maxLines = 1,
    this.maxLength,
    this.keyboard,
    this.controller,
    this.validator,
    this.onChanged,
    this.onTap,
    this.hint,
    this.helper,
    this.errorText,
    this.formatters,
    this.action,
    this.onSubmitted,
  });

  @override
  State<NomiField> createState() => _NomiFieldState();
}

class _NomiFieldState extends State<NomiField> {
  late bool _oculto = widget.obscure;

  @override
  Widget build(BuildContext context) {
    Widget? sufijo;
    if (widget.obscure) {
      sufijo = IconButton(
        tooltip: _oculto ? 'Mostrar' : 'Ocultar',
        icon: Icon(_oculto ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
        onPressed: () => setState(() => _oculto = !_oculto),
      );
    } else if (widget.suffix != null) {
      sufijo = Icon(widget.suffix, size: 20);
    }
    return TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initial : null,
      obscureText: _oculto,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboard,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      inputFormatters: widget.formatters,
      textInputAction: widget.action,
      onFieldSubmitted: widget.onSubmitted,
      style: TextStyle(color: widget.enabled ? NomiColors.text1 : NomiColors.text3, fontSize: 15),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        helperMaxLines: 2,
        errorText: widget.errorText,
        errorMaxLines: 3,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20),
        suffixIcon: sufijo,
      ),
    );
  }
}

/// Lista desplegable controlada (el valor lo guarda la pantalla).
class NomiSelect<T> extends StatelessWidget {
  final String label;
  final List<(T, String)> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final IconData? icon;
  final String? Function(T?)? validator;
  final String? errorText;
  final String? hint;

  const NomiSelect(
    this.label,
    this.items, {
    super.key,
    this.value,
    this.onChanged,
    this.icon,
    this.validator,
    this.errorText,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final existe = items.any((e) => e.$1 == value);
    return DropdownButtonFormField<T>(
      key: ValueKey('$label-${existe ? value : null}-${items.length}'),
      initialValue: existe ? value : null,
      isExpanded: true,
      dropdownColor: NomiColors.card,
      borderRadius: BorderRadius.circular(12),
      style: const TextStyle(color: NomiColors.text1, fontSize: 15),
      icon: const Icon(Icons.arrow_drop_down, color: NomiColors.text3),
      validator: validator,
      hint: hint == null ? null : Text(hint!, style: const TextStyle(color: NomiColors.text3)),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 3,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
      ),
      items: [
        for (final e in items)
          DropdownMenuItem(value: e.$1, child: Text(e.$2, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}

/// Botón de la app (relleno o con borde).
class NomiButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool outlined;
  final double height;
  final VoidCallback? onPressed;
  final bool loading;

  const NomiButton(
    this.label, {
    super.key,
    this.color = NomiColors.blue,
    this.icon,
    this.outlined = false,
    this.height = 48,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const textStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 14);
    final child = loading
        ? const SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final action = loading ? null : onPressed;
    return SizedBox(
      height: height,
      child: outlined
          ? OutlinedButton(
              onPressed: action,
              style: OutlinedButton.styleFrom(
                foregroundColor: NomiColors.text1,
                side: BorderSide(color: color == NomiColors.blue ? NomiColors.blue : color, width: 1.5),
                shape: shape,
                textStyle: textStyle,
              ),
              child: child,
            )
          : FilledButton(
              onPressed: action,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: color.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white70,
                shape: shape,
                textStyle: textStyle,
              ),
              child: child,
            ),
    );
  }
}

/// Botones en fila con el mismo ancho.
class ButtonRow extends StatelessWidget {
  final List<Widget> children;
  const ButtonRow(this.children, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Insignia de estatus.
class StatusBadge extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  const StatusBadge(this.text, this.fg, this.bg, {super.key});

  factory StatusBadge.activo() =>
      const StatusBadge('Activo', NomiColors.emerald, NomiColors.emeraldBg);
  factory StatusBadge.inactivo() =>
      const StatusBadge('Inactivo', NomiColors.red, NomiColors.redBg);
  factory StatusBadge.pendiente() =>
      const StatusBadge('Pendiente', NomiColors.amber, NomiColors.amberBg);
  factory StatusBadge.aprobado() =>
      const StatusBadge('Aprobado', NomiColors.emerald, NomiColors.emeraldBg);
  factory StatusBadge.rechazado() =>
      const StatusBadge('Rechazado', NomiColors.red, NomiColors.redBg);

  factory StatusBadge.estatus(bool activo) => activo ? StatusBadge.activo() : StatusBadge.inactivo();

  /// Estado de una solicitud: pendiente, aprobado o rechazado.
  factory StatusBadge.solicitud(String estado) => switch (estado) {
        'aprobado' => StatusBadge.aprobado(),
        'rechazado' => StatusBadge.rechazado(),
        _ => StatusBadge.pendiente(),
      };

  /// Estado de un recibo: calculado, publicado (por firmar) o firmado.
  factory StatusBadge.recibo(String estado) => switch (estado) {
        'firmado' => const StatusBadge('Firmado', NomiColors.emerald, NomiColors.emeraldBg),
        'publicado' => const StatusBadge('Por firmar', NomiColors.amber, NomiColors.amberBg),
        _ => const StatusBadge('Calculado', NomiColors.blue, NomiColors.blueBg),
      };

  factory StatusBadge.nomina(String estado) => estado == 'cerrada'
      ? const StatusBadge('Cerrada', NomiColors.text2, Color(0x33CBD5E1))
      : const StatusBadge('Abierta', NomiColors.emerald, NomiColors.emeraldBg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Fila de registro con franja de color a la izquierda.
class RecordTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const RecordTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.accent = NomiColors.blue,
    this.trailing,
    this.leading,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: NomiColors.card, borderRadius: radius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                if (leading != null) Center(child: leading),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: const TextStyle(color: NomiColors.text3, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
                if (trailing != null)
                  Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: trailing)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila etiqueta - valor.
class KvRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const KvRow(this.label, this.value,
      {super.key, this.color = NomiColors.text1, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final w = bold ? FontWeight.w700 : FontWeight.w400;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: NomiColors.text2, fontWeight: w, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Text(value, style: TextStyle(color: color, fontWeight: w, fontSize: 14)),
      ],
    );
  }
}

/// Divisor delgado para tarjetas.
class NomiDivider extends StatelessWidget {
  final double vertical;
  const NomiDivider({super.key, this.vertical = 12});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: vertical),
        child: const Divider(height: 1, color: NomiColors.stroke),
      );
}

/// Indicador compacto (etiqueta + valor) para resúmenes.
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  const KpiTile(this.label, this.value,
      {super.key, this.color = NomiColors.text1, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return NomiCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: NomiColors.text3), const SizedBox(width: 4)],
              Expanded(
                child: Text(label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: NomiColors.text3)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Logo NomiGest dibujado con código.
class NomiLogo extends StatelessWidget {
  final double size;
  const NomiLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 120, 120), const Radius.circular(30)),
      Paint()..color = NomiColors.navy,
    );
    final blue = Paint()..color = NomiColors.blue;
    canvas.drawRect(const Rect.fromLTWH(28, 78, 14, 18), blue);
    canvas.drawRect(const Rect.fromLTWH(53, 64, 14, 32), blue);
    canvas.drawRect(const Rect.fromLTWH(78, 50, 14, 46), Paint()..color = NomiColors.darkGreen);
    final path = Path()
      ..moveTo(26, 46)
      ..lineTo(46, 30)
      ..lineTo(60, 40)
      ..lineTo(94, 18);
    canvas.drawPath(
      path,
      Paint()
        ..color = NomiColors.emerald
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
