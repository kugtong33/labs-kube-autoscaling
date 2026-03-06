# Story E1-S1 — Project Directory Structure

**Epic:** E1 — Project Scaffold & Configuration Surface
**Status:** Pending

---

## User Story

**As a** contributor,
**I want** a standard, documented project layout,
**so that** every script, manifest, and artifact has a predictable location.

---

## Acceptance Criteria

- `scripts/`, `scripts/lib/`, `k8s/`, `k8s/addons/`, `k8s/presets/`, `k8s/app/landing/`, `k8s/app/api/`, `docs/`, `artifacts/`, `.state/` directories exist or are created on first run
- `README.md` documents top-level layout
- `.gitignore` excludes `artifacts/` and `.state/`

---

## Tasks

| ID | Task | Status |
|---|---|---|
| 1.1.1 | Create directory skeleton: `scripts/lib/`, `k8s/app/landing/`, `k8s/app/api/`, `k8s/addons/`, `k8s/presets/`, `docs/` | Pending |
| 1.1.2 | Add `.gitignore` entries for `artifacts/`, `.state/`, `*.log` | Pending |
| 1.1.3 | Create `README.md` with project overview, prerequisites, and top-level command reference | Pending |
