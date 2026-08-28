---
description: Run or design Agent Cypher Android regression tests for task execution, permissions, background behavior, overlays, accessibility, voice, provider failures, and recovery.
---

# Device Regression

Test or plan tests for:

- app foreground/background/killed;
- screen locked/unlocked;
- microphone permission granted, denied, revoked;
- notification permission granted/denied;
- overlay permission granted/denied;
- accessibility service enabled/disabled;
- correct/wrong foreground app context;
- target found/not found;
- online/offline/provider error/rate limit;
- cancellation and partial completion;
- unchanged/stale screen and recovery;
- emulator and real device where possible.

Use exact commands and evidence. Distinguish static review, analyzer validation, unit tests, build validation, emulator tests, and real-device tests. Never claim runtime success without runtime evidence.