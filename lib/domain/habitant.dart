import 'dart:math' as math;

enum Emotion { curious, calm, cautious, reserved }

enum Activity { observing, exploring, resting }

enum Interaction { greet, offerObject, giveSpace, examineMark }

enum MemoryKind { encounter, interaction, activity, mystery }

enum MysteryStage { hidden, appeared, examined }

/// Rasgos independientes: no existe una puntuación de amistad o felicidad.
class Personality {
  Personality({
    double curiosity = 0.55,
    double trust = 0.30,
    double independence = 0.50,
    double sensitivity = 0.60,
  }) : curiosity = _unit(curiosity),
       trust = _unit(trust),
       independence = _unit(independence),
       sensitivity = _unit(sensitivity);

  final double curiosity;
  final double trust;
  final double independence;
  final double sensitivity;

  Personality change({
    double curiosity = 0,
    double trust = 0,
    double independence = 0,
    double sensitivity = 0,
  }) => Personality(
    curiosity: this.curiosity + curiosity,
    trust: this.trust + trust,
    independence: this.independence + independence,
    sensitivity: this.sensitivity + sensitivity,
  );

  Map<String, Object> toJson() => {
    'curiosity': curiosity,
    'trust': trust,
    'independence': independence,
    'sensitivity': sensitivity,
  };

  factory Personality.fromJson(Map<String, dynamic> json) => Personality(
    curiosity: (json['curiosity'] as num).toDouble(),
    trust: (json['trust'] as num).toDouble(),
    independence: (json['independence'] as num).toDouble(),
    sensitivity: (json['sensitivity'] as num).toDouble(),
  );

  static double _unit(double value) {
    if (!value.isFinite) throw const FormatException('Rasgo no finito');
    return value.clamp(0.0, 1.0).toDouble();
  }
}

class Memory {
  const Memory({
    required this.kind,
    required this.at,
    required this.text,
    this.interaction,
  });

  final MemoryKind kind;
  final DateTime at;
  final String text;
  final Interaction? interaction;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'at': at.toUtc().toIso8601String(),
    'text': text,
    'interaction': interaction?.name,
  };

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
    kind: MemoryKind.values.byName(json['kind'] as String),
    at: DateTime.parse(json['at'] as String).toUtc(),
    text: json['text'] as String,
    interaction: json['interaction'] == null
        ? null
        : Interaction.values.byName(json['interaction'] as String),
  );
}

class Habitant {
  Habitant({
    required this.discoveredAt,
    required this.updatedAt,
    required this.personality,
    this.emotion = Emotion.cautious,
    this.activity = Activity.observing,
    this.mystery = MysteryStage.hidden,
    this.interactions = 0,
    this.lastInteractionAt,
    List<Memory> memories = const [],
  }) : memories = List.unmodifiable(memories.takeLast(memoryLimit));

  static const schemaVersion = 1;
  static const memoryLimit = 100;

  final DateTime discoveredAt;
  final DateTime updatedAt;
  final Personality personality;
  final Emotion emotion;
  final Activity activity;
  final MysteryStage mystery;
  final int interactions;
  final DateTime? lastInteractionAt;
  final List<Memory> memories;

  factory Habitant.discover(DateTime now) => Habitant(
    discoveredAt: now.toUtc(),
    updatedAt: now.toUtc(),
    personality: Personality(),
    memories: [
      Memory(
        kind: MemoryKind.encounter,
        at: now.toUtc(),
        text: 'Alguien miró dentro de la habitación por primera vez.',
      ),
    ],
  );

  Habitant copyWith({
    DateTime? updatedAt,
    Personality? personality,
    Emotion? emotion,
    Activity? activity,
    MysteryStage? mystery,
    int? interactions,
    DateTime? lastInteractionAt,
    List<Memory>? memories,
  }) => Habitant(
    discoveredAt: discoveredAt,
    updatedAt: updatedAt ?? this.updatedAt,
    personality: personality ?? this.personality,
    emotion: emotion ?? this.emotion,
    activity: activity ?? this.activity,
    mystery: mystery ?? this.mystery,
    interactions: interactions ?? this.interactions,
    lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
    memories: memories ?? this.memories,
  );

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'discoveredAt': discoveredAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'personality': personality.toJson(),
    'emotion': emotion.name,
    'activity': activity.name,
    'mystery': mystery.name,
    'interactions': interactions,
    'lastInteractionAt': lastInteractionAt?.toUtc().toIso8601String(),
    'memories': memories.map((m) => m.toJson()).toList(),
  };

  factory Habitant.fromJson(Map<String, dynamic> json) {
    if (json['version'] != schemaVersion) {
      throw const FormatException('Versión de guardado no compatible');
    }
    final interactions = json['interactions'] as int;
    if (interactions < 0) throw const FormatException('Contador inválido');
    return Habitant(
      discoveredAt: DateTime.parse(json['discoveredAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      personality: Personality.fromJson(
        json['personality'] as Map<String, dynamic>,
      ),
      emotion: Emotion.values.byName(json['emotion'] as String),
      activity: Activity.values.byName(json['activity'] as String),
      mystery: MysteryStage.values.byName(json['mystery'] as String),
      interactions: interactions,
      lastInteractionAt: json['lastInteractionAt'] == null
          ? null
          : DateTime.parse(json['lastInteractionAt'] as String).toUtc(),
      memories: (json['memories'] as List<dynamic>)
          .map((m) => Memory.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

extension<T> on List<T> {
  Iterable<T> takeLast(int count) => skip(math.max(0, length - count));
}
