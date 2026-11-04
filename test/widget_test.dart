import 'package:el_habitante/app.dart';
import 'package:el_habitante/data/habitat_repository.dart';
import 'package:el_habitante/domain/habitant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryRepository implements HabitatRepository {
  Habitant? state;

  @override
  Future<Habitant?> load() async => state;

  @override
  Future<void> save(Habitant state) async {
    this.state = state;
  }
}

void main() {
  testWidgets('abre la habitación, interactúa, consulta recuerdos y vuelve a abrir',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MemoryRepository();
    Future<void> open() async {
      await tester.pumpWidget(ElHabitanteApp(
        repositoryFactory: () async => repository,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    await open();
    expect(find.text('Hay alguien del otro lado.'), findsOneWidget);
    await tester.ensureVisible(find.text('Saludar'));
    await tester.tap(find.text('Saludar'));
    await tester.pump();
    expect(repository.state!.interactions, 1);
    await tester.tap(find.byTooltip('Recuerdos y personalidad'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Su mundo interior'), findsOneWidget);
    expect(find.text('Curiosidad: moderada'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await open();
    expect(repository.state!.interactions, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('un toque breve responde y otro durante la pausa recibe aviso',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MemoryRepository();
    await tester.pumpWidget(
      ElHabitanteApp(repositoryFactory: () async => repository),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('Saludar'));
    await tester.tap(find.text('Saludar'));
    await tester.pump();
    expect(repository.state!.interactions, 1);
    expect(find.text('Te acercaste a saludarlo.'), findsOneWidget);

    await tester.ensureVisible(find.text('Dejar una piedra'));
    await tester.tap(find.text('Dejar una piedra'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.state!.interactions, 1);
    expect(
      find.text('Dale un instante para responder antes del próximo gesto.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('envía mensajes de texto sin conexión y registra solamente temas',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MemoryRepository();
    await tester.pumpWidget(ElHabitanteApp(
      repositoryFactory: () async => repository,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final input = find.byType(TextField);
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Me encanta el universo');
    await tester.tap(find.byTooltip('Enviar mensaje local'));
    await tester.pump();
    expect(repository.state?.interests['espacio'], 1);
    expect(repository.state?.lastReply, contains('universo'));
    expect(repository.state?.toJson().toString(), isNot(contains('Me encanta')));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la habitación admite texto grande y una pantalla angosta',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() async {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(ElHabitanteApp(
      repositoryFactory: () async => MemoryRepository(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Hay alguien del otro lado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
