---
description: Review Agent Cypher Android security, privacy, API credentials, permissions, exposed components, sensitive logs, and network behavior before or after relevant changes.
---

# Android Security and Privacy

Check for API keys, tokens, headers, keystores, signing secrets, exported activities/services/providers/receivers, intent validation, deep links, WebViews, local servers, network binding, TLS/network security configuration, QUERY_ALL_PACKAGES, clipboard access, backups, debug flags, sensitive logs, accessibility risks, and screen data sent to external models.

Never print secret values or commit them. Do not weaken security or permissions to make tests pass. Provide severity-ranked findings and the smallest safe remediation.