/// Pantalla completa (la letra): en la PC, la ventana; en el teléfono, sin las barras del sistema.
/// Detrás de una interfaz: cada plataforma lo hace a su manera (`data/screen_mode_impl.dart`).
abstract class ScreenMode {
  Future<void> setFullScreen(bool on);
}
