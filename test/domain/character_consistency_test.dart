import 'package:el_habitante/ai/local_brain.dart';
import 'package:el_habitante/domain/behavior_engine.dart';
import 'package:el_habitante/domain/habitant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = BehaviorEngine();
  final now = DateTime.utc(2026, 11, 5, 13);

  test('el personaje no recita que no es asistente', () {
    final prompt = buildHabitantPrompt(Habitant.discover(now));
    expect(prompt, contains('Sos El Habitante'));
    expect(prompt, contains('frases cortas y completas'));
    expect(prompt.toLowerCase(), isNot(contains('no sos un asistente')));
  });

  test('una pregunta no se transforma en recuerdo de confesión', () {
    final initial = Habitant.discover(now);
    final question = engine.converse(
      initial, '¿Fui yo quien te encerró acá?', now,
    );
    expect(question.visitorClaimedToEnclose, isFalse);
    expect(question.memories.last.text, isNot(contains('afirmó')));
  });

  test('negar el encierro no genera desconfianza por una confesión falsa', () {
    final initial = Habitant.discover(now);
    final next = engine.converse(
      initial, 'Yo nunca te encerré', now,
    );
    expect(next.visitorClaimedToEnclose, isFalse);
    expect(next.personality.trust,
        greaterThan(initial.personality.trust));
  });

  test('una afirmación sí se recuerda como no verificada', () {
    final initial = Habitant.discover(now);
    final claim = engine.converse(
      initial, 'Fui yo quien te encerró', now,
    );
    expect(claim.visitorClaimedToEnclose, isTrue);
    expect(claim.memories.last.text, contains('No hay pruebas'));
    expect(
      buildHabitantPrompt(claim),
      contains('una afirmación sin pruebas'),
    );
  });
}
