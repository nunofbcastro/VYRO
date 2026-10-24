---
name: quality
description: Privacy and QA for the VYRO Flutter project
---

# Privacy and QA

Local-first by default, explicit camera permissions, no uploading photos, no silent video saves. Format/analyze/test each phase and disclose mocks or skipped checks. Validate reduced-motion and accessibility.

## Workflow
1. Read `AGENTS.md`, `docs/PRODUCT_SPEC.md` and related brand docs.
2. Draft the smallest testable change; prefer real behavior to placeholders.
3. Implement and add tests for failures, permissions and offline cases.
4. Run checks where available and report honest results.
