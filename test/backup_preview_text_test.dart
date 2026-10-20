import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/backup/domain/backup_manifest.dart';
import 'package:kiji_player/features/backup/presentation/backup_screen.dart';
import 'package:kiji_player/l10n/l10n.dart';

BackupManifest _manifest(DateTime createdAt) => BackupManifest(
      createdAt: createdAt,
      platform: 'android',
      files: const [],
      counts: const BackupCounts(playlists: 1, likes: 1, history: 3, downloads: 2),
    );

void main() {
  tearDown(() => setKijiLocale(const Locale('es')));

  test('Restaurar en inglés: sin "de"/"del" ni palabras en español', () {
    setKijiLocale(const Locale('en'));
    final today = restorePreviewText(_manifest(DateTime.now()));
    expect(today, startsWith('Backup from today '));
    expect(today, contains('1 playlist\n'));
    expect(today, contains('1 like\n'));
    expect(today, contains('3 songs in your history'));
    expect(today, isNot(contains('canciones')));
    expect(restorePreviewText(_manifest(DateTime(2026, 10, 1, 9))), startsWith('Backup from 01/10/2026 09:00'));
  });

  test('Restaurar en español: "de hoy" y "del 01/10/2026"', () {
    setKijiLocale(const Locale('es'));
    expect(restorePreviewText(_manifest(DateTime.now())), startsWith('Copia de hoy '));
    expect(restorePreviewText(_manifest(DateTime(2026, 10, 1, 9))), startsWith('Copia del 01/10/2026 09:00'));
    expect(restorePreviewText(_manifest(DateTime.now())), contains('3 canciones en el historial'));
  });
}
