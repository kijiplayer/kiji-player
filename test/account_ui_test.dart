import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/account/data/account_store.dart';
import 'package:kiji_player/features/account/data/yt_sync.dart';
import 'package:kiji_player/features/account/domain/yt_session.dart';
import 'package:kiji_player/features/account/presentation/account_screens.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';

class _Account extends AccountNotifier {
  _Account(this.session);
  final YtSession? session;
  @override
  YtSession? build() => session;
}

class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}

class _NoSync extends YtSyncNotifier {
  int syncs = 0;
  @override
  YtSyncState build() => const YtSyncState();
  @override
  Future<bool> syncNow() async {
    syncs++;
    return true;
  }
}

void main() {
  ProviderContainer make({YtSession? session, AppSettings settings = const AppSettings(), _NoSync? sync}) {
    final c = ProviderContainer(overrides: [
      accountProvider.overrideWith(() => _Account(session)),
      settingsProvider.overrideWith(() => _Settings(settings)),
      ytSyncProvider.overrideWith(() => sync ?? _NoSync()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('Biblioteca sin sesión: «Conecta tu YouTube Music», que se cierra y no vuelve', (tester) async {
    final c = make();
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: Scaffold(body: YtConnectCard()))));
    expect(find.text('Conecta tu YouTube Music (opcional)'), findsOneWidget);
    expect(find.byKey(const Key('yt-connect-sign-in')), findsOneWidget);
    await tester.tap(find.byKey(const Key('yt-connect-hide')));
    await tester.pump();
    expect(find.byKey(const Key('yt-connect-card')), findsNothing);
    expect(c.read(settingsProvider).ytConnectCardHidden, isTrue);
    expect(AppSettings.fromJson(c.read(settingsProvider).toJson()).ytConnectCardHidden, isTrue, reason: 'se guarda');
  });

  testWidgets('Con la sesión iniciada la tarjeta no aparece', (tester) async {
    final c = make(session: const YtSession(cookie: 'SAPISID=inventada'));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: Scaffold(body: YtConnectCard()))));
    expect(find.byKey(const Key('yt-connect-card')), findsNothing);
  });

  testWidgets('Al iniciar sesión se pregunta una sola vez por la sincronización («Ahora no» la deja apagada)', (tester) async {
    final sync = _NoSync();
    final c = make(session: const YtSession(cookie: 'SAPISID=inventada'), sync: sync);
    late WidgetRef ref;
    late BuildContext ctx;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Consumer(builder: (context, r, _) {
          ref = r;
          ctx = context;
          return const Scaffold();
        }),
      ),
    ));
    final first = offerSyncOnce(ctx, ref);
    await tester.pumpAndSettle();
    expect(find.text('¿Sincronizar con YouTube Music?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('yt-sync-offer-no')));
    await tester.pumpAndSettle();
    await first;
    expect(c.read(settingsProvider).ytSync, isFalse);
    expect(c.read(settingsProvider).ytSyncOffered, isTrue);
    // La segunda vez, nada.
    final second = offerSyncOnce(ctx, ref);
    await tester.pumpAndSettle();
    expect(find.text('¿Sincronizar con YouTube Music?'), findsNothing);
    await second;
    expect(sync.syncs, 0);
  });

  testWidgets('«Activar» prende la sincronización y lee la cuenta', (tester) async {
    final sync = _NoSync();
    final c = make(session: const YtSession(cookie: 'SAPISID=inventada'), sync: sync);
    late WidgetRef ref;
    late BuildContext ctx;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Consumer(builder: (context, r, _) {
          ref = r;
          ctx = context;
          return const Scaffold();
        }),
      ),
    ));
    final done = offerSyncOnce(ctx, ref);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yt-sync-offer-yes')));
    await tester.pumpAndSettle();
    await done;
    expect(c.read(settingsProvider).ytSync, isTrue);
    expect(sync.syncs, 1);
  });

  testWidgets('Configuración → Cuenta: sin sesión, «Iniciar sesión» y el interruptor deshabilitado; con sesión, «Cerrar sesión» y «Sincronizar ahora»', (tester) async {
    Widget section() => const MaterialApp(
      home: Scaffold(body: Column(children: [AccountStatusTile(), SyncSwitchTile(), SyncNowTile()])),
    );
    var c = make();
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: section()));
    expect(find.byKey(const Key('account-sign-in')), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('settings-yt-sync'))).onChanged, isNull);
    expect(find.byKey(const Key('settings-yt-sync-now')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    c = make(session: const YtSession(cookie: 'SAPISID=inventada'), settings: const AppSettings(ytSync: true));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: section()));
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
    expect(find.text('Sincronizar ahora'), findsOneWidget);
    expect(find.text('Todavía no se sincronizó.'), findsOneWidget);
  });
}
