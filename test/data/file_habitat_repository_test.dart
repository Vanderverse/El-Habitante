import 'dart:io';

import 'package:el_habitante/data/file_habitat_repository.dart';
import 'package:el_habitante/domain/behavior_engine.dart';
import 'package:el_habitante/domain/habitant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late FileHabitatRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('el_habitante_test_');
    repository = FileHabitatRepository(directory);
  });

  tearDown(() async => directory.delete(recursive: true));

  test('primer inicio y guardado que sobrevive a una nueva instancia', () async {
    expect(await repository.load(), isNull);
    final now = DateTime.utc(2026, 1, 1, 12);
    final original = Habitant.discover(now);
    await repository.save(original);
    final changed = const BehaviorEngine().interact(original,
        Interaction.offerObject, now);
    await repository.save(changed);
    final restored = await FileHabitatRepository(directory).load();
    expect(restored!.toJson(), changed.toJson());
    expect(await File('${repository.file.path}.tmp').exists(), isFalse);
  });

  test('un archivo corrupto no se sobrescribe ni se interpreta como primer inicio',
      () async {
    await repository.file.writeAsString('{datos incompletos');
    await expectLater(repository.load(), throwsFormatException);
    expect(await repository.file.readAsString(), '{datos incompletos');
  });

  test('un temporal interrumpido no sustituye el guardado confirmado', () async {
    final state = Habitant.discover(DateTime.utc(2026));
    await repository.save(state);
    await File('${repository.file.path}.tmp').writeAsString('incompleto');
    expect((await repository.load())!.toJson(), state.toJson());
    await repository.save(state);
    expect(await File('${repository.file.path}.tmp').exists(), isFalse);
  });
}
