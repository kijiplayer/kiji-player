import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/kiji_tokens.dart';

/// Superficie de "vidrio" (§7): translúcida, con blur del fondo y un borde
/// de 1 px que brilla apenas.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = KijiRadii.card,
    this.padding,
    this.blur = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  /// El blur es caro en listas largas: se puede apagar y queda solo el vidrio.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: KijiColors.glassFill,
        borderRadius: borderRadius,
        border: Border.all(color: KijiColors.glassBorder),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: KijiSizes.glassBlur, sigmaY: KijiSizes.glassBlur),
              child: body,
            )
          : body,
    );
  }
}

/// Caja con borde degradado violeta → cian de [width] px.
class GradientBorder extends StatelessWidget {
  const GradientBorder({
    super.key,
    required this.child,
    this.radius = KijiRadii.card,
    this.width = 1,
    this.fill = KijiColors.background,
  });

  final Widget child;
  final double radius;
  final double width;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: KijiColors.accentGradientDiagonal,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: EdgeInsets.all(width),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius - width),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - width),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Botón redondo de vidrio (cerrar, ⋯, Letra, Cola...).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.label,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  /// Si tiene texto, es una píldora (ícono + texto) en vez de un círculo.
  final String? label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? KijiColors.muted.withValues(alpha: 0.4)
        : (active ? KijiColors.cyan : Colors.white);
    final content = label == null
        ? SizedBox.square(dimension: size, child: Icon(icon, color: color, size: size * 0.5))
        : SizedBox(
            height: size,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(label!, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );

    // Nombre explícito para lectores de pantalla (el Tooltip solo no alcanza).
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label ?? tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Glass(
          radius: KijiRadii.pill,
          blur: false,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onPressed, customBorder: const StadiumBorder(), child: content),
          ),
        ),
      ),
    );
  }
}

/// Texto pintado con el degradado de acento (logo "Kiji").
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => KijiColors.accentGradient.createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
