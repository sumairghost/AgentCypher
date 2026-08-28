---
description: Improve Agent Cypher task speed while preserving verification, confidence checks, user consent, cancellation, and honest error reporting.
---

# Execution Performance

First measure where time is spent: request intake, planning, provider/model latency, accessibility observation, app launch, action execution, verification, recovery, and total task time.

Prefer:

- deterministic fast paths where correctness is established;
- targeted accessibility queries instead of repeated full-screen dumps;
- reuse of recent state that is still valid;
- compact typed model prompts and fewer model calls;
- condition-based waits instead of long fixed sleeps;
- bounded native channel calls;
- safe parallel work only when steps are independent and side-effect-free;
- caching stable app/package/navigation facts with explicit invalidation.

Avoid:

- blind coordinate actions when semantic targets are available;
- unbounded waits or retries;
- repeated screenshots or dumps without a state-change reason;
- duplicate model planning for the same stable state;
- skipping verification merely to reduce latency.

Add or use latency metrics for planning, model calls, observation, action, verification, recovery, and total task time. State expected benefit, risk, benchmark method, and whether device testing is still needed.