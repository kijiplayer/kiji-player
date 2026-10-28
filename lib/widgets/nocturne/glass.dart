import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/kiji_tokens.dart';
import 'micro_motion.dart';

/// Superficie de "vidrio": translúcida, con blur del fondo y un borde
/// de 1 px que brilla apenas (Grafito: vidrio esmerilado; Papel: superficie sólida).
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = KijiRadii.card, this.padding, this.blur = true});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  /// El blur es caro en listas largas: se puede apagar y queda solo el vidrio.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    // Papel: superficie sólida. Grafito: vidrio esmerilado; con desenfoque va sobre cualquier
    // contenido (mini-reproductor, barra de navegación), así que lleva el ahumado para que se lea.
    final frosted = blur && KijiLook.style != KijiStyle.paper;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: frosted && KijiLook.museum ? KijiMuseum.pane : KijiColors.glassFill,
        borderRadius: borderRadius,
        border: Border.all(color: KijiColors.glassBorder),
      ),
      // Material propio: los ListTile y botones de adentro pintan aquí su efecto al tocar
      // (si no, lo pintan detrás del vidrio y no se ve).
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: frosted
          // Agrupado (rendimiento): todos los vidrios de la pantalla comparten una sola pasada
          // de desenfoque del fondo (BackdropGroup en app.dart).
          ? BackdropFilter.grouped(
              filter: ImageFilter.blur(sigmaX: KijiSizes.glassBlur, sigmaY: KijiSizes.glassBlur),
              child: body,
            )
          : body,
    );
  }
}

/// Caja con borde degradado violeta → cian de [width] px.
class GradientBorder extends StatelessWidget {
  const GradientBorder({super.key, required this.child, this.radius = KijiRadii.card, this.width = 1, this._fill});

  final Widget child;
  final double radius;
  final double width;
  final Color? _fill;

  /// Relleno de adentro; de fábrica, el fondo de la paleta activa.
  Color get fill => _fill ?? KijiColors.background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Grafito y Papel: sin degradado, una línea lisa.
        gradient: KijiLook.nocturne ? KijiColors.accentGradientDiagonal : null,
        color: KijiLook.nocturne ? null : KijiColors.glassBorder,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: EdgeInsets.all(width),
        child: DecoratedBox(
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(radius - width)),
          child: ClipRRect(borderRadius: BorderRadius.circular(radius - width), child: child),
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
    this.foreground,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  /// Si tiene texto, es una píldora (ícono + texto) en vez de un círculo.
  final String? label;
  final bool active;

  /// Color del ícono en pantallas que son siempre oscuras (la letra), sea cual sea el tema.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? KijiColors.muted.withValues(alpha: 0.4)
        : (active ? KijiColors.cyan : foreground ?? KijiColors.text);
    final content = label == null
        ? SizedBox.square(
            dimension: size,
            child: PopSwitcher(
              child: Icon(icon, key: ValueKey(icon), color: color, size: size * 0.5),
            ),
          )
        : SizedBox(
            height: size,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopSwitcher(
                    child: Icon(icon, key: ValueKey(icon), color: color, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
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
        child: PressScale(
          enabled: onPressed != null,
          pressed: 0.94,
          child: Glass(
            radius: KijiRadii.pill,
            // Sin desenfoque del fondo: sobre la aurora animada se recalculaba en cada cuadro
            // (en la PC bajaba a ~40 fps). El desenfoque real está en la aurora misma.
            blur: false,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onPressed, customBorder: const StadiumBorder(), child: content),
            ),
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
