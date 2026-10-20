import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kiji_player/l10n/l10n.dart';

/// Pregunta dónde guardar un archivo de texto (UTF-8) y avisa cómo salió.
/// Lo usan Exportar playlists (Importar y el ⋯ de la playlist).
Future<void> saveTextFile(
  BuildContext context,
  String fileName,
  String content, {
  String? dialogTitle,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final uri = await FilePicker.saveFile(
      dialogTitle: dialogTitle ?? tx.guardarPlaylist,
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    if (uri != null) messenger.showSnackBar(SnackBar(content: Text(tx.seGuardo(fileName))));
  } catch (error) {
    debugPrint('=== EXPORTAR: no se pudo guardar $fileName: $error ===');
    messenger.showSnackBar(SnackBar(content: Text(tx.noSePudoGuardarElArchivo)));
  }
}
