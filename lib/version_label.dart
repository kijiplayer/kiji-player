import 'features/dev_tools/dev_build.dart';
import 'version.dart';

import 'package:kiji_player/l10n/l10n.dart';

export 'version.dart';

/// La versión como se muestra: Kiji "0.5.0-beta.1"; Kiji Dev "0.5.0-beta.1-dev.2".
String get kijiVersionLabel => isDevBuild ? '$kijiVersion-dev.$kijiBuild' : kijiVersion;

/// Canal: Dev (versión de pruebas) o Estable (lo que ya se probó en Dev, sin cambios).
String get kijiChannel => isDevBuild ? 'Dev' : tx.estable; // l10n-ignore

/// "19/10/2026".
String get kijiBuildDateLabel {
  final parts = kijiBuildDate.split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : kijiBuildDate;
}
