import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/kiji_tokens.dart';

/// Elegir una imagen (galería o archivo) y recortarla cuadrada (Tarea Z3).
/// Devuelve los bytes recortados, o null si el usuario cancela.
Future<Uint8List?> pickAndCropImage(BuildContext context) async {
  final picked = await FilePicker.pickFiles(type: FileType.image, dialogTitle: 'Elige una foto');
  if (picked.isEmpty || !context.mounted) return null;
  final Uint8List bytes;
  try {
    bytes = await picked.first.readAsBytes();
  } catch (error) {
    debugPrint('=== PERSONALIZAR: no se pudo leer la imagen: $error ===');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir esa imagen.')));
    }
    return null;
  }
  if (!context.mounted) return null;
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(builder: (_) => CropScreen(image: bytes), fullscreenDialog: true),
  );
}

/// Pantalla de recorte cuadrado.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.image});

  final Uint8List image;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _controller = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recortar'),
        actions: [
          TextButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.crop();
                  },
            child: const Text('Listo'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Crop(
          image: widget.image,
          controller: _controller,
          aspectRatio: 1,
          interactive: true,
          baseColor: KijiColors.background,
          maskColor: Colors.black.withValues(alpha: 0.6),
          progressIndicator: const CircularProgressIndicator(),
          onCropped: (result) {
            switch (result) {
              case CropSuccess(:final croppedImage):
                Navigator.of(context).pop(croppedImage);
              case CropFailure(:final cause):
                debugPrint('=== PERSONALIZAR: no se pudo recortar: $cause ===');
                setState(() => _cropping = false);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('No se pudo recortar esa imagen.')));
            }
          },
        ),
      ),
    );
  }
}
