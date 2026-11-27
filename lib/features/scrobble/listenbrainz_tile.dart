import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/kiji_tokens.dart';
import 'scrobble_provider.dart';

import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

/// Configuración → Cuenta → «Scrobbling a ListenBrainz»: conectado (con quién) o sin conectar.
class ListenBrainzTile extends ConsumerWidget {
  const ListenBrainzTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(listenBrainzProvider);
    return ListTile(
      key: const Key('settings-listenbrainz'),
      leading: const Icon(Icons.graphic_eq_rounded),
      title: Text(tx.scrobblingListenBrainz),
      subtitle: Text(user == null ? tx.scrobblingListenBrainzNota : tx.conectadoComo(user)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showKijiSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const _ListenBrainzSheet(),
      ),
    );
  }
}

class _ListenBrainzSheet extends ConsumerStatefulWidget {
  const _ListenBrainzSheet();

  @override
  ConsumerState<_ListenBrainzSheet> createState() => _ListenBrainzSheetState();
}

class _ListenBrainzSheetState extends ConsumerState<_ListenBrainzSheet> {
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(listenBrainzProvider.notifier).connect(_token.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : tx.tokenNoValido;
    });
    if (ok) _token.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(listenBrainzProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tx.scrobblingListenBrainz, style: KijiText.title(size: 20)),
              const SizedBox(height: 6),
              Text(tx.listenBrainzExplicacion, style: TextStyle(color: KijiColors.muted)),
              const SizedBox(height: 14),
              if (user != null) ...[
                Text(tx.conectadoComo(user), style: KijiText.title(size: 15)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('listenbrainz-disconnect'),
                  icon: const Icon(Icons.link_off_rounded),
                  label: Text(tx.desconectar),
                  onPressed: () => ref.read(listenBrainzProvider.notifier).disconnect(),
                ),
              ] else ...[
                TextField(
                  key: const Key('listenbrainz-token'),
                  controller: _token,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(labelText: tx.tuTokenDeListenBrainz, errorText: _error),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(tx.dondeEstaMiToken),
                    onPressed: () => launchUrl(
                      Uri.parse('https://listenbrainz.org/settings/'), // l10n-ignore
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FilledButton(
                  key: const Key('listenbrainz-connect'),
                  onPressed: _busy ? null : _connect,
                  child: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(tx.conectar),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
