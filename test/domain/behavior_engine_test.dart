import 'dart:convert';

import 'package:el_habitante/domain/behavior_engine.dart';
import 'package:el_habitante/domain/habitant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = BehaviorEngine();
  final start = DateTime.utc(2026, 1, 1, 12);

  test('el primer encuentro crea personalidad y un recuerdo estructurado', () {
    final state = Habitant.discover(start);
    expect(state.emotion, Emotion.cautious);
    expect(state.memories.single.kind, MemoryKind.encounter);
    expect(state.memories.single.at, start);
    expect(state.mystery, MysteryStage.hidden);
  });

  test('cada interacción modifica rasgos distintos', () {
    final initial = Habitant.discover(start);
    final greeting = engine.interact(initial, Interaction.greet, start);
    final object = engine.interact(initial, Interaction.offerObject, start);
    final space = engine.interact(initial, Interaction.giveSpace, start);
    expect(greeting.personality.trust, greaterThan(initial.personality.trust));
    expect(greeting.personality.curiosity, initial.personality.curiosity);
    expect(object.personality.curiosity, greaterThan(initial.personality.curiosity));
    expect(space.personality.independence,
        greaterThan(initial.personality.independence));
    expect(greeting.memories.last.kind, MemoryKind.interaction);
  });

  test('los toques repetidos no aumentan rasgos ni recuerdos', () {
    final first = engine.interact(
      Habitant.discover(start), Interaction.greet, start,
    );
    final second = engine.interact(
      first, Interaction.greet, start.add(const Duration(seconds: 1)),
    );
    expect(identical(first, second), isTrue);
    expect(second.interactions, 1);
  });

  test('los rasgos se mantienen finitos y entre cero y uno', () {
    final p = Personality(trust: 2, curiosity: -1).change(
      sensitivity: 500, independence: -500,
    );
    expect(p.trust, 1);
    expect(p.curiosity, 0);
    expect(p.sensitivity, 1);
    expect(p.independence, 0);
    expect(() => Personality(trust: double.nan), throwsFormatException);
  });

  test('la ausencia produce actividad y rasgos, sin castigar la confianza', () {
    final initial = Habitant.discover(start);
    final next = engine.advance(initial, start.add(const Duration(hours: 2)));
    expect(next.personality.independence,
        greaterThan(initial.personality.independence));
    expect(next.personality.trust, initial.personality.trust);
    expect(next.memories.where((m) => m.kind == MemoryKind.activity), hasLength(1));
    expect(next.updatedAt, start.add(const Duration(hours: 2)));
  });

  test('limita ausencias largas y no vuelve a procesar el tiempo consumido', () {
    final initial = Habitant.discover(start);
    final eightHours = engine.advance(initial, start.add(const Duration(hours: 8)));
    final year = engine.advance(initial, start.add(const Duration(days: 365)));
    expect(year.personality.toJson(), eightHours.personality.toJson());
    expect(identical(engine.advance(year, year.updatedAt), year), isTrue);
  });

  test('tolera un reloj atrasado y conserva minutos parciales', () {
    final initial = Habitant.discover(start);
    expect(identical(engine.advance(initial,
        start.subtract(const Duration(hours: 1))), initial), isTrue);
    final next = engine.advance(initial, start.add(const Duration(minutes: 7)));
    expect(next.updatedAt, start.add(const Duration(minutes: 5)));
    final later = engine.advance(next, start.add(const Duration(minutes: 10)));
    expect(later.updatedAt, start.add(const Duration(minutes: 10)));
  });

  test('no reinicia el tiempo de ausencia con cada toque', () {
    var state = Habitant.discover(start);
    state = engine.interact(state, Interaction.greet,
        start.add(const Duration(minutes: 4)));
    state = engine.advance(state, start.add(const Duration(minutes: 5)));
    expect(state.memories.any((m) => m.kind == MemoryKind.activity), isTrue);
  });

  test('el misterio aparece una vez tras cuatro gestos y puede examinarse', () {
    var state = Habitant.discover(start);
    for (var i = 0; i < 4; i++) {
      state = engine.interact(state, Interaction.greet,
          start.add(Duration(seconds: i * 4)));
    }
    expect(state.mystery, MysteryStage.appeared);
    expect(state.memories.where((m) => m.kind == MemoryKind.mystery), hasLength(1));
    expect(engine.dialogue(state), contains('marca'));
    state = engine.interact(state, Interaction.examineMark,
        start.add(const Duration(seconds: 20)));
    expect(state.mystery, MysteryStage.examined);
    expect(state.memories.last.text, contains('primera habitación'));
    final repeated = engine.interact(state, Interaction.examineMark,
        start.add(const Duration(seconds: 30)));
    expect(identical(repeated, state), isTrue);
    final later = engine.advance(state, start.add(const Duration(hours: 1)));
    expect(later.memories.where((m) => m.kind == MemoryKind.mystery), hasLength(2));
  });

  test('el misterio también aparece tras treinta minutos sin interacciones', () {
    final initial = Habitant.discover(start);
    final state = engine.advance(initial, start.add(const Duration(minutes: 30)));
    expect(state.interactions, 0);
    expect(state.mystery, MysteryStage.appeared);
  });

  test('una marca oculta no puede examinarse', () {
    final initial = Habitant.discover(start);
    expect(identical(engine.interact(initial, Interaction.examineMark, start),
        initial), isTrue);
  });

  test('los diálogos dependen de los rasgos, la emoción y la actividad', () {
    final initial = Habitant.discover(start);
    final trusting = initial.copyWith(
      emotion: Emotion.calm, personality: Personality(trust: 0.8),
    );
    expect(engine.dialogue(initial), contains('despacio'));
    expect(engine.dialogue(trusting), contains('Reconozco'));
    expect(engine.dialogue(trusting.copyWith(activity: Activity.resting)),
        contains('silencio'));
  });

  test('conversa sobre temas conocidos y nunca guarda el mensaje literal', () {
    final initial = Habitant.discover(start);
    final next = engine.converse(
        initial, 'Mi contraseña de skyrim es SECRET123', start);
    expect(next.interests['juegos'], 1);
    expect(next.personality.trust, greaterThan(initial.personality.trust));
    expect(next.memories.last.kind, MemoryKind.conversation);
    expect(next.memories.last.text, 'Conversamos sobre videojuegos.');
    expect(engine.dialogue(next), contains('juegos'));
    expect(jsonEncode(next.toJson()), isNot(contains('SECRET123')));
  });

  test('las conversaciones repetidas refuerzan un interés, respetando la pausa', () {
    var state = Habitant.discover(start);
    state = engine.converse(state, 'Me gusta la música', start);
    final unchanged = engine.converse(
        state, 'Otra canción', start.add(const Duration(seconds: 1)));
    expect(identical(unchanged, state), isTrue);
    state = engine.converse(
        state, 'Otra canción', start.add(const Duration(seconds: 4)));
    state = engine.converse(
        state, 'Quiero cantar', start.add(const Duration(seconds: 8)));
    expect(state.interests['musica'], 3);
    expect(engine.dialogue(state), contains('varias veces'));
  });

  test('los guardados de 0.1 se abren sin perder personalidad ni recuerdos', () {
    final old = Habitant.discover(start).toJson()
      ..remove('interests')
      ..remove('lastReply');
    final recovered = Habitant.fromJson(
        jsonDecode(jsonEncode(old)) as Map<String, dynamic>);
    expect(recovered.interests, isEmpty);
    expect(recovered.lastReply, isNull);
    expect(recovered.memories, hasLength(1));
    expect(recovered.personality.toJson(), Habitant.discover(start).personality.toJson());
  });

  test('el misterio avanza cuando conversa sobre la marca examinada', () {
    var state = Habitant.discover(start);
    for (var i = 0; i < 4; i++) {
      state = engine.interact(
          state, Interaction.greet, start.add(Duration(seconds: i * 4)));
    }
    state = engine.interact(
        state, Interaction.examineMark, start.add(const Duration(seconds: 16)));
    expect(state.mystery, MysteryStage.examined);
    state = engine.converse(
        state, '¿Qué es esa marca?', start.add(const Duration(seconds: 20)));
    expect(state.mystery, MysteryStage.signal);
    expect(engine.dialogue(state), contains('NO ESTÁS SOLO'));
    expect(state.memories.where((m) => m.kind == MemoryKind.mystery), hasLength(3));
    final again = engine.converse(
        state, '¿Hay otra señal?', start.add(const Duration(seconds: 24)));
    expect(again.memories.where((m) => m.kind == MemoryKind.mystery), hasLength(3));
  });

  test('los recuerdos están acotados y conservan los más recientes', () {
    final state = Habitant.discover(start).copyWith(
      memories: List.generate(200, (i) => Memory(
        kind: MemoryKind.activity, at: start, text: '$i',
      )),
    );
    expect(state.memories, hasLength(Habitant.memoryLimit));
    expect(state.memories.first.text, '100');
    expect(state.memories.last.text, '199');
    expect(() => state.memories.clear(), throwsUnsupportedError);
  });

  test('JSON conserva todos los atributos y rechaza versiones desconocidas', () {
    final state = engine.interact(Habitant.discover(start),
        Interaction.offerObject, start);
    final decoded = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
    expect(Habitant.fromJson(decoded).toJson(), state.toJson());
    decoded['version'] = 999;
    expect(() => Habitant.fromJson(decoded), throwsFormatException);
  });
}
