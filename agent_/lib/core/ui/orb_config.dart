/// Configurable Cypher orb parameters and profiles.
///
/// This model exists so the Orb Lab can drive the REAL procedural renderer
/// (`cypher_voice_orb.dart`) without duplicating it and without hardcoding
/// tuning constants into the painter. All values are pure numbers so the file
/// is unit-testable without a Flutter binding.
///
/// Every knob is a multiplier or override relative to the orb's built-in
/// per-state profile, so `CypherOrbConfig.standard()` reproduces the stock
/// rendering exactly.
library;

/// Tunable rendering + physics parameters for the voice orb.
class CypherOrbConfig {
  /// Per-state energy overrides (0..1). `null` keeps the built-in profile.
  final double? idleEnergy;
  final double? listeningEnergy;
  final double? processingEnergy;
  final double? executingEnergy;
  final double? speakingEnergy;

  /// Overall jelly deformation amplitude multiplier (0..2, default 1).
  final double deformation;

  /// Deformation frequency multiplier (0..3, default 1).
  final double deformationSpeed;

  /// Internal color-flow frequency multiplier (0..3, default 1).
  final double fluidSpeed;

  /// 0..1 â€” softness dampens high-order harmonics for a smoother silhouette
  /// (0 = crisp multi-harmonic jelly, 1 = calm near-circular blob).
  final double jellySoftness;

  /// Spring stiffness multiplier for touch physics (0.2..2.5, default 1).
  final double elasticity;

  /// Spring damping multiplier for touch physics (0.2..3, default 1).
  final double damping;

  /// Audio amplitude influence multiplier (0..2, default 1).
  final double audioInfluence;

  /// Tap pulse (rim wave) response multiplier (0..2, default 1).
  final double tapResponse;

  /// Touch indentation/pressure influence multiplier (0..2, default 1).
  final double touchInfluence;

  /// 0..1 weight of the higher-order harmonic field (d2..d4) relative to the
  /// base wave (1 = stock mix, 0 = only the base wave survives).
  final double waveStrength;

  /// Ambient glow opacity multiplier (0..2, default 1).
  final double glow;

  /// Interior highlight opacity multiplier (0..2, default 1).
  final double highlight;

  /// 0..1 blend of the interior light between the palette's light/tint
  /// shades (0 = tint-dominant, 1 = light-dominant).
  final double internalColorMix;

  /// Global motion time-scale multiplier (0..2, default 1). 0 freezes motion.
  final double motionScale;

  const CypherOrbConfig({
    this.idleEnergy,
    this.listeningEnergy,
    this.processingEnergy,
    this.executingEnergy,
    this.speakingEnergy,
    this.deformation = 1.0,
    this.deformationSpeed = 1.0,
    this.fluidSpeed = 1.0,
    this.jellySoftness = 0.0,
    this.elasticity = 1.0,
    this.damping = 1.0,
    this.audioInfluence = 1.0,
    this.tapResponse = 1.0,
    this.touchInfluence = 1.0,
    this.waveStrength = 1.0,
    this.glow = 1.0,
    this.highlight = 1.0,
    this.internalColorMix = 1.0,
    this.motionScale = 1.0,
  });

  /// The stock rendering profile (identical to the unwired orb).
  const CypherOrbConfig.standard() : this();

  static double _d(dynamic v, double min, double max, double fallback) {
    if (v is! num) return fallback;
    return (v.toDouble()).clamp(min, max).toDouble();
  }

  static double? _dn(dynamic v) {
    if (v is! num) return null;
    return (v.toDouble()).clamp(0.0, 1.0).toDouble();
  }

  factory CypherOrbConfig.fromJson(Map<String, dynamic> json) {
    return CypherOrbConfig(
      idleEnergy: _dn(json['idleEnergy']),
      listeningEnergy: _dn(json['listeningEnergy']),
      processingEnergy: _dn(json['processingEnergy']),
      executingEnergy: _dn(json['executingEnergy']),
      speakingEnergy: _dn(json['speakingEnergy']),
      deformation: _d(json['deformation'], 0, 2, 1),
      deformationSpeed: _d(json['deformationSpeed'], 0, 3, 1),
      fluidSpeed: _d(json['fluidSpeed'], 0, 3, 1),
      jellySoftness: _d(json['jellySoftness'], 0, 1, 0),
      elasticity: _d(json['elasticity'], 0.2, 2.5, 1),
      damping: _d(json['damping'], 0.2, 3, 1),
      audioInfluence: _d(json['audioInfluence'], 0, 2, 1),
      tapResponse: _d(json['tapResponse'], 0, 2, 1),
      touchInfluence: _d(json['touchInfluence'], 0, 2, 1),
      waveStrength: _d(json['waveStrength'], 0, 1, 1),
      glow: _d(json['glow'], 0, 2, 1),
      highlight: _d(json['highlight'], 0, 2, 1),
      internalColorMix: _d(json['internalColorMix'], 0, 1, 1),
      motionScale: _d(json['motionScale'], 0, 2, 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'idleEnergy': idleEnergy,
        'listeningEnergy': listeningEnergy,
        'processingEnergy': processingEnergy,
        'executingEnergy': executingEnergy,
        'speakingEnergy': speakingEnergy,
        'deformation': deformation,
        'deformationSpeed': deformationSpeed,
        'fluidSpeed': fluidSpeed,
        'jellySoftness': jellySoftness,
        'elasticity': elasticity,
        'damping': damping,
        'audioInfluence': audioInfluence,
        'tapResponse': tapResponse,
        'touchInfluence': touchInfluence,
        'waveStrength': waveStrength,
        'glow': glow,
        'highlight': highlight,
        'internalColorMix': internalColorMix,
        'motionScale': motionScale,
      };

  CypherOrbConfig copyWith({
    double? idleEnergy,
    double? listeningEnergy,
    double? processingEnergy,
    double? executingEnergy,
    double? speakingEnergy,
    bool clearIdleEnergy = false,
    bool clearListeningEnergy = false,
    bool clearProcessingEnergy = false,
    bool clearExecutingEnergy = false,
    bool clearSpeakingEnergy = false,
    double? deformation,
    double? deformationSpeed,
    double? fluidSpeed,
    double? jellySoftness,
    double? elasticity,
    double? damping,
    double? audioInfluence,
    double? tapResponse,
    double? touchInfluence,
    double? waveStrength,
    double? glow,
    double? highlight,
    double? internalColorMix,
    double? motionScale,
  }) {
    return CypherOrbConfig(
      idleEnergy: clearIdleEnergy ? null : (idleEnergy ?? this.idleEnergy),
      listeningEnergy: clearListeningEnergy
          ? null
          : (listeningEnergy ?? this.listeningEnergy),
      processingEnergy: clearProcessingEnergy
          ? null
          : (processingEnergy ?? this.processingEnergy),
      executingEnergy: clearExecutingEnergy
          ? null
          : (executingEnergy ?? this.executingEnergy),
      speakingEnergy: clearSpeakingEnergy
          ? null
          : (speakingEnergy ?? this.speakingEnergy),
      deformation: deformation ?? this.deformation,
      deformationSpeed: deformationSpeed ?? this.deformationSpeed,
      fluidSpeed: fluidSpeed ?? this.fluidSpeed,
      jellySoftness: jellySoftness ?? this.jellySoftness,
      elasticity: elasticity ?? this.elasticity,
      damping: damping ?? this.damping,
      audioInfluence: audioInfluence ?? this.audioInfluence,
      tapResponse: tapResponse ?? this.tapResponse,
      touchInfluence: touchInfluence ?? this.touchInfluence,
      waveStrength: waveStrength ?? this.waveStrength,
      glow: glow ?? this.glow,
      highlight: highlight ?? this.highlight,
      internalColorMix: internalColorMix ?? this.internalColorMix,
      motionScale: motionScale ?? this.motionScale,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CypherOrbConfig &&
      other.idleEnergy == idleEnergy &&
      other.listeningEnergy == listeningEnergy &&
      other.processingEnergy == processingEnergy &&
      other.executingEnergy == executingEnergy &&
      other.speakingEnergy == speakingEnergy &&
      other.deformation == deformation &&
      other.deformationSpeed == deformationSpeed &&
      other.fluidSpeed == fluidSpeed &&
      other.jellySoftness == jellySoftness &&
      other.elasticity == elasticity &&
      other.damping == damping &&
      other.audioInfluence == audioInfluence &&
      other.tapResponse == tapResponse &&
      other.touchInfluence == touchInfluence &&
      other.waveStrength == waveStrength &&
      other.glow == glow &&
      other.highlight == highlight &&
      other.internalColorMix == internalColorMix &&
      other.motionScale == motionScale;

  @override
  int get hashCode => Object.hash(
        idleEnergy, listeningEnergy, processingEnergy, executingEnergy,
        speakingEnergy, deformation, deformationSpeed, fluidSpeed,
        jellySoftness, elasticity, damping, audioInfluence, tapResponse,
        touchInfluence, waveStrength, glow, highlight, internalColorMix,
        motionScale,
      );
}

/// A named, persistable orb configuration (developer-only).
class CypherOrbProfile {
  final String id;
  final String name;
  final CypherOrbConfig config;
  final DateTime updatedAt;

  const CypherOrbProfile({
    required this.id,
    required this.name,
    required this.config,
    required this.updatedAt,
  });

  CypherOrbProfile withConfig(CypherOrbConfig config) => CypherOrbProfile(
        id: id,
        name: name,
        config: config,
        updatedAt: DateTime.now(),
      );

  CypherOrbProfile renamed(String name) => CypherOrbProfile(
        id: id,
        name: name,
        config: config,
        updatedAt: DateTime.now(),
      );

  factory CypherOrbProfile.fromJson(Map<String, dynamic> json) {
    return CypherOrbProfile(
      id: json['id'] is String ? json['id'] as String : '',
      name: json['name'] is String ? json['name'] as String : 'Unnamed',
      config: CypherOrbConfig.fromJson(
        json['config'] is Map<String, dynamic>
            ? json['config'] as Map<String, dynamic>
            : const <String, dynamic>{},
      ),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'config': config.toJson(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is CypherOrbProfile &&
      other.id == id &&
      other.name == name &&
      other.config == config;

  @override
  int get hashCode => Object.hash(id, name, config);
}

/// Programmatic control surface for a live voice orb.
///
/// The orb widget attaches itself as the delegate when it mounts, so the Orb
/// Lab can drive the SAME rendering system a user interacts with by hand.
/// When no orb is attached the calls are safely ignored (never crash, never
/// fake feedback).
class CypherOrbController {
/// The currently bound orb state — wiring-internal: set by the orb widget
  /// when it mounts/dismounts so tooling can drive the same renderer it uses by
   /// hand; kept public (not underscore-private) because the orb widget lives
     /// in a different library. Callers should prefer the methods below and always
       /// guard with [isAttached]; calls are safety no-ops when no orb is bound.
  CypherOrbDelegate? delegate;

  /// True when a live orb is bound to this controller.
  bool get isAttached => delegate != null;

  /// Trigger the tap rim-wave without invoking the orb's onTap callback.
  void pulse() => delegate?.pulse();

  /// Apply a swipe impulse (dx/dy in logical pixels, like a drag delta).
  void swipe(double dx, double dy) => delegate?.swipe(dx, dy);

  /// Increase press depth (as if the user pressed and held).
  void press() => delegate?.press();

  /// Begin a simulated touch at a position relative to the orb center,
  /// expressed in half-size units (0,0 = center; 1,0 = right edge; -1,-1 =
  /// top-left corner).
  void beginTouch(double x, double y) => delegate?.beginTouch(x, y);

  /// Move an active simulated touch.
  void moveTouch(double x, double y) => delegate?.moveTouch(x, y);

  /// Release the simulated touch.
  void endTouch() => delegate?.endTouch();

  /// Reset all interaction physics (settles to rest immediately).
  void reset() => delegate?.resetInteraction();
}

/// Implemented by the orb's widget state; hidden from callers.
abstract class CypherOrbDelegate {
  void pulse();
  void swipe(double dx, double dy);
  void press();
  void beginTouch(double x, double y);
  void moveTouch(double x, double y);
  void endTouch();
  void resetInteraction();
}
