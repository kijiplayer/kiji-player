import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/downloads/presentation/downloads_screen.dart';
import '../../features/local_library/presentation/local_library_screen.dart';
import '../../features/updates/update_checker.dart';
import '../../features/updates/updates_screen.dart';
import '../../features/yt_music/presentation/search_screen.dart';
import '../../providers/playback_provider.dart';
import '../../providers/shell_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/mini_player.dart';
import '../shell/desktop_shell.dart';
import '../shell/pill_nav_bar.dart';
import 'inicio_tab.dart';

/// Pantalla principal. Adaptable: en pantallas angostas,
/// píldora flotante abajo con el mini-reproductor encima; desde 1000 px
/// (PC), barra lateral, panel "A continuación" y barra del reproductor.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<PlaybackNotice?>(playbackNoticeProvider, (previous, notice) {
      if (notice == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(notice.message),
        duration: Duration(seconds: notice.action == null ? 4 : 8),
        // Con acción, Flutter lo deja fijo por defecto; un aviso no debería
        // quedarse tapando la pantalla.
        persist: false,
        action: switch (notice.action) {
          NoticeAction.openDownloads => SnackBarAction(
              label: 'Ver descargadas',
              onPressed: () => DownloadsScreen.open(context),
            ),
          null => null,
        },
      ));
      ref.read(playbackNoticeProvider.notifier).state = null;
    });

    // Versión nueva encontrada al abrir Kiji: un aviso con "Ver" (Tarea W1).
    ref.listen<UpdateState>(updateProvider, (previous, next) {
      final latest = next.latest;
      if (latest == null || previous?.latest?.version == latest.version) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hay una versión nueva de Kiji (${latest.version}).'),
        duration: const Duration(seconds: 8),
        persist: false,
        action: SnackBarAction(label: 'Ver', onPressed: () => showReleaseSheet(context, latest)),
      ));
    });

    return CallbackShortcuts(
      bindings: {
        // Ctrl K (o ⌘K): ir al buscador desde cualquier pestaña.
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _focusSearch(ref),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _focusSearch(ref),
      },
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= KijiSizes.desktopBreakpoint
            ? const DesktopShell()
            : const _MobileShell(),
      ),
    );
  }

  static void _focusSearch(WidgetRef ref) {
    ref.read(shellTabProvider.notifier).state = ShellTab.search;
    // Después del cambio de pestaña, cuando el campo ya existe.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(searchFocusProvider).requestFocus());
  }
}

/// Contenido de la pestaña activa (compartido por celular y PC).
class ShellTabContent extends ConsumerWidget {
  const ShellTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(shellTabProvider)) {
      ShellTab.home => const InicioTab(),
      ShellTab.search => const SearchScreen(),
      ShellTab.library => const LocalLibraryScreen(),
    };
  }
}

class _MobileShell extends ConsumerWidget {
  const _MobileShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBody: true,
      body: const SafeArea(bottom: false, child: ShellTabContent()),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              MiniPlayer(),
              SizedBox(height: 10),
              Center(child: PillNavBar()),
            ],
          ),
        ),
      ),
    );
  }
}
