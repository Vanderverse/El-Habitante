import 'dart:convert';
import 'dart:io';

import '../domain/habitant.dart';
import 'habitat_repository.dart';

/// JSON versionado en el directorio privado de la aplicación.
/// La sustitución es atómica en Android/iOS: un cierre no deja un JSON a medias.
class FileHabitatRepository implements HabitatRepository {
  FileHabitatRepository(Directory directory)
    : file = File('${directory.path}/habitant_v1.json');

  final File file;

  @override
  Future<Habitant?> load() async {
    if (!await file.exists()) return null;
    // Un guardado ilegible genera un error visible; nunca se reinicia en silencio.
    return Habitant.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> save(Habitant state) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(state.toJson()), flush: true);
    await temporary.rename(file.path);
  }
}
