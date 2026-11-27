// Sabor «play» (Google Play, base de la 1.0): el lugar del reproductor OFICIAL de YouTube.
// TODAVÍA NO SE USA. Reglas para cuando se haga (decisión de David, Proyecto Play):
//  - el video se ve siempre (nada de audio solo) y nunca suena en segundo plano;
//  - con sus anuncios, sin tocarlos (nada de silenciar ni saltar);
//  - la letra va al lado del video, nunca encima;
//  - hace falta un proyecto de la API de YouTube (lo crea David, no Code) y respetar su cuota.

import 'package:flutter/widgets.dart';

/// Lo que va a necesitar el sabor «play» para reproducir YouTube: un reproductor visible e
/// incrustado. La Kiji completa («full») no lo usa.
abstract class OfficialYoutubePlayer {
  /// El video embebido, visible (la app no lo esconde ni lo achica a un punto).
  Widget build(BuildContext context, String videoId);

  Future<void> play();
  Future<void> pause();

  /// Al ir a segundo plano, el reproductor oficial se pausa (no hay YouTube en segundo plano).
  Future<void> onBackground();
}