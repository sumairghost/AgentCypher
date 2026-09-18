import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'services/ai_service.dart';
import 'services/task_executor.dart';
import 'services/screen_automation_service.dart';
import 'services/app_launcher_service.dart';
import 'services/shizuku_service.dart';
import 'services/chat_history_service.dart';
import 'models/chat_message.dart';
import 'models/assistant_overlay_phase.dart';
import 'widgets/message_bubble.dart';
import 'widgets/overlay/assistant_orb.dart';

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  bool _isExpanded = false;
  AssistantOverlayPhase _phase = AssistantOverlayPhase.idle;
  final TextEditingController _taskController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSent = false;
  bool _isListening = false;
  bool _speechReady = false;
  double _audioLevel = 0;
  Timer? _audioPoller;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final List<ChatMessage> _messages = [];

  late final AiService _aiService;
  late final ScreenAutomationService _screenService;
  late final AppLauncherService _appLauncher;
  late final ShizukuService _shizukuService;
  late final Future<void> _servicesReady;
  StreamSubscription<dynamic>? _overlaySubscription;
  TaskExecutor? _executor;
  Future<void> _overlayHistoryWrite = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _speech
        .initialize(
          onError: (error) {
            if (!mounted) return;
            _stopAudioPoller();
            setState(() => _isListening = false);
            log('Overlay speech error: $error');
          },
          onStatus: (status) {
            if (!mounted) return;
            if (status == 'notListening' || status == 'done') {
              _stopAudioPoller();
              setState(() {
                _isListening = false;
                if (_phase == AssistantOverlayPhase.listening) {
                  _phase = AssistantOverlayPhase.idle;
                }
              });
            }
          },
        )
        .then((available) {
          _speechReady = available;
        })
        .catchError((error) {
          _speechReady = false;
          log('Overlay speech initialization failed: $error');
        });

    _aiService = AiService();
    _screenService = ScreenAutomationService();
    _appLauncher = AppLauncherService();
    _shizukuService = ShizukuService();
    _servicesReady = _initializeServices();
    _overlaySubscription = FlutterOverlayWindow.overlayListener.listen(
      _handleMainAppEvent,
    );

    // Welcome message
    _messages.add(
      ChatMessage(
        role: 'assistant',
        content:
            'Hi! I am your Private Agent. Ask me to perform any task on your screen.',
      ),
    );
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    _executor?.cancel();
    _stopAudioPoller();
    unawaited(_speech.stop().catchError((_) {}));
    _taskController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleMainAppEvent(dynamic event) {
    if (event is! String || !event.startsWith('OVERLAY_')) return;

    final separator = event.indexOf('|');
    final type = separator == -1 ? event : event.substring(0, separator);
    final message = separator == -1 ? '' : event.substring(separator + 1);

    if (type == 'OVERLAY_HISTORY') {
      try {
        final decoded = jsonDecode(utf8.decode(base64Decode(message))) as List;
        final history = decoded
            .map(
              (item) =>
                  ChatMessage.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        if (!mounted) return;
        setState(() {
          _messages
            ..clear()
            ..addAll(history);
          _isSent = true;
          _scrollToBottom();
        });
      } catch (error) {
        log('Overlay history sync failed: $error');
      }
      return;
    }

    if (type == 'OVERLAY_RESET') {
      if (!mounted) return;
      setState(() {
        _isExpanded = false;
        _isSent = false;
      });
      return;
    }

    if (message.isEmpty || !mounted) return;
    setState(() {
      _isSent = type != 'OVERLAY_TASK_FINISHED';
      _messages.add(ChatMessage(role: 'assistant', content: message));
      _scrollToBottom();
    });
  }

  Future<void> _initializeServices() async {
    // 1. Send registration broadcast first so native MethodChannels are active
    final intent = const AndroidIntent(
      action: 'com.cypherghost.agentcypher.REGISTER_BACKGROUND_CHANNELS',
      package: 'com.cypherghost.agentcypher',
    );
    try {
      await intent.sendBroadcast();
    } catch (e) {
      log("Broadcast error: $e");
    }

    // 2. Wait a brief moment for registration
    await Future.delayed(const Duration(milliseconds: 150));

    // 3. Initialize AI Service settings
    await _aiService.init();

    // 4. Safely query Shizuku without locking startup
    try {
      await _shizukuService.checkAvailability();
    } catch (e) {
      log("Shizuku check error: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _persistOverlayMessage(ChatMessage message) {
    _overlayHistoryWrite = _overlayHistoryWrite
        .then((_) => ChatHistoryService.appendOverlayMessage(message.toJson()))
        .catchError((Object error) {
          log('Overlay history handoff failed: $error');
        });
  }

  Future<void> _toggleListening() async {
    if (!mounted) return;
    if (_isListening) {
      _stopAudioPoller();
      try {
        await _speech.stop();
      } catch (error) {
        log('Overlay speech stop failed: $error');
      }
      if (mounted) {
        setState(() {
          _isListening = false;
          if (_phase == AssistantOverlayPhase.listening) {
            _phase = AssistantOverlayPhase.idle;
          }
        });
      }
      return;
    }

    if (!_speechReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input is unavailable. Check microphone permission.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _phase = AssistantOverlayPhase.listening;
    });
    _startAudioPoller();
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (result.finalResult) {
            _stopAudioPoller();
            setState(() {
              _isListening = false;
              _taskController.text = result.recognizedWords;
            });
            _sendTask(result.recognizedWords);
          }
        },
        onSoundLevelChange: (level) {
          // Real recognizer amplitude; only meaningful while listening.
          if (!_isListening) return;
          _lastSoundLevel = level;
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          partialResults: false,
        ),
      );
    } catch (error) {
      log('Overlay speech start failed: $error');
      _stopAudioPoller();
      if (mounted) {
        setState(() {
          _isListening = false;
          if (_phase == AssistantOverlayPhase.listening) {
            _phase = AssistantOverlayPhase.idle;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start voice input.')),
        );
      }
    }
  }

  /// Polls the live microphone sound level while listening and feeds it to
  /// the orb so its jelly deformation reacts to real voice amplitude.
  void _startAudioPoller() {
    _audioPoller?.cancel();
    _audioPoller = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      final level = _soundLevelNormalized();
      if ((level - _audioLevel).abs() > 0.004) {
        setState(() => _audioLevel = level);
      }
    });
  }

  void _stopAudioPoller() {
    _audioPoller?.cancel();
    _audioPoller = null;
    _audioLevel = 0;
    _lastSoundLevel = 0;
  }

  /// Last level reported by the recognizer's `onSoundLevelChange` callback
  /// (the only sound level surface in speech_to_text 7.x). Zero when not
  /// listening or before the first event; never fabricated.
  double _lastSoundLevel = 0;

  double _soundLevelNormalized() {
    final raw = _lastSoundLevel;
    if (raw.isNaN || raw.isInfinite) return 0;
    return (raw.clamp(0.0, 10.0) / 10.0).toDouble();
  }

  /// Human-readable name for the current overlay phase.
  String _phaseName(AssistantOverlayPhase phase) {
    switch (phase) {
      case AssistantOverlayPhase.idle:
        return 'Idle';
      case AssistantOverlayPhase.expanded:
        return 'Expanded';
      case AssistantOverlayPhase.listening:
        return 'Listening';
      case AssistantOverlayPhase.thinking:
        return 'Thinking';
      case AssistantOverlayPhase.executing:
        return 'Executing';
      case AssistantOverlayPhase.success:
        return 'Done';
      case AssistantOverlayPhase.error:
        return 'Error';
      case AssistantOverlayPhase.awaitingApproval:
        return 'Needs approval';
    }
  }

  /// Short progress text shown while a task is running.
  String _statusText(AssistantOverlayPhase phase) {
    switch (phase) {
      case AssistantOverlayPhase.idle:
        return 'Ready';
      case AssistantOverlayPhase.expanded:
        return 'Expanded';
      case AssistantOverlayPhase.listening:
        return 'Listening…';
      case AssistantOverlayPhase.thinking:
        return 'Planning…';
      case AssistantOverlayPhase.executing:
        return 'Running task…';
      case AssistantOverlayPhase.success:
        return 'Task completed';
      case AssistantOverlayPhase.error:
        return 'Task failed';
      case AssistantOverlayPhase.awaitingApproval:
        return 'Waiting for your approval';
    }
  }

  Future<void> _sendTask(String task) async {
    if (task.trim().isEmpty) return;
    // Duplicate-prevention: reject while a prior request is active.
    if (_isSent || _executor != null) {
      log('Overlay duplicate request blocked: _isSent=$_isSent executor=${_executor != null}');
      return;
    }

    final userTask = task.trim();
    final userMessage = ChatMessage(role: 'user', content: userTask);
    setState(() {
      _isSent = true;
      _messages.add(userMessage);
      _scrollToBottom();
    });
    _persistOverlayMessage(userMessage);

    _taskController.clear(); // Clear immediately for responsive UX feedback

    try {
      await _servicesReady;
    } catch (error) {
      log('Overlay services failed to initialize: $error');
      if (mounted) {
        final errorMessage = ChatMessage(
          role: 'assistant',
          content:
              'Background services are unavailable. Please reopen the overlay and try again.',
        );
        setState(() {
          _isSent = false;
          _messages.add(errorMessage);
          _scrollToBottom();
        });
        _persistOverlayMessage(errorMessage);
      }
      return;
    }
    if (!mounted) return;
    if (!await _screenService.waitUntilReady()) {
      if (mounted) {
        final errorMessage = ChatMessage(
          role: 'assistant',
          content:
              'The background accessibility bridge did not respond. '
              'Close and reopen the floating overlay, then try again.',
        );
        setState(() {
          _isSent = false;
          _messages.add(errorMessage);
          _scrollToBottom();
        });
        _persistOverlayMessage(errorMessage);
      }
      return;
    }

    try {
      // Execute the task directly in the overlay isolate!
      _phase = AssistantOverlayPhase.thinking;
      _executor = TaskExecutor(
        aiService: _aiService,
        screenService: _screenService,
        appLauncher: _appLauncher,
        shizukuService: _shizukuService,
        onProgress: (msg) {
          log("Overlay Task Progress: $msg");
          if (mounted) {
            final progressMessage = ChatMessage(
              role: 'assistant',
              content: msg,
            );
            setState(() {
              if (_phase == AssistantOverlayPhase.thinking || _phase == AssistantOverlayPhase.idle) {
                _phase = AssistantOverlayPhase.executing;
              }
              _messages.add(progressMessage);
              _scrollToBottom();
            });
            _persistOverlayMessage(progressMessage);
          }
        },
      );

      _executor!
          .executeTask(userTask)
          .then((res) {
            log("Overlay Task Finished");
            _executor = null;
            if (mounted) {
              final resultMessage = ChatMessage(
                role: 'assistant',
                content: res,
              );
              final lowered = res.toLowerCase();
              final wasCancelled = lowered.contains('cancel') || lowered.contains('cancelled');
              final wasAwaitingApproval = lowered.contains('approval') || lowered.contains('review') || lowered.contains('preview');
              setState(() {
                _isSent = false;
                _phase = wasCancelled
                    ? AssistantOverlayPhase.idle
                    : (wasAwaitingApproval ? AssistantOverlayPhase.awaitingApproval : AssistantOverlayPhase.success);
                _messages.add(resultMessage);
                _scrollToBottom();
              });
              _persistOverlayMessage(resultMessage);
            }
          })
          .catchError((e) {
            log("Overlay Task Error: $e");
            _executor = null;
            if (mounted) {
              final errorMessage = ChatMessage(
                role: 'assistant',
                content: 'I could not complete that task. Please try again.',
              );
              setState(() {
                _isSent = false;
                _phase = AssistantOverlayPhase.error;
                _messages.add(errorMessage);
                _scrollToBottom();
              });
              _persistOverlayMessage(errorMessage);
            }
          });
    } catch (e) {
      _executor = null;
      log("Overlay Task Execution Exception: $e");
      if (mounted) {
        final errorMessage = ChatMessage(
          role: 'assistant',
          content: 'I could not complete that task. Please try again.',
        );
        setState(() {
          _isSent = false;
          _messages.add(errorMessage);
          _scrollToBottom();
        });
        _persistOverlayMessage(errorMessage);
      }
    }
  }

  OverlayPosition? _savedBubblePosition;

  Future<void> _toggleExpanded() async {
    if (!_isExpanded) {
      // Save current bubble position before expanding
      _savedBubblePosition = await FlutterOverlayWindow.getOverlayPosition();
      final initialPosition = OverlayPosition(
        10,
        _savedBubblePosition?.y ?? 300,
      );
      // Move to a safe position so the expanded panel stays on-screen
      await FlutterOverlayWindow.moveOverlay(initialPosition);
      await FlutterOverlayWindow.resizeOverlay(300, 360, false);
      setState(() {
        _isExpanded = true;
        _scrollToBottom();
      });
    } else {
      await FlutterOverlayWindow.resizeOverlay(56, 56, true);
      // Restore the original bubble position
      if (_savedBubblePosition != null) {
        await FlutterOverlayWindow.moveOverlay(_savedBubblePosition!);
      }
      setState(() => _isExpanded = false);
    }
  }

  Future<void> _openMainApp() async {
    // Cancel any active overlay executor so opening main app never leaves
    // an orphaned executor running after the overlay closes.
    if (_executor != null) {
      _executor!.cancel();
      _executor = null;
    }
    if (mounted) {
      setState(() {
        _isExpanded = false;
        _isSent = false;
        _phase = AssistantOverlayPhase.idle;
      });
    }
    await _overlayHistoryWrite;
    const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: 'com.cypherghost.agentcypher',
      componentName: 'com.cypherghost.agentcypher.MainActivity',
      flags: <int>[
        Flag.FLAG_ACTIVITY_NEW_TASK,
        Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
      ],
    );
    await intent.launch();
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (!_isExpanded) {
      return GestureDetector(
        onPanUpdate: (d) {
          // Drag to reposition (preserved overlay-window mechanism)
        },
        onTap: _toggleExpanded,
        child: Semantics(
          label: 'Agent Cypher assistant orb',
          button: true,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: AssistantOrb(phase: _phase, size: 56, audioLevel: _audioLevel),
            ),
          ),
        ),
      );
    }

    // Expanded translucent glass assistant panel — compact, upper-screen, responsive
    return OverflowBox(
      minWidth: 320,
      maxWidth: 320,
      minHeight: 380,
      maxHeight: 420,
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 60, left: 8, right: 8),
        decoration: BoxDecoration(
          color: const Color(0xDD18141E), // deep graphite translucent glass
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x66A5B4FC).withOpacity(0.35), width: 1),
          boxShadow: [
            BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.25), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with orb + status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: const Color(0x66FFFFFF).withOpacity(0.12), width: 1)),
                  ),
                  child: Row(
                    children: [
                      AssistantOrb(phase: _phase, size: 36, audioLevel: _audioLevel),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Agent Cypher', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                            Text(_phaseName(_phase), style: const TextStyle(fontSize: 10, color: Color(0xFFB4B4D8))),
                          ],
                        ),
                      ),
                      Semantics(
                        button: true, label: 'Open Agent Cypher',
                        child: GestureDetector(
                          onTap: () => unawaited(_openMainApp()),
                          child: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 18),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _toggleExpanded,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0x22FFFFFF), shape: BoxShape.circle),
                          child: const Icon(Icons.remove, color: Colors.white70, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status / progress line
                if (_phase == AssistantOverlayPhase.thinking || _phase == AssistantOverlayPhase.executing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF6366F1))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_statusText(_phase), style: const TextStyle(fontSize: 11, color: Colors.white70))),
                      ],
                    ),
                  ),
                // Messages
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => MessageBubble(message: _messages[index], compact: true),
                    ),
                  ),
                ),
                // Input area
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: const Color(0x22FFFFFF), width: 0.5)),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taskController,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Type or say a command...',
                            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFB4B4D8)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            filled: true, fillColor: const Color(0x22FFFFFF),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onSubmitted: (val) => _sendTask(val),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          if (_executor != null &&
                              (_phase == AssistantOverlayPhase.executing ||
                                  _phase == AssistantOverlayPhase.thinking)) {
                            _executor!.cancel();
                            if (mounted) {
                              setState(() {
                                _phase = AssistantOverlayPhase.idle;
                                _isSent = false;
                              });
                            }
                          }
                        },
                        child: const Icon(Icons.cancel_outlined, color: Colors.white70, size: 20),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _toggleListening,
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.redAccent : const Color(0xFF06B6D4),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _sendTask(_taskController.text),
                        child: Container(
                          width: 28, height: 28,
                          decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
