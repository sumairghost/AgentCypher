---
description: Prepare Agent Cypher for a safe Android release by checking build configuration, signing, permissions, secrets, shrinker rules, artifact output, and release validation.
---

# Release Engineering

Before a release, verify versioning, Flutter analysis, tests, debug/release separation, Android permissions, exported components, ProGuard/R8 rules, network security, signing configuration, keystore handling, secret exclusion, APK/AAB output, and release-device validation.

Never commit keystores, signing passwords, provider keys, or authorization data. Do not claim a release is ready until the release artifact has been built and tested.