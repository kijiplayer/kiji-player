import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/local_library_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../settings/data/settings_store.dart';
import '../data/android_media_store_source.dart';
import '../domain/music_filter.dart';

/// Las carpetas del teléfono con audios (las que pasan las reglas fijas), y si se muestran.
final musicFoldersProvider = FutureProvider<List<MusicFolder>>((ref) async {
  final source = ref.watch(localLibrarySourceProvider);
  ref.watch(settingsProvider.select((s) => (folders: s.excludedFolders, choices: s.musicFolderChoices)));
  if (source is! AndroidMediaStoreSource) return const [];
  try {
    if (!await source.hasAccess()) return const [];
    return await source.musicFolders(exclusions: ref.read(settingsProvider).localExclusions);
  } catch (error) {
    debugPrint('=== BIBLIOTECA: no se pudieron leer las carpetas (${error.runtimeType}) ===');
    return const [];
  }
});

/// Configuración → "Carpetas de música": cada carpeta con audios, cuántos tiene y un interruptor
/// para mostrarla u ocultarla en la Biblioteca. Ocultar no borra nada.
class MusicFoldersScreen extends ConsumerWidget {
  const MusicFoldersScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MusicFoldersScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(musicFoldersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tx.carpetasDeMusica)),
      body: folders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(tx.carpetasDeMusicaVacio)),
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(tx.carpetasDeMusicaNota, style: TextStyle(color: KijiColors.muted, height: 1.4)),
            ),
            if (list.isEmpty)
              Padding(padding: const EdgeInsets.all(16), child: Text(tx.carpetasDeMusicaVacio)),
            for (final folder in list)
              SwitchListTile(
                key: Key('music-folder-${folder.path}'),
                secondary: Icon(folder.shown ? Icons.folder_rounded : Icons.folder_off_outlined),
                title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${tx.nAudios(folder.total)} · ${folder.path}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                value: folder.shown,
                onChanged: (on) => ref.read(settingsProvider.notifier).update(
                  (s) => s.copyWith(musicFolderChoices: {...s.musicFolderChoices, folder.path: on}),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
