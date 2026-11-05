/// "3:07"; con una hora o más, "1:00:44" (antes se perdían las horas: 1:00:44 se veía "0:44").
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
  return '${duration.inMinutes}:$seconds';
}
