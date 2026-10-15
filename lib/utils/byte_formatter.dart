/// Tamaño legible en español: "850 KB", "4,2 MB", "1,5 GB".
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit <= 1 || value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1).replaceAll('.', ',');
  return '$text ${units[unit]}';
}
