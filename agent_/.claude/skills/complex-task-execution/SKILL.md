---
description: Design or review Agent Cypher's complex multi-step task plans, typed actions, dependencies, verification, recovery, cancellation, and partial-completion reporting.
---

# Complex Task Execution

Treat a complex user request as a typed ordered task plan, not a loose sequence of model text.

Every planned step must define:

- stable ID;
- user-visible intent;
- action type;
- target/app/package context;
- preconditions and dependencies;
- expected_result;
- verification method;
- retry policy and timeout;
- reversible/irreversible classification;
- confirmation requirement;
- state: pending, running, verified, failed, skipped, blocked, or cancelled.

Before every step, observe the current state and verify context. After every mutating action, re-observe and machine-check the expected result. A non-throwing method call is not proof of success.

Use bounded condition waits, bounded retries, cancellation checks, safe idempotent retry rules, unchanged-screen/stall detection, wrong-app recovery, and honest unsupported-capability reporting.

For actions with external consequences—sending a message, purchase, posting, deleting, account changes—require confirmation immediately before the action. Never repeat an irreversible action after a partial failure without explicit user approval.
