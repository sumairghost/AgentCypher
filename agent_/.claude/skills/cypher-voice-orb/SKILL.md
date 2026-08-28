# Skill: Cypher Voice Orb

Procedural, interactive voice-assistant orb for Agent Cypher. No Lottie, Rive,
GIFs, videos, or external animation assets — the orb is rendered live by a
Flutter `CustomPainter` so its appearance reacts to real application state.

## Rendering architecture

Renderer lives in `lib/core/ui/cypher_voice_orb.dart`.

Component layers (one file, clearly separated):

1. **State controller** — `CypherVoiceOrbState` enum + `_StateProfile.of(state)`
   → per-state `energy`, `deformAmp`, `deformSpeed`, `flowSpeed`, `audioGain`,
   and optional `error`/`dim` tint. The widget runs one `Ticker` (not multiple
   animation controllers), accumulates continuous time `t`, eases the open/close
   `scale`, and decays a `tapPulse` wave.
2. **Visual renderer** — `_OrbPainter` (pure `CustomPainter`):
   - Organic silhouette: 60 radial segments of a multi-harmonic jelly field
     (`sin θ`, `sin 2θ`, `sin 3θ`, `sin 4θ` with per-instance phase seeds so no
     two orbs move identically), closed with `quadraticBezierTo` midpoints.
   - Interior light: clip to the blob, fill with a drifting multi-stop radial
     gradient (`light → base → container → deep`), overlay 2 orbiting soft light
     regions, and a touch-region brightening. Everything is one theme family.
   - Rim: blurred hairline gradient stroke, bright top sheen fading down.
   - Ambient glow: cheap radial fill (no `BackdropFilter` anywhere).
3. **Touch interaction** — `_OrbInteraction`: spring/damper physics on
   displacement (stiffness 90, damping 9, max displacement 0.20 of size),
   finger-angular indentation, press depth, swipe squash, and frame-by-frame
   relaxation. No per-frame widget rebuilds of the wider screen.
4. **Audio input mapping** — `audioLevel` (0..1) parameter. In LISTENING /
   SPEAKING states it drives low-order jelly harmonics and energy. Callers
   poll the platform recognizer (`SpeechToText.getSoundLevel()`) while
   listening; normalized to 0..1.
5. **Theme input** — colors come exclusively from `context.cypher.colors`
   (`accent`, `accentLight`, `accentDark`, `accentContainer`, `error`, …).
   Never hardcode a hue; the orb follows presets and custom accents for free.

## State model and voice mapping

| State         | Real trigger                              | Visual profile                                  |
|---------------|-------------------------------------------|-------------------------------------------------|
| idle          | Launcher shown, no session                | Calm: low energy, slow breathing, faint flow    |
| opening       | Launcher tapped → expanding               | Elastic stretch, rising energy                  |
| listening     | Microphone actively recognizing           | Energy follows live audio amplitude             |
| processing    | Waiting for the model response            | Swirling internal flow, moderate energy         |
| executing     | Agent task loop running (1.5–2× idle)     | Highest energy, pronounced elastic motion       |
| speaking      | TTS is speaking                            | Rhythmic, audio-coupled deformation             |
| closing       | Session ending                            | Contracts to launcher size                      |
| cancelled     | Stop/cancel requested                     | Quick dip then settle                           |
| error         | Mic failure, permission denied, net/model fail | Error tint, erratic deformation            |
| unavailable   | `enabled: false` / uninitialized voice    | Dim, near-static                                |

## Interaction model

Tap → elastic pulse + traveling rim wave. Press/hold → indentation toward the
finger, brighter touched region, depth-scaled. Drag → displacement + directional
stretch. Swipe → velocity impulse + vertical squash, damped rebound. Springs and
damping make it behave like viscous jelly, not a translated icon.

## Theme integration

Orb colors derive from semantic tokens only. Presets already produce correct
families; when a custom accent is active, `CypherColorTokens.accent*` reflect it
automatically, so the orb needs no per-theme branches.

## Performance requirements

- One ticker + one `CustomPainter` per orb; localized rebuilds only.
- No `BackdropFilter`, `MaskFilter.blur` limited to the rim stroke, no image
  decode, no per-frame allocations beyond a few paths/gradients.
- `shouldRepaint` returns true (motion), but paint work is minimal and GPU-safe.
- Dispose the ticker in `dispose()`; guard `dt` against pauses (`dt > 0.1`).
- Reduce work automatically for containers not visible (callers should remove
  or pause the orb when off-screen).

## Accessibility requirements

- Semantic label per state (idle / listening / processing / speaking / error /
  unavailable) via `Semantics`; animation must never be the only state signal.
- 44dp+ minimum touch target; `tooltip`/label covers the compact launcher.
- Reduced motion (`MediaQuery.disableAnimationsOf`) scales motion to 0.15× —
  deformation and speeds drop, but state color/glow feedback remains.

## Responsive positioning

No hardcoded screen size. The widget is sized by its parent; the launcher is
56×56, the full orb 96–200 depending on available layout. Callers position it
inside `SafeArea`/`LayoutBuilder` bounds (overlay already clamps to display
bounds via the native overlay resize mechanism).

## Audio plumbing (verified on device before claiming)

`VoiceService.soundLevelNormalized` wraps `SpeechToText.getSoundLevel()`.
Wire it only while the recognizer is actively listening; do not fabricate
amplitude. TTS amplitude is not available from `flutter_tts`; SPEAKING can
either feed the last-known audio envelope or run its rhythmic profile — never
claim live TTS amplitude without device evidence.