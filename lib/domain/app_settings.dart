/// Opens this app's system settings page so permissions can be changed
abstract interface class AppSettings {
  /// False when the platform refused to open the page
  Future<bool> open();
}
