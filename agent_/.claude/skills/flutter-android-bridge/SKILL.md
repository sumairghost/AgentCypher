---
description: Trace Flutter-to-Android integrations before changing platform channels, Kotlin services, manifests, permissions, lifecycle, 
---

# Flutter–Android Bridge

Before editing a platform-dependent feature:

1. Locate the Dart caller.
2. Locate the MethodChannel/EventChannel name and payload schema.
3. Locate the Kotlin implementation and Android component/service.
4. Check AndroidManifest.xml declarations, exported flags, and permissions.
5. Check foreground, background, killed, locked-screen, reboot, and permission-denied behavior.
6. Trace native success and failure into Dart results.
7. Locate relevant tests and identify missing coverage.

Do not replace native Android behavior with Dart mocks when real service, overlay, accessibility, notification, media, or system-setting behavior is required. Report source evidence. Do not claim compilation or device success without direct validation.