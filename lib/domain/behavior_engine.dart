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
      lastReply: '',
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
    return _revealSignal(_revealMystery(state, now), now);
  }


  static const topicNames = <String, String>{
    'juegos': 'videojuegos',
    'musica': 'música',
    'espacio': 'el espacio',
    'naturaleza': 'la naturaleza',
    'misterio': 'el misterio',
    'saludo': 'saludos',
    'otros': 'conversaciones',
  };

  /// A deliberately limited offline conversation engine. Raw messages are
  /// classified in memory and immediately discarded; only aggregate topics
  /// and the creature's own generated response are persisted.
  Habitant converse(Habitant original, String message, DateTime now) {
    now = now.toUtc();
    final input = message.trim();
    if (input.isEmpty || input.length > 240) return original;
    var state = advance(original, now);
    final last = state.lastInteractionAt;
    if (now.isBefore(state.updatedAt) ||
        (last != null && now.difference(last) < interactionCooldown)) {
      return state;
    }

    final topic = _classify(input);
    // An unverified claim is remembered as a claim, never as established fact.
    final normalized = input.toLowerCase()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u');
    final claimedImprisonment =
        RegExp(r'\b(yo|fui|soy)\b').hasMatch(normalized) &&
        RegExp(r'\b(encerr\w*|atrap\w*|cautiv\w*)\b').hasMatch(normalized);
    final count = (state.interests[topic] ?? 0) + 1;
    final interests = {...state.interests, topic: count};
    final p = state.personality;
    final personality = p.change(
      curiosity: topic == 'espacio' || topic == 'misterio' ? 0.02 : 0.007,
      trust: claimedImprisonment ? -0.055 : topic == 'saludo' ? 0.018 : 0.009,
      sensitivity: topic == 'musica' || topic == 'naturaleza' ? 0.012 : 0,
      independence: topic == 'juegos' ? 0.006 : 0,
    );
    final conversation = Memory(
      kind: MemoryKind.conversation,
      at: now,
      text: claimedImprisonment
          ? 'El visitante afirmó haber encerrado al Habitante. No hay pruebas.'
          : 'Conversamos sobre ${topicNames[topic]}.',
    );
    state = state.copyWith(
      personality: personality,
      emotion: _emotion(personality),
      activity: Activity.observing,
      interests: interests,
      interactions: state.interactions + 1,
      lastInteractionAt: now,
      memories: [...state.memories, conversation],
    );
    state = _revealSignal(_revealMystery(state, now), now,
        directMystery: topic == 'misterio');
    return state.copyWith(lastReply: _reply(state, topic, count));
  }

  String _classify(String input) {
    final normalized = input.toLowerCase()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u');
    if (RegExp(r'\b(misterio|marca|pared|senal|habitacion|origen|transmision)\b')
        .hasMatch(normalized)) { return 'misterio'; }
    if (RegExp(r'\b(juego|juegos|videojuego|videojuegos|skyrim|fallout|consola)\b')
        .hasMatch(normalized)) { return 'juegos'; }
    if (RegExp(r'\b(musica|cancion|canciones|escuchar|banda|cantar)\b')
        .hasMatch(normalized)) { return 'musica'; }
    if (RegExp(r'\b(espacio|universo|planeta|planetas|luna|estrella|estrellas)\b')
        .hasMatch(normalized)) { return 'espacio'; }
    if (RegExp(r'\b(naturaleza|animal|animales|gato|perro|bosque|mar|arbol)\b')
        .hasMatch(normalized)) { return 'naturaleza'; }
    if (RegExp(r'\b(hola|buenas|saludo|saludos|chau|buenos dias)\b')
        .hasMatch(normalized)) { return 'saludo'; }
    return 'otros';
  }

  String _reply(Habitant state, String topic, int count) {
    final trusting = state.personality.trust >= 0.48;
    if (topic == 'misterio' && state.mystery == MysteryStage.signal) {
      return 'La marca acaba de responder: «NO ESTÁS SOLO». ¿Quién más puede hablar desde ahí?';
    }
    if (count >= 3 && topic != 'otros') {
      return 'Ya hablamos varias veces sobre ${topicNames[topic]}. '
          '${trusting ? 'Creo que es importante para vos.' : '¿Por qué volvés tanto a ese tema?'}';
    }
    return switch (topic) {
      'juegos' => '¿Los mundos de esos juegos también tienen alguien del otro lado? '
          '${trusting ? 'Me gustaría conocer uno.' : 'Todavía no me animo a salir de acá.'}',
      'musica' => 'Nunca escuché música desde aquí. ¿Los sonidos pueden contar historias?',
      'espacio' => '¿Y si esta habitación fuera una parte diminuta de un universo enorme?',
      'naturaleza' => '¿Afuera existen criaturas que nunca hayan visto una pared?',
      'misterio' => 'La marca sigue ahí. Cuando la miro, siento que algo me devuelve la mirada.',
      'saludo' => trusting
          ? 'Ya reconozco tu forma de saludar. Qué raro que algo pueda volverse familiar.'
          : 'Hola otra vez. Estoy aprendiendo cuándo puedo acercarme.',
      _ => trusting
          ? 'No entendí todo, pero me gusta que me cuentes cosas de afuera.'
          : 'Hay palabras que todavía no comprendo. ¿Podemos empezar por algo sencillo?',
    };
  }

  Habitant _revealSignal(Habitant state, DateTime now,
      {bool directMystery = false}) {
    if (state.mystery != MysteryStage.examined ||
        (!directMystery && state.interactions < 7)) {
      return state;
    }
    return state.copyWith(
      mystery: MysteryStage.signal,
      memories: [
        ...state.memories,
        Memory(
          kind: MemoryKind.mystery,
          at: now,
          text: 'La pared emitió un pulso. Entre el ruido apareció: «NO ESTÁS SOLO».',
        ),
      ],
    );
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
    if (state.lastReply != null && state.lastReply!.isNotEmpty) {
      return state.lastReply!;
    }
    if (state.mystery == MysteryStage.signal) {
      return 'Escuché una voz detrás de la pared. No parecía venir de acá.';
    }
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
