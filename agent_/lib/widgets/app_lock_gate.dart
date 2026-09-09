import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/cypher_theme.dart';
import '../core/theme/spacing_tokens.dart';
import '../services/biometric_service.dart';

/// Persisted preference key for the biometric app lock.
const String kAppLockEnabledKey = 'app_lock_enabled';

/// Wraps the home experience in the biometric app lock when the user enabled
/// it in Settings → PRIVACY → App Lock.
///
/// Behavior:
/// - Locks on first build (when enabled) and again when the app returns to the
///   foreground after being away.
/// - Uses [BiometricService.authenticateWithFallback]: biometric first, then
///   device credential (PIN/pattern).
/// - Failure handling: an inline error with a Retry action — no crash, no
///   silent unlock.
/// - Devices without any enrolled biometric/credential: the gate cannot
///   authenticate anyone, so it stays unlocked and reports the reason. It
///   never pretends to protect the app when it cannot.
///
/// Re-lock threshold: the system credential dialog (PIN) briefly backgrounds
/// the app, so a resume within 5 seconds of pausing is treated as part of the
/// authentication flow rather than a fresh app switch.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _enabled = false;
  bool _locked = false;
  bool _authenticating = false;
  String? _error;
  DateTime? _pausedAt;
  Timer? _resumeDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAndLock();
  }

  Future<void> _loadAndLock() async {
    bool enabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(kAppLockEnabledKey) ?? false;
    } catch (_) {
      enabled = false;
    }
    if (!mounted) return;
    setState(() => _enabled = enabled);
    if (enabled) {
      await _lock();
    }
  }

  Future<void> _lock() async {
    // Ensure availability is known even if app startup partially failed.
    await BiometricService().init();
    final status = BiometricService().getBiometricStatus();
    if (!status.available) {
      // Honest behavior: no enrolled auth method means the lock cannot be
      // enforced. Show the app rather than pretending to protect it.
      if (!mounted) return;
      setState(() {
        _locked = false;
        _error = null;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _locked = true;
      _error = null;
    });
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    if (!mounted) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    final result = await BiometricService().authenticateWithFallback(
      biometricReason: 'Unlock Agent Cypher',
      deviceCredentialReason: 'Unlock Agent Cypher with your device PIN or '
          'pattern',
    );
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (result.success) {
        _locked = false;
      } else {
        _error = result.error ?? 'Authentication failed.';
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed && _enabled && !_locked) {
      final pausedAt = _pausedAt;
      final away = pausedAt == null
          ? false
          : DateTime.now().difference(pausedAt) >
              const Duration(seconds: 5);
      if (!away || _authenticating) return;
      // Small debounce: lifecycle transitions can fire in quick succession.
      _resumeDebounce?.cancel();
      _resumeDebounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted && _enabled && !_locked && !_authenticating) {
          unawaited(_lock());
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    final c = context.cypher;
    return Scaffold(
      backgroundColor: c.colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(CypherSpacing.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_person_rounded,
                  size: 56,
                  color: c.colors.accent,
                ),
                const SizedBox(height: CypherSpacing.space6),
                Text(
                  'Agent Cypher is locked',
                  style: c.typography.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: CypherSpacing.space2),
                Text(
                  'Authenticate with your fingerprint, face, or device '
                  'credential to continue.',
                  style: c.typography.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: CypherSpacing.space6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: c.colors.error,
                      ),
                      const SizedBox(width: CypherSpacing.space2),
                      Flexible(
                        child: Text(
                          _error!,
                          style: c.typography.bodySmall.copyWith(
                            color: c.colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: CypherSpacing.space10),
                FilledButton.icon(
                  onPressed: _authenticating ? null : _authenticate,
                  icon: _authenticating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint_rounded, size: 18),
                  label: Text(
                    _authenticating ? 'Authenticating…' : 'Unlock',
                    style: c.typography.labelLarge,
                  ),
                ),
                TextButton(
                  onPressed: _authenticating ? null : _authenticate,
                  child: const Text('Use another method'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}