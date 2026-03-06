# Story E10-S2 — Configuration & Troubleshooting Docs

**Epic:** E10 — Documentation & Learner Experience
**Status:** Pending

---

## User Story

**As an** intermediate user (Audience B),
**I want** a full configuration reference and troubleshooting cards for each HPA failure code,
**so that** I can tune profiles and recover independently.

---

## Acceptance Criteria

- `docs/configuration.md`: all env vars, profiles, modes, defaults, memory requirements
- `docs/troubleshooting.md`: one card per HPA-301..306 with Symptom / Check / Fix / Retry fields (mirrors `print_failure_hint`)
- Both docs kept in sync with script behavior (single source of truth is script; docs mirror it)

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 10.2.1 | Write `docs/configuration.md`: all env vars with defaults, allowed values, profile table | Pending |
| 10.2.2 | Write `docs/troubleshooting.md`: 6 failure code cards matching `print_failure_hint` output format | Pending |
| 10.2.3 | Add profile-specific expectations section: what to expect per profile during proof | Pending |
| 10.2.4 | Add `docs/artifact-reference.md`: annotated artifact tree with field descriptions | Pending |
