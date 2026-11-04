import '../domain/habitant.dart';

/// Frontera de persistencia. El motor no conoce el sistema de archivos.
abstract interface class HabitatRepository {
  Future<Habitant?> load();
  Future<void> save(Habitant state);
}
