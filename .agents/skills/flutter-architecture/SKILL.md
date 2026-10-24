---
name: flutter-architecture
description: Flutter app architecture for the VYRO Flutter project
---

# Flutter app architecture

Use modular features, clean repository boundaries, Riverpod providers and go_router; keep buildable checkpoints. Avoid long widget files. Test navigation and local CRUD.

## Workflow
1. Read `AGENTS.md`, `docs/PRODUCT_SPEC.md` and related brand docs.
2. Draft the smallest testable change; prefer real behavior to placeholders.
3. Implement and add tests for failures, permissions and offline cases.
4. Run checks where available and report honest results.
