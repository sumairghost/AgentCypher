---
description: Apply the Agent Cypher voice, speech, audio focus, foreground-service, and recovery checklist before editing voice-related code.
---

# Voice Runtime

Treat voice as a state machine: idle, waiting, wake detected, recording, processing, speaking, cancelled, permission denied, service stopped, and recovery.

Before changing voice code, check microphone permission, audio focus, foreground-service requirements, notification behavior, Bluetooth/headsets, locked screen, background behavior, process death, battery impact, cancellation, network failure, model failure, and diagnostic logging.

Wake-word work is deferred unless explicitly requested. Do not silently repair or remove it during unrelated work. Never claim background voice behavior is working without emulator or real-device evidence.