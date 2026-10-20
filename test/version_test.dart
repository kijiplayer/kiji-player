import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/updates/update_checker.dart';
import 'package:kiji_player/version_label.dart';

void main() {
  test('pubspec.yaml y lib/version.dart dicen lo mismo (los escribe tool/version.dart)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final line = RegExp(r'^version: (\S+)\+(\d+)$', multiLine: true).firstMatch(pubspec)!;
    expect(line.group(1), kijiVersion);
    expect(int.parse(line.group(2)!), kijiBuild);
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(kijiBuildDate), isTrue);
  });

  test('Comparar versiones: las beta van en orden y la estable gana', () {
    expect(compareVersions('0.5.0-beta.2', '0.5.0-beta.1'), greaterThan(0));
    expect(compareVersions('0.5.0-beta.10', '0.5.0-beta.9'), greaterThan(0));
    expect(compareVersions('0.5.0', '0.5.0-beta.3'), greaterThan(0));
    expect(compareVersions('0.6.0-beta.1', '0.5.0'), greaterThan(0));
    expect(compareVersions('v0.5.0-beta.1', '0.5.0-beta.1+2'), 0);
  });

  test('Sin --flavor dev se muestra como Kiji estable', () {
    expect(kijiVersionLabel, kijiVersion);
    expect(kijiChannel, 'Estable');
    expect(kijiBuildDateLabel, matches(RegExp(r'^\d{2}/\d{2}/\d{4}$')));
  });
}
