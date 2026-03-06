# Story E1-S1 — Project Directory Structure

**Epic:** E1 — Project Scaffold & Configuration Surface
**Status:** Done

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

### Task 1.1.1 — Create directory skeleton
- [x] Create `scripts/` directory
- [x] Create `scripts/lib/` directory
- [x] Create `k8s/app/landing/` directory
- [x] Create `k8s/app/api/` directory
- [x] Create `k8s/addons/` directory
- [x] Create `k8s/presets/` directory
- [x] Create `docs/` directory
- [x] Create `artifacts/` directory
- [x] Create `.state/` directory
- [x] Add `.gitkeep` files to track empty directories in git

### Task 1.1.2 — Add `.gitignore` entries
- [x] Add `artifacts/` to `.gitignore`
- [x] Add `.state/` to `.gitignore`
- [x] Add `*.log` to `.gitignore`

### Task 1.1.3 — Create `README.md`
- [x] Write project overview section
- [x] Write prerequisites table (docker, kind, kubectl, node, bash, curl)
- [x] Write quick start commands section
- [x] Write configuration variables section
- [x] Write project layout directory tree
- [x] Write gate pipeline summary
- [x] Write recovery section
- [x] Write profiles table
