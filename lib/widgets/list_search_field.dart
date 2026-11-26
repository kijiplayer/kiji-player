import 'package:flutter/material.dart';

import '../features/settings/domain/setting_search.dart' show normalizeForSearch;
import '../models/track.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// ¿[track] coincide con [query] (ya normalizada con [normalizeForSearch])? Título, artista y álbum,
/// sin tildes ni mayúsculas.
bool trackMatches(Track track, String query) =>
    query.isEmpty || normalizeForSearch('${track.title} ${track.artist} ${track.album ?? ''}').contains(query);

/// Buscador de una lista de canciones (Canciones, Descargadas, un artista…). Llama a [onChanged]
/// con el texto ya normalizado. Lo elegido con la selección múltiple se mantiene al buscar.
class ListSearchField extends StatefulWidget {
  const ListSearchField({super.key, required this.onChanged, this.hint});

  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  State<ListSearchField> createState() => _ListSearchFieldState();
}

class _ListSearchFieldState extends State<ListSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('list-search'),
    controller: _controller,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      isDense: true,
      prefixIcon: const Icon(Icons.search_rounded),
      hintText: widget.hint ?? tx.buscarEnEstaLista,
      suffixIcon: _controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: tx.borrarBusqueda,
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                setState(() {});
                widget.onChanged('');
              },
            ),
    ),
    onChanged: (text) {
      setState(() {});
      widget.onChanged(normalizeForSearch(text.trim()));
    },
  );
}
