import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/downloads/presentation/downloads_screen.dart';
import '../../features/local_library/presentation/local_library_screen.dart';
import '../../features/yt_music/presentation/search_screen.dart';
import '../../providers/playback_provider.dart';
import '../../widgets/mini_player.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  static const _destinations = [
    _NavDestination(label: 'Inicio', icon: Icons.home_outlined, selectedIcon: Icons.home),
    _NavDestination(label: 'Buscar', icon: Icons.search_outlined, selectedIcon: Icons.search),
    _NavDestination(
      label: 'Biblioteca',
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final track = playback.track;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiji'),
      ),
      body: switch (_currentIndex) {
        1 => const SearchScreen(),
        2 => const LocalLibraryScreen(),
        _ => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _emptyMessage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  track == null
                      ? 'Elige una canción'
                      : '${playback.statusLabel}: ${track.title}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
      },
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              for (final destination in _destinations)
                BottomNavigationBarItem(
                  icon: Icon(destination.icon),
                  activeIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String get _emptyMessage {
    return switch (_currentIndex) {
      0 => 'No hay contenido',
      1 => 'Busca música, videos o podcasts',
      _ => 'Tu biblioteca está vacía',
    };
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
