import 'package:el_habitante/application/habitat_controller.dart';
import 'package:el_habitante/data/habitat_repository.dart';
import 'package:el_habitante/domain/habitant.dart';
import 'package:flutter_test/flutter_test.dart';

class TestRepository implements HabitatRepository {
  Habitant? saved;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  int simultaneousWrites = 0;

  @override
  Future<Habitant?> load() async {
    if (failRead) throw const FormatException('No legible');
    return saved;
  }

  @override
  Future<void> save(Habitant state) async {
    if (failWrite) throw Exception('Sin espacio');
    simultaneousWrites++;
    expect(simultaneousWrites, 1);
    await Future<void>.delayed(Duration.zero);
    saved = state;
    writes++;
    simultaneousWrites--;
  }
}

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);

  test('serializa las escrituras y conserva el estado más reciente', () async {
    final repository = TestRepository();
    var now = start;
    final controller = HabitatController(
      repositoryFactory: () async => repository, clock: () => now,
    );
    addTearDown(controller.dispose);
    await controller.load();
    final first = controller.interact(Interaction.greet);
    now = now.add(const Duration(seconds: 4));
    final second = controller.interact(Interaction.offerObject);
    await Future.wait([first, second]);
    expect(repository.saved!.interactions, 2);
    expect(repository.writes, 3);
  });

  test('un error de lectura no borra recuerdos y permite reintentar', () async {
    final repository = TestRepository()..failRead = true;
    final controller = HabitatController(
      repositoryFactory: () async => repository, clock: () => start,
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.state, isNull);
    expect(controller.error, isNotNull);
    expect(repository.writes, 0);
    repository.failRead = false;
    await controller.load();
    expect(controller.state, isNotNull);
    expect(controller.error, isNull);
  });

  test('informa un guardado fallido y puede recuperar los cambios', () async {
    final repository = TestRepository();
    final controller = HabitatController(
      repositoryFactory: () async => repository, clock: () => start,
    );
    addTearDown(controller.dispose);
    await controller.load();
    repository.failWrite = true;
    await controller.interact(Interaction.greet);
    expect(controller.error, contains('guardar'));
    expect(repository.saved!.interactions, 0);
    repository.failWrite = false;
    await controller.save();
    expect(controller.error, isNull);
    expect(repository.saved!.interactions, 1);
  });

  test('al reabrir calcula la actividad transcurrida una sola vez', () async {
    final repository = TestRepository()..saved = Habitant.discover(start);
    final controller = HabitatController(
      repositoryFactory: () async => repository,
      clock: () => start.add(const Duration(hours: 2)),
    );
    addTearDown(controller.dispose);
    await controller.load();
    final count = controller.state!.memories.length;
    await controller.reconcile();
    expect(controller.state!.memories, hasLength(count));
    expect(controller.state!.mystery, MysteryStage.appeared);
  });
}
