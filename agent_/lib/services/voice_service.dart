import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _disposed = false;

  // Event stream controllers
  final StreamController<VoiceEvent> _eventController =
      StreamController.broadcast();

  String _lastRecognizedText = '';

  bool get isListening => _isListening;
  Stream<VoiceEvent> get eventStream => _eventController.stream;

  /// Whether the platform speech recognizer is ready for use.
  bool get speechRecognitionAvailable => _isInitialized;

  /// Whether the TTS engine is ready for use.
  bool get ttsAvailable => _isInitialized;

  /// Live microphone sound level normalized to 0..1 (0 when unavailable or
  /// not listening). Maps to orb jelly deformation while listening.
  ///
  /// Backed by the recognizer's `onSoundLevelChange` callback (the only sound
  /// level surface in speech_to_text 7.x); never fabricated. Resets to 0
  /// whenever listening stops.
  double _lastSoundLevel = 0;

  double get soundLevelNormalized {
    final raw = _lastSoundLevel;
    if (raw.isNaN || raw.isInfinite) return 0;
    return (raw.clamp(0.0, 10.0) / 10.0).toDouble();
  }

  // ─── Wake word ("Hey Cypher") ───────────────────────────────────────────
  //
  // Placeholder API surface only: background wake-word detection is NOT
  // implemented in this build (there is no native foreground service or
  // detector). The settings tile reports the feature as unavailable and
  // refuses to enable. Do not present these as a working detector; a real
  // implementation requires BackgroundWakeWordService on the native side.
  bool get wakeWordAvailable => false;
  bool get wakeWordListening => false;

  /// Always returns false: wake-word mode cannot be started in this build.
  Future<bool> startWakeWordMode() async => false;

  /// No-op: there is no background wake-word session to stop.
  Future<void> stopWakeWordMode() async {}

  void _emit(VoiceEvent event) {
    if (!_disposed && !_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  Future<void> init() async {
    if (_disposed) return;

    if (_isInitialized) return;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          _isListening = false;
          _emit(
            VoiceEvent(
              type: 'error',
              message: 'Speech recognition error: $error',
            ),
          );
        },
        onStatus: (status) {
          _emit(VoiceEvent(type: 'status', message: 'Speech status: $status'));
        },
      );

      // Configure TTS
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _emit(
        VoiceEvent(type: 'initialized', message: 'Voice service initialized'),
      );
    } catch (e) {
      _isInitialized = false;
      _emit(
        VoiceEvent(type: 'error', message: 'Voice initialization failed: $e'),
      );
    }
  }

  /// Check if TTS engine is available
  Future<bool> isTtsAvailable() async {
    try {
      // flutter_tts should be available if init was successful
      return _isInitialized;
    } catch (e) {
      return false;
    }
  }

  /// Start listening for speech. Returns transcribed text via callback.
  Future<void> startListening({
    required Function(String) onResult,
    required Function() onDone,
  }) async {
    if (!_isInitialized) await init();
    if (_disposed) return;
    if (!_isInitialized) {
      _emit(
        VoiceEvent(type: 'error', message: 'Voice service not initialized'),
      );
      return;
    }

    if (_isListening) return; // Already listening

    _isListening = true;
    _emit(
      VoiceEvent(
        type: 'listening_started',
        message: 'Started listening for voice input',
      ),
    );

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (_disposed) return;
          if (result.recognizedWords.isNotEmpty) {
            _lastRecognizedText = result.recognizedWords;
          }

          if (result.finalResult) {
            _isListening = false;
            _lastSoundLevel = 0;
            _emit(
              VoiceEvent(
                type: 'recognized',
                message: 'Speech recognized',
                content: result.recognizedWords,
              ),
            );
            onResult(result.recognizedWords);
            onDone();
          } else if (result.recognizedWords.isNotEmpty) {
            _emit(
              VoiceEvent(
                type: 'partial_result',
                message: 'Partial result',
                content: result.recognizedWords,
              ),
            );
          }
        },
        onSoundLevelChange: (level) {
          // Real recognizer amplitude; only meaningful while listening.
          if (!_isListening) return;
          _lastSoundLevel = level;
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
          onDevice: false,
        ),
      );
    } catch (e) {
      _isListening = false;
      _emit(VoiceEvent(type: 'error', message: 'Listening error: $e'));
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    _isListening = false;
    _lastSoundLevel = 0;
    await _speech.stop();
    _emit(VoiceEvent(type: 'listening_stopped', message: 'Stopped listening'));
  }

  /// Speak text aloud
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    try {
      _emit(VoiceEvent(type: 'speaking_started', message: 'Started speaking'));

      await _tts.speak(text);

      _emit(
        VoiceEvent(type: 'speaking_completed', message: 'Finished speaking'),
      );
    } catch (e) {
      _emit(VoiceEvent(type: 'error', message: 'TTS error: $e'));
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _emit(VoiceEvent(type: 'speaking_stopped', message: 'Stopped speaking'));
  }

  /// Get last recognized text
  String getLastRecognizedText() => _lastRecognizedText;

  /// Clear last recognized text
  void clearLastRecognizedText() => _lastRecognizedText = '';

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isListening = false;
    unawaited(_speech.stop().catchError((_) {}));
    unawaited(_tts.stop().catchError((_) {}));
    _eventController.close();
  }
}

/// Voice event for streaming updates
class VoiceEvent {
  final String
  type; // initialized, listening_started, listening_stopped, recognized, partial_result, speaking_started, speaking_completed, speaking_stopped, error
  final String message;
  final String? content;

  /// Wake-word surface state (null when the event is unrelated to the
  /// wake-word feature; always null in the current no-op stub).
  final bool? wakeWordAvailable;
  final bool? wakeWordEnabled;
  final bool? wakeWordListening;

  VoiceEvent({
    required this.type,
    required this.message,
    this.content,
    this.wakeWordAvailable,
    this.wakeWordEnabled,
    this.wakeWordListening,
  });

  @override
  String toString() =>
      'VoiceEvent($type: $message' +
      (content != null ? ', "$content"' : '') +
      ')';
}
