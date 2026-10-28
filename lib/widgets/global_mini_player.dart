import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/playback_provider.dart';
import '../theme/kiji_tokens.dart';
import 'mini_player.dart';

/// Navigator de toda la app: el mini-reproductor global vive afuera de él y
/// lo usa para abrir el reproductor y las hojas.
final kijiNavigatorKey = GlobalKey<NavigatorState>();

/// Nombres de las rutas que no muestran el mini-reproductor global (ya tienen
/// el suyo o son el reproductor mismo).
abstract final class KijiRoutes {
  static const player = 'player';
  static const lyrics = 'lyrics';
  static const share = 'share';
  static const welcome = 'welcome';
  static const style = 'style';
  static const whatsNew = 'whats-new';
  static const hideMiniPlayer = {'/', player, lyrics, share, welcome, style, whatsNew};
}

/// Lo que importa de la pila de pantallas para el mini-reproductor.
@immutable
class RouteStackInfo {
  const RouteStackInfo({this.topPageName, this.popupOpen = false});

  /// Nombre de la pantalla de arriba de todo ('/' es Inicio).
  final String? topPageName;

  /// Hay una hoja, un diálogo o un menú abierto.
  final bool popupOpen;
}

/// Sigue la pila del Navigator.
class MiniPlayerRouteObserver extends NavigatorObserver {
  final info = ValueNotifier(const RouteStackInfo(topPageName: '/'));
  final _stack = <Route<dynamic>>[];

  void _update() {
    final top = _stack.isEmpty ? null : _stack.last;
    String? page = '/';
    for (final route in _stack.reversed) {
      if (route is PageRoute) {
        page = route.settings.name;
        break;
      }
    }
    // El Navigator avisa en medio de un build (también en el primero, el de runApp, que pasa
    // fuera de un cuadro): se aplica después, siempre el último estado. Cambiarlo en el acto
    // era el "setState() during build" que mostró el aviso de errores.
    final pending = _pending == null;
    _pending = RouteStackInfo(topPageName: page, popupOpen: top is PopupRoute);
    if (!pending) return;
    void apply() {
      final next = _pending;
      _pending = null;
      if (next != null) info.value = next;
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      scheduleMicrotask(apply);
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    }
  }

  RouteStackInfo? _pending;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      _stack[i] = newRoute;
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _update();
  }
}

/// Si el mini-reproductor global se ve: hay canción, la pantalla
/// de arriba no tiene el suyo, y no hay hoja, diálogo ni teclado abiertos.
bool showGlobalMiniPlayer({required bool hasTrack, required RouteStackInfo routes, required bool keyboardOpen}) =>
    hasTrack && !routes.popupOpen && !keyboardOpen && !KijiRoutes.hideMiniPlayer.contains(routes.topPageName);

/// Alto que ocupa el mini-reproductor global (sin contar el borde seguro).
const globalMiniPlayerSpace = miniPlayerHeight + 12 + 8;

/// Pone el mini-reproductor en todas las pantallas y corre el contenido hacia
/// arriba para que nunca quede tapado.
class GlobalMiniPlayer extends ConsumerWidget {
  const GlobalMiniPlayer({super.key, required this.observer, required this.child});

  final MiniPlayerRouteObserver observer;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(playbackProvider.select((p) => p.track != null));
    final media = MediaQuery.of(context);
    return ValueListenableBuilder<RouteStackInfo>(
      valueListenable: observer.info,
      builder: (context, routes, _) {
        final show = showGlobalMiniPlayer(
          hasTrack: hasTrack,
          routes: routes,
          keyboardOpen: media.viewInsets.bottom > 0,
        );
        final space = show ? globalMiniPlayerSpace + media.padding.bottom : 0.0;
        return ColoredBox(
          color: KijiColors.background,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(bottom: space),
                  child: MediaQuery(
                    data: show ? media.copyWith(padding: media.padding.copyWith(bottom: 0)) : media,
                    child: child,
                  ),
                ),
              ),
              if (show)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12 + media.padding.bottom,
                  height: miniPlayerHeight,
                  // Overlay propio: los botones del mini-reproductor tienen tooltips.
                  child: Overlay(
                    initialEntries: [
                      OverlayEntry(
                        builder: (_) => const Align(
                          alignment: Alignment.bottomCenter,
                          child: MiniPlayer(useAppNavigator: true),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
