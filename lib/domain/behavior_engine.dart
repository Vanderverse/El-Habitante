import 'dart:math' as math;

import 'habitant.dart';

/// Simulación determinista, sin Flutter, disco, reloj global ni servicios externos.
class BehaviorEngine {
  const BehaviorEngine();

  static const step = Duration(minutes: 5);
  static const maximumSteps = 96; // Hasta ocho horas de evolución por ausencia.
  static const interactionCooldown = Duration(seconds: 3);

  Habitant advance(Habitant state, DateTime now) {
    now = now.toUtc();
    final steps = now.difference(state.updatedAt).inSeconds ~/ step.inSeconds;
    if (steps <= 0) return state; // Tolera atrasos del reloj y no duplica actividad.
    final simulated = math.min(steps, maximumSteps);
    final personality = state.personality.change(
      curiosity: simulated * 0.0007,
      independence: simulated * 0.001,
    );
    final activity = now.hour < 6
        ? Activity.resting
        : personality.independence > 0.55
        ? Activity.exploring
        : Activity.observing;
    final description = switch (activity) {
      Activity.resting => 'Se acurrucó y escuchó los sonidos de la habitación.',
      Activity.exploring => 'Exploró por su cuenta los bordes de la habitación.',
      Activity.observing => 'Estudió las sombras que se mueven por la pared.',
    };
    return _revealMystery(
      state.copyWith(
        // Conserva el resto de la franja; consume toda ausencia, incluso al limitarla.
        updatedAt: state.updatedAt.add(step * steps),
        personality: personality,
        emotion: _emotion(personality),
        activity: activity,
        memories: [
          ...state.memories,
          Memory(kind: MemoryKind.activity, at: now, text: description),
        ],
      ),
      now,
    );
  }

  Habitant interact(Habitant original, Interaction action, DateTime now) {
    now = now.toUtc();
    var state = advance(original, now);
    // Una marca oculta o ya examinada no genera recuerdos ni recompensas.
    if (action == Interaction.examineMark &&
        state.mystery != MysteryStage.appeared) {
      return state;
    }
    final last = state.lastInteractionAt;
    if (now.isBefore(state.updatedAt) ||
        (last != null && now.difference(last) < interactionCooldown)) {
      return state;
    }
    final p = state.personality;
    final personality = switch (action) {
      Interaction.greet => p.change(trust: 0.025, sensitivity: -0.008),
      Interaction.offerObject => p.change(curiosity: 0.04, trust: 0.01),
      Interaction.giveSpace => p.change(independence: 0.035, trust: 0.015),
      Interaction.examineMark => p.change(curiosity: 0.03, sensitivity: 0.02),
    };
    final text = switch (action) {
      Interaction.greet => 'Alguien se acercó despacio. Recordó esa presencia.',
      Interaction.offerObject => 'Encontró una pequeña piedra junto a la puerta.',
      Interaction.giveSpace => 'Le dieron espacio para decidir qué hacer.',
      Interaction.examineMark =>
        'Bajo la marca apareció una frase: «No es la primera habitación».',
    };
    state = state.copyWith(
      personality: personality,
      emotion: _emotion(personality),
      activity: action == Interaction.giveSpace
          ? Activity.resting
          : Activity.observing,
      mystery: action == Interaction.examineMark ? MysteryStage.examined : null,
      interactions: state.interactions + 1,
      lastInteractionAt: now,
      memories: [
        ...state.memories,
        Memory(
          kind: action == Interaction.examineMark
              ? MemoryKind.mystery
              : MemoryKind.interaction,
          at: now,
          text: text,
          interaction: action,
        ),
      ],
    );
    return _revealMystery(state, now);
  }

  Habitant _revealMystery(Habitant state, DateTime now) {
    if (state.mystery != MysteryStage.hidden ||
        (state.interactions < 4 &&
            now.difference(state.discoveredAt) < const Duration(minutes: 30))) {
      return state;
    }
    return state.copyWith(
      mystery: MysteryStage.appeared,
      memories: [
        ...state.memories,
        Memory(
          kind: MemoryKind.mystery,
          at: now,
          text: 'Una marca apareció en la pared. No estaba ahí antes.',
        ),
      ],
    );
  }

  Emotion _emotion(Personality p) {
    if (p.trust < 0.38 && p.sensitivity > 0.5) return Emotion.cautious;
    if (p.curiosity > 0.65) return Emotion.curious;
    if (p.independence > 0.72 && p.trust < 0.5) return Emotion.reserved;
    return Emotion.calm;
  }

  String dialogue(Habitant state) {
    if (state.mystery == MysteryStage.appeared) {
      return 'Esa marca… ¿vos también la ves?';
    }
    if (state.mystery == MysteryStage.examined &&
        state.memories.isNotEmpty &&
        state.memories.last.kind == MemoryKind.mystery) {
      return '¿Cuántas habitaciones habrá antes de esta?';
    }
    if (state.activity == Activity.resting) {
      return 'Voy a quedarme acá un rato. Podés acompañarme en silencio.';
    }
    final lastInteraction = state.memories.isEmpty
        ? null
        : state.memories.last.interaction;
    if (lastInteraction == Interaction.offerObject) {
      return state.emotion == Emotion.cautious
          ? 'Podés dejarla ahí. La miraré cuando me anime.'
          : 'La piedra es fría. Quiero verla de cerca.';
    }
    if (lastInteraction == Interaction.greet && state.emotion == Emotion.cautious) {
      return 'Te vi. Todavía necesito un poquito de distancia.';
    }
    return switch (state.emotion) {
      Emotion.cautious => 'Te estoy conociendo. Acercate despacio.',
      Emotion.curious => state.personality.independence > 0.6
          ? 'Encontré algo por mi cuenta. Quizás te lo muestre.'
          : '¿Qué habrá del otro lado de esa pared?',
      Emotion.reserved => 'Hoy prefiero explorar a mi manera.',
      Emotion.calm => state.personality.trust > 0.55
          ? 'Reconozco tus pasos. Me gusta que vuelvas.'
          : 'La habitación suena distinta cuando estás acá.',
    };
  }
}
