/// Hora del día en 12 o 24 horas, según Configuración → Apariencia → Formato de hora.
///
/// Se guarda acá (igual que el idioma de [tx]) para poder escribir la hora sin un
/// `BuildContext`; `KijiApp` lo actualiza cada vez que cambia el ajuste o el del sistema.
bool kijiUse24Hour = true;

/// "08:05" / "21:10" en 24 horas; "8:05 AM" / "9:10 PM" en 12 horas.
String formatClock(DateTime time, {bool? use24Hour}) {
  final minutes = time.minute.toString().padLeft(2, '0');
  if (use24Hour ?? kijiUse24Hour) return '${time.hour.toString().padLeft(2, '0')}:$minutes';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour:$minutes ${time.hour < 12 ? 'AM' : 'PM'}'; // l10n-ignore
}
