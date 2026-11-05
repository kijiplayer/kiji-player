import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/utils/duration_formatter.dart';

void main() {
  test('Duraciones: minutos y, con una hora o más, horas', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    expect(formatDuration(const Duration(hours: 1, seconds: 44)), '1:00:44');
    expect(formatDuration(const Duration(hours: 2, minutes: 5, seconds: 3)), '2:05:03');
  });
}
