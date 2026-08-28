import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../core/theme/cypher_theme.dart';
import '../core/theme/spacing_tokens.dart';
import '../core/ui/cypher_components.dart';
import '../models/chat_message.dart';
import '../models/agent_action.dart';
import '../models/task_plan.dart';
import '../services/ai_service.dart';
import '../services/action_handler.dart';
import '../services/voice_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/cypher_composer.dart';
import '../widgets/model_selector_sheet.dart';
import '../services/chat_history_service.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';
import 'task_history_screen.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../main.dart';
import '../config/feature_flags.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiService _aiService = AiService();
  final ActionHandler _actionHandler = ActionHandler();
  final VoiceService _voiceService = VoiceService();
  final NotificationService _notificationService = NotificationService();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;

  // Custom switch state: 'chat' or 'agent'
  String _mode = 'chat';

  // Chat Session state tracking
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  String _sessionTitle = '';

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  Timer? _overlayHistoryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
    _startOverlayHistorySync();
    // Register as the handler for overlay bubble tasks
    onOverlayTask = (task) => _sendMessage(task);
  }

  Future<void> _initServices() async {
    try {
      await _aiService.init();
      await _notificationService.requestPermission();
      await _voiceService.init();
      await _actionHandler.shizuku.checkAvailability();
    } catch (error, stackTrace) {
      developer.log(
        'Optional home services failed to initialize: $error',
        name: 'AgentCypher',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveSession() async {
    if (_messages.isEmpty) return;

    // Set first user message as session title if not set
    if (_sessionTitle.isEmpty) {
      final firstUserMsg = _messages.firstWhere(
        (m) => m.isUser,
        orElse: () => ChatMessage(role: 'user', content: 'New Chat'),
      );
      _sessionTitle = firstUserMsg.content.length > 28
          ? '${firstUserMsg.content.substring(0, 25)}...'
          : firstUserMsg.content;
    }

    final session = ChatSession(
      id: _sessionId,
      title: _sessionTitle,
      timestamp: DateTime.now(),
      messages: _messages.map((m) => m.toJson()).toList(),
    );

    await ChatHistoryService.saveSession(session);
  }

  Future<void> _sendMessage(String text) async {
    if (!mounted || text.trim().isEmpty) return;

    final userMessage = ChatMessage(role: 'user', content: text.trim());
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _updateOverlayState();
    _textController.clear();
    _scrollToBottom();
    try {
      await _saveSession();
    } catch (error, stackTrace) {
      developer.log(
        'Could not save chat session before request: $error',
        name: 'AgentCypher',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;

    if (_aiService.isImageGenerationRequest(text.trim())) {
      try {
        final generated = await _aiService.generateImage(text.trim());
        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: generated.revisedPrompt == null
                ? 'Generated image.'
                : 'Generated image.\n\n_${generated.revisedPrompt}_',
            imageUrl: generated.imageUrl,
          ));
        });
        await _saveSession();
      } catch (error) {
        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(
              role: 'assistant',
              content: 'Image generation unavailable: ${error.toString().replaceFirst('Exception: ', '')}',
            ));
          });
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
          _scrollToBottom();
          unawaited(_updateOverlayState().catchError((error) {
            developer.log('Overlay state update failed: $error', name: 'AgentCypher');
          }));
        }
      }
      return;
    }

    // Agent-mode imperatives go directly to the existing TaskExecutor. This
    // avoids spending one model call on an intent JSON response before the
    // real screen-observation loop starts.
    if (_mode == 'agent' && _looksLikeAgentTask(text.trim())) {
      await _runAgentTask(text.trim());
      return;
    }

    // Add empty placeholder assistant message for streaming
    final assistantMessage = ChatMessage(role: 'assistant', content: '');
    setState(() {
      _messages.add(assistantMessage);
    });
    final assistantIndex = _messages.length - 1;

    try {
      final isAgent = _mode == 'agent';
      final stream = _aiService
          .sendMessageStream(text.trim(), isAgentMode: isAgent)
          .timeout(
            const Duration(seconds: 90),
            onTimeout: (sink) {
              sink.addError(
                TimeoutException(
                  'The model did not return visible text within 90 seconds.',
                ),
              );
              sink.close();
            },
          );
      String accumulated = '';

      await for (final chunk in stream) {
        accumulated += chunk;
        if (mounted) {
          setState(() {
            _messages[assistantIndex] = ChatMessage(
              role: 'assistant',
              content: accumulated,
            );
          });
          _scrollToBottom();
        }
      }
      await _saveSession();

      if (!mounted) return;

      // Check if it's an action
      final action = _aiService.parseAction(accumulated);

      if (action != null) {
        // If it's an action, we remove the raw JSON message from display
        setState(() {
          _messages.removeAt(assistantIndex);
        });

        await _showTaskProgressOverlay('Starting: ${text.trim()}');

        // Execute the action (pass aiService for multi-step tasks)
        final result = await _actionHandler.execute(
          action,
          aiService: _aiService,
          onProgress: (msg) {
            developer.log('Task progress: $msg', name: 'AgentCypher');
            _sendOverlayEvent('OVERLAY_PROGRESS', msg);
            if (mounted) {
              setState(() {
                _messages.add(
                  ChatMessage(role: 'assistant', content: '⏳ $msg'),
                );
              });
              _scrollToBottom();
            }
          },
        );

        setState(() {
          _messages.add(
            ChatMessage(
              role: 'assistant',
              content: result.success
                  ? (action.response.isNotEmpty
                        ? action.response
                        : (result.details ?? 'Done.'))
                  : (action.response.isNotEmpty
                        ? '${action.response}\n\n⚠️ ${result.details}'
                        : '⚠️ ${result.details}'),
              actionResult: result,
            ),
          );
        });
        _sendOverlayEvent(
          'OVERLAY_TASK_FINISHED',
          result.success
              ? (result.details ?? 'Task complete.')
              : 'Task failed: ${result.details ?? 'Unknown error'}',
        );
        if (action.action != 'execute_task') {
          await _notificationService.showTaskCompleteNotification(
            result.success ? 'Task Completed' : 'Task Failed',
            result.details ??
                (result.success
                    ? 'Agent finished its goal.'
                    : 'Agent could not complete the task.'),
          );
        }
        await _saveSession();
      } else {
        // Plain text response, we already rendered it, just speak it
        _voiceService.speak(accumulated);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && _messages.length > assistantIndex) {
            _messages.removeAt(assistantIndex);
          }
          _messages.add(
            ChatMessage(
              role: 'assistant',
              content: 'Error: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
        unawaited(
          _updateOverlayState().catchError((error) {
            developer.log(
              'Overlay state update failed: $error',
              name: 'AgentCypher',
            );
          }),
        );
      }
    }
  }

  bool _looksLikeAgentTask(String text) {
    final normalized = text.toLowerCase().trim();
    const taskMarkers = <String>[
      'open ',
      'go to ',
      'search ',
      'find ',
      'send ',
      'message ',
      'whatsapp',
      'telegram',
      'play ',
      'subscribe',
      'download',
      'install ',
      'turn on ',
      'turn off ',
      'set ',
      'launch ',
      'navigate ',
      'click ',
    ];
    return taskMarkers.any(normalized.contains);
  }

  bool _requiresTaskConfirmation(String goal) {
    final normalized = goal.toLowerCase();
    const sensitiveMarkers = <String>[
      'send ',
      'message ',
      'whatsapp',
      'sms',
      'call ',
      'email ',
      'subscribe',
      'download',
      'install ',
      'delete ',
      'purchase',
    ];
    return sensitiveMarkers.any(normalized.contains);
  }

  /// Plan preview for complex or sensitive tasks: shows every typed step
  /// with its verification method before anything touches the device.
  Future<bool> _showPlanPreview(TaskPlan plan) async {
    if (!mounted) return false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review plan'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: plan.steps.length,
            itemBuilder: (context, index) {
              final step = plan.steps[index];
              final flag = step.requiresConfirmation ? ' ⚠️' : '';
              return ListTile(
                dense: true,
                leading: Text('${index + 1}.'),
                title: Text('${step.intent}$flag'),
                subtitle: Text(
                  '${step.action}'
                  '${step.expectedResult.isEmpty ? '' : ' → ${step.expectedResult}'}',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Run plan'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<bool> _confirmAgentTask(String goal) async {
    if (!mounted || !_requiresTaskConfirmation(goal)) return true;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm agent task'),
        content: Text('Allow Agent Cypher to perform this action?\n\n$goal'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<void> _runAgentTask(String goal) async {
    try {
      if (!await _confirmAgentTask(goal)) {
        if (mounted) {
          setState(() {
            _messages.add(
              const ChatMessage(
                role: 'assistant',
                content: 'Task cancelled before any action was performed.',
              ),
            );
          });
        }
        return;
      }
      await _showTaskProgressOverlay('Starting: $goal');
      final result = await _actionHandler.execute(
        AgentAction(
          action: 'execute_task',
          params: {'goal': goal},
          response: '',
        ),
        aiService: _aiService,
        onProgress: (message) {
          developer.log('Task progress: $message', name: 'AgentCypher');
          _sendOverlayEvent('OVERLAY_PROGRESS', message);
          if (mounted) {
            setState(() {
              _messages.add(
                ChatMessage(role: 'assistant', content: '⏳ $message'),
              );
            });
            _scrollToBottom();
          }
        },
        onPlanPreview: (plan) => _showPlanPreview(plan),
        onBeforePlanStep: (step) async {
          // Sensitive steps get an explicit confirmation immediately before
          // they run; ordinary steps proceed automatically.
          if (!step.requiresConfirmation) return true;
          if (!mounted) return false;
          final approved = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Confirm sensitive step'),
              content: Text(
                '${step.intent}\n\nAction: ${step.action}'
                '${step.targetDescription.isEmpty ? '' : '\nTarget: ${step.targetDescription}'}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Allow'),
                ),
              ],
            ),
          );
          return approved == true;
        },
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content: result.success
                ? (result.details ?? 'Task completed.')
                : '⚠️ ${result.details ?? 'Task failed.'}',
            actionResult: result,
          ),
        );
      });
      _sendOverlayEvent(
        'OVERLAY_TASK_FINISHED',
        result.success
            ? (result.details ?? 'Task complete.')
            : 'Task failed: ${result.details ?? 'Unknown error'}',
      );
      await _saveSession();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content: '⚠️ Task failed: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
        unawaited(_updateOverlayState().catchError((error) {
          developer.log('Overlay state update failed: $error', name: 'AgentCypher');
        }));
      }
    }
  }

  Future<void> _showTaskProgressOverlay(String message) async {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    if (!await FlutterOverlayWindow.isPermissionGranted()) return;

    // Never cover Agent Cypher itself. The lifecycle observer will create the
    // overlay after an automated action moves this app to the background.
    if (_appLifecycleState != AppLifecycleState.paused) return;

    if (!await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'Agent Cypher',
        overlayContent: 'Performing task...',
        flag: OverlayFlag.focusPointer,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.auto,
        startPosition: const OverlayPosition(0, 200),
        width: 56,
        height: 56,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    // Keep the overlay minimized during automation. The user can still tap the
    // bubble to open the full conversation whenever they choose.
    _sendOverlayEvent('OVERLAY_TASK_STARTED', message);
  }

  void _sendOverlayEvent(String type, String message) {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    final safeMessage = message.replaceAll('|', ' ');
    unawaited(
      FlutterOverlayWindow.shareData(
        '$type|$safeMessage',
      ).timeout(const Duration(seconds: 2)).catchError((Object _) {}),
    );
  }

  Future<void> _sendOverlayHistorySnapshot() async {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    final history = base64Encode(
      utf8.encode(
        jsonEncode(_messages.map((message) => message.toJson()).toList()),
      ),
    );
    try {
      await FlutterOverlayWindow.shareData(
        'OVERLAY_HISTORY|$history',
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (!mounted) return;
    if (_isListening) {
      try {
        await _voiceService.stopListening();
      } catch (error) {
        developer.log('Voice stop failed: $error', name: 'AgentCypher');
      }
      if (mounted) setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);

    try {
      await _voiceService.startListening(
        onResult: (text) {
          if (mounted) unawaited(_sendMessage(text));
        },
        onDone: () {
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (error) {
      developer.log('Voice start failed: $error', name: 'AgentCypher');
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _startNewChat() {
    setState(() {
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionTitle = '';
      _messages.clear();
      _aiService.clearHistory();
    });
  }

  void _loadChatSession(ChatSession session) {
    setState(() {
      _sessionId = session.id;
      _sessionTitle = session.title;
      _messages.clear();
      for (final m in session.messages) {
        _messages.add(ChatMessage.fromJson(m));
      }

      _aiService.clearHistory();
      for (final m in _messages) {
        if (m.actionResult != null) continue;
        _aiService.addHistoryMessage(m.role, m.content);
      }
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayHistoryTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      _appLifecycleState = state;
    });
    if (state == AppLifecycleState.resumed) {
      _startOverlayHistorySync();
      unawaited(_handleAppForegrounded());
    } else {
      _overlayHistoryTimer?.cancel();
      _updateOverlayState();
    }
  }

  void _startOverlayHistorySync() {
    _overlayHistoryTimer?.cancel();
    if (!FeatureFlags.floatingOverlayEnabled) return;
    unawaited(_importOverlayChatHistory());
    _overlayHistoryTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) {
      if (_appLifecycleState == AppLifecycleState.resumed) {
        unawaited(_importOverlayChatHistory());
      }
    });
  }

  Future<void> _handleAppForegrounded() async {
    await _updateOverlayState();
    await _importOverlayChatHistory();
  }

  Future<void> _importOverlayChatHistory() async {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    if (_importingOverlayHistory) return;
    _importingOverlayHistory = true;
    try {
      final handoff = await ChatHistoryService.consumeOverlayMessages();
      if (!mounted || handoff.isEmpty) return;

      final imported = handoff.map(ChatMessage.fromJson).toList();
      for (final message in imported) {
        if (message.actionResult == null) {
          _aiService.addHistoryMessage(message.role, message.content);
        }
      }
      setState(() {
        _messages.addAll(imported);
      });
      _scrollToBottom();
      await _saveSession();
    } finally {
      _importingOverlayHistory = false;
    }
  }

  int _overlayUpdateGeneration = 0;
  bool _importingOverlayHistory = false;

  Future<void> _updateOverlayState() async {
    if (!FeatureFlags.floatingOverlayEnabled) return;
    final generation = ++_overlayUpdateGeneration;
    final isBackground = _appLifecycleState == AppLifecycleState.paused;
    final shouldBeActive = isBackground;

    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted || generation != _overlayUpdateGeneration) return;

      final active = await FlutterOverlayWindow.isActive();
      if (generation != _overlayUpdateGeneration) return;
      if (shouldBeActive && !active) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (generation != _overlayUpdateGeneration) return;
        if (_appLifecycleState != AppLifecycleState.paused) return;
        if (await FlutterOverlayWindow.isActive()) return;
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: 'Agent Cypher',
          overlayContent: _isLoading
              ? 'Performing task...'
              : 'Floating Assistant',
          flag: OverlayFlag.focusPointer,
          alignment: OverlayAlignment.centerRight,
          visibility: NotificationVisibility.visibilitySecret,
          positionGravity: PositionGravity.auto,
          startPosition: const OverlayPosition(0, 200),
          width: 56,
          height: 56,
        );
        if (_isLoading && _appLifecycleState == AppLifecycleState.paused) {
          // Give the overlay isolate time to attach its listener, then send the
          // full active conversation. A second snapshot makes cold starts
          // reliable without duplicating messages because the overlay replaces
          // its list atomically.
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await _sendOverlayHistorySnapshot();
          await Future<void>.delayed(const Duration(milliseconds: 250));
          if (_isLoading && _appLifecycleState == AppLifecycleState.paused) {
            await _sendOverlayHistorySnapshot();
          }
        }
      } else if (shouldBeActive && active && _isLoading) {
        await _sendOverlayHistorySnapshot();
      } else if (!shouldBeActive && active) {
        try {
          await FlutterOverlayWindow.shareData(
            'OVERLAY_RESET|',
          ).timeout(const Duration(milliseconds: 150));
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (generation != _overlayUpdateGeneration) return;
        if (_appLifecycleState == AppLifecycleState.paused) return;
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (error, stackTrace) {
      developer.log(
        'Overlay state synchronization failed: $error',
        name: 'AgentCypher',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cypher;
    // Retained for the drawer and empty-state helpers, which still accept it.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Transparent: the token gradient background shows through.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            text: 'Cypher',
            style: c.typography.titleLarge.copyWith(
              color: c.colors.accent,
              fontWeight: FontWeight.w800,
            ),
            children: [
              TextSpan(
                text: ' Agent',
                style: c.typography.titleLarge.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Model',
            onPressed: () => ModelSelectorSheet.show(
              context,
              aiService: _aiService,
              onOpenSettings: () => _openSettings(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: _isLoading ? null : _startNewChat,
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      drawer: _buildDrawer(context, isDark),
      body: CypherBackground(
        child: Column(
            children: [
              // Pill selector switcher
              _buildModeSelector(isDark),

              // API key warning banner
              if (!_aiService.isConfigured)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CypherSpacing.space6,
                    vertical: CypherSpacing.space2,
                  ),
                  child: CypherCard(
                    color: context.cypher.colors.warning.withOpacity(0.10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: CypherSpacing.space4,
                      vertical: CypherSpacing.space3,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: context.cypher.colors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: CypherSpacing.space3),
                        Expanded(
                          child: Text(
                            'API not configured. Open Settings to add provider details.',
                            style: context.cypher.typography.labelMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _openSettings,
                          child: const Text('Configure'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Chat content area
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: CypherSpacing.space4,
                          vertical: CypherSpacing.space2,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return MessageBubble(message: _messages[index]);
                        },
                      ),
              ),

              // Generation indicator with stop affordance
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CypherSpacing.space8,
                    vertical: CypherSpacing.space2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.cypher.colors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: CypherSpacing.space3),
                      Text(
                        'Thinking…',
                        style: context.cypher.typography.chatMeta,
                      ),
                      const SizedBox(width: CypherSpacing.space2),
                      TextButton.icon(
                        onPressed: _handleStopRequested,
                        icon: Icon(
                          Icons.stop_circle_rounded,
                          size: 16,
                          color: context.cypher.colors.error,
                        ),
                        label: Text(
                          'Stop',
                          style: context.cypher.typography.labelMedium
                              .copyWith(
                            color: context.cypher.colors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),

              // Composer
              CypherComposer(
                controller: _textController,
                isLoading: _isLoading,
                isListening: _isListening,
                onSend: _sendMessage,
                onStop: _handleStopRequested,
                onToggleVoice: _toggleVoice,
              ),
            ],
        ),
      ),
    );
  }

  void _handleStopRequested() {
    _actionHandler.cancelTask();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          aiService: _aiService,
          shizukuService: _actionHandler.shizuku,
          screenAutomationService: _actionHandler.screenAutomation,
        ),
      ),
    );
    await _actionHandler.shizuku.checkAvailability();
    if (mounted) setState(() {});
  }

  Widget _buildDrawer(BuildContext context, bool isDark) {
    final c = context.cypher;
    final textStyle = c.typography.labelMedium.copyWith(
      fontWeight: FontWeight.w600,
    );
    final headerStyle = c.typography.titleLarge.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
    );

    return Drawer(
      backgroundColor: c.colors.surface,
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 20,
              left: 24,
              right: 24,
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/app-logo.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Agent Cypher', style: headerStyle),
              ],
            ),
          ),

          // New Chat Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _startNewChat();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_comment_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'New Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Divider(indent: 16, endIndent: 16, height: 20),

          // Section CHAT HISTORY
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CHAT HISTORY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          // Chat Sessions List
          Expanded(
            child: FutureBuilder<List<ChatSession>>(
              future: ChatHistoryService.loadSessions(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No recent chats',
                      style: TextStyle(
                        color: isDark ? Colors.grey[800] : Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  );
                }

                final sessions = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isCurrent = session.id == _sessionId;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrent
                            ? Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.15),
                              )
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        dense: true,
                        leading: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 15,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : (isDark ? Colors.grey[600] : Colors.grey[500]),
                        ),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle.copyWith(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isCurrent
                                ? context.cypher.colors.textPrimary
                                : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Colors.redAccent.withOpacity(0.7),
                          ),
                          onPressed: () async {
                            await ChatHistoryService.deleteSession(session.id);
                            if (isCurrent) {
                              _startNewChat();
                            }
                            (context as Element)
                                .markNeedsBuild(); // Re-trigger build refresh
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _loadChatSession(session);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(indent: 16, endIndent: 16, height: 20),

          // Section TASKS & SETTINGS
          ListTile(
            horizontalTitleGap: 8,
            leading: Icon(
              Icons.history_rounded,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 20,
            ),
            title: Text('Task History', style: textStyle),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskHistoryScreen()),
              );
            },
          ),
          ListTile(
            horizontalTitleGap: 8,
            leading: Icon(
              Icons.settings_rounded,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 20,
            ),
            title: Text('Settings', style: textStyle),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    aiService: _aiService,
                    shizukuService: _actionHandler.shizuku,
                    screenAutomationService: _actionHandler.screenAutomation,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildModeSelector(bool isDark) {
    final c = context.cypher;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: CypherSpacing.space3),
        padding: const EdgeInsets.all(CypherSpacing.space1),
        decoration: BoxDecoration(
          color: c.colors.surfaceContainer,
          borderRadius: BorderRadius.circular(CypherSpacing.radiusFull),
          border: Border.all(color: c.colors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeButton(
              'chat',
              'Chat',
              Icons.chat_bubble_outline_rounded,
              isDark,
            ),
            _buildModeButton(
              'agent',
              'Agent',
              Icons.smart_toy_outlined,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    String modeId,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final c = context.cypher;
    final isSelected = _mode == modeId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _mode = modeId;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: CypherSpacing.space6,
          vertical: CypherSpacing.space2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CypherSpacing.radiusFull),
          color: isSelected ? c.colors.accent : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? c.colors.textOnAccent : c.colors.textTertiary,
            ),
            const SizedBox(width: CypherSpacing.space2),
            Text(
              label,
              style: c.typography.labelMedium.copyWith(
                color:
                    isSelected ? c.colors.textOnAccent : c.colors.textTertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final c = context.cypher;
    final time = DateTime.now();
    String timeGreeting = 'Hello';
    if (time.hour >= 5 && time.hour < 12) {
      timeGreeting = 'Hello, good morning.';
    } else if (time.hour >= 12 && time.hour < 17) {
      timeGreeting = 'Hello, good afternoon.';
    } else if (time.hour >= 17 && time.hour < 22) {
      timeGreeting = 'Hello, good evening.';
    } else {
      timeGreeting = 'Hello.';
    }

    final suggestions = _mode == 'chat'
        ? [
            'Write a professional email',
            'Explain quantum computing simply',
            'Brainstorm mobile app ideas',
            'Write a poem about robots',
          ]
        : [
            'Open YouTube and search for cats',
            'Call Mom',
            'Set volume to 80%',
            'What\'s on my screen?',
          ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CypherSpacing.space8,
          vertical: CypherSpacing.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: CypherSpacing.space6),
            Text(
              timeGreeting,
              style: c.typography.displayLarge.copyWith(
                color: c.colors.textSecondary,
                fontWeight: FontWeight.w300,
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: CypherSpacing.space1),
            Text(
              'How can I help you?',
              style: c.typography.displayLarge.copyWith(
                color: c.colors.accent,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: CypherSpacing.space16),
            Text(
              'SUGGESTIONS',
              style: c.typography.labelSmall.copyWith(
                color: c.colors.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: CypherSpacing.space4),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: suggestions.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: CypherSpacing.space2),
                itemBuilder: (context, index) {
                  return Center(
                    child: CypherChip(
                      label: suggestions[index],
                      onTap: () => _sendMessage(suggestions[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
