import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kiji_player/l10n/l10n.dart';

/// El logo de Kiji ("Opción B · K de onda"), dibujado desde
/// `assets/branding/kiji_logo.svg`, la misma fuente que los íconos.
class KijiLogo extends StatelessWidget {
  const KijiLogo({super.key, this.size = 40});

  static const asset = 'assets/branding/kiji_logo.svg';

  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset(asset, width: size, height: size, semanticsLabel: tx.logoDeKiji);
}
