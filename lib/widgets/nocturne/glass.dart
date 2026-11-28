
import 'package:flutter/material.dart';

import '../../theme/kiji_tokens.dart';
import 'liquid_glass.dart';
import 'micro_motion.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'liquid_glass_pro.dart';

/// Superficie de "vidrio líquido" (0.8.3, ver [LiquidGlass]): deja ver el fondo ya desenfocado,
/// con un borde de luz fino, un reflejo que se corre al deslizar y profundidad, sin desenfocar
/// nada en cada cuadro (Grafito: vidrio ahumado; Papel: superficie sólida de papel).
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = KijiRadii.card,
    this.padding,
    this.blur = true,
    this.onDark = false,
    this.floating = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  /// Desde la 0.8.3 ningún vidrio desenfoca en vivo; se mantiene por compatibilidad (false: una
  /// tarjeta de lista, igual que las demás).
  final bool blur;

  /// Sobre una pantalla que es siempre oscura (la letra): el vidrio de Nocturne, aunque el estilo
  /// sea claro (en Papel el vidrio es claro y opaco, y el ícono blanco no se vería).
  final bool onDark;

  /// Encima de contenido que se mueve (barra de pestañas, mini-reproductor, barras de abajo): con
  /// una base más opaca, para que lo de abajo nunca se cruce con lo de arriba.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    // Material propio: los ListTile y botones de adentro pintan aquí su efecto al tocar
    // (si no, lo pintan detrás del vidrio y no se ve).
    final body = ClipRRect(
      borderRadius: borderRadius,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
    if (onDark && KijiColors.palette.isLight) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: KijiPalette.nocturne.glassFill,
          borderRadius: borderRadius,
          border: Border.all(color: KijiPalette.nocturne.glassBorder),
        ),
        child: body,
      );
    }
    return LiquidGlass(
      borderRadius: borderRadius,
      kind: floating ? GlassKind.floating : GlassKind.card,
      child: body,
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
    // «Liquid Glass real» (0.9): los redondos, con el botón del paquete tal como viene.
    if (label != null || foreground != null) return _classic(context);
    return ValueListenableBuilder<bool>(
      valueListenable: LiquidGlassPro.active,
      builder: (context, pro, _) => !pro
          ? _classic(context)
          : Tooltip(
              message: tooltip,
              child: lgw.GlassIconButton(
                icon: Icon(icon, color: active ? KijiColors.cyan : null),
                onPressed: onPressed,
                size: size,
                semanticLabel: tooltip,
              ),
            ),
    );
  }

  Widget _classic(BuildContext context) {
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
                      // Grafito: etiquetas chicas y en gris.
                      style: KijiLook.museum
                          ? TextStyle(color: active ? color : KijiColors.muted, fontSize: 13, fontWeight: FontWeight.w500)
                          : TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );

    // Nombre explícito para lectores de pantalla (el Tooltip solo no alcanza).
    return Semantics(
      // Su propio nodo: si no, el nombre y la acción se funden con lo de alrededor (en Inicio, el
      // engranaje quedaba dentro del saludo y TalkBack no lo podía tocar aparte).
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label ?? tooltip,
      // La acción va acá: con excludeSemantics, la del InkWell no llega y TalkBack no podría tocarlo.
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: PressScale(
          enabled: onPressed != null,
          pressed: 0.94,
          child: KijiLook.museum
              ? Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onPressed, customBorder: const StadiumBorder(), child: content),
                )
              : Glass(
            radius: KijiRadii.pill,
            onDark: foreground != null,
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
