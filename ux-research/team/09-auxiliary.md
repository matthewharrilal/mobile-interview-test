# 09-auxiliary — auxiliary tasks expansion

This file complements `00-build-brief.md` (mission, animation params, hard rules) and `12-continuous-audit.json` (continuous audit spec). It documents the **operational mechanics** of the audit infrastructure: how audit tasks get spawned, how remediation flows, how the audit log is maintained.

## Table of contents

1. [Audit dispatch protocol](#1-audit-dispatch-protocol)
2. [Per-dimension auditor agent template](#2-per-dimension-auditor-agent-template)
3. [Remediation task template](#3-remediation-task-template)
4. [Audit log file](#4-audit-log-file)
5. [Auxiliary task list](#5-auxiliary-task-list)
6. [Tool-installation prerequisites](#6-tool-installation-prerequisites)

---

## 1. Audit dispatch protocol

### When the team-lead dispatches auditors

The trigger is **a worker marking a feature task as `completed` via TaskUpdate**. The team-lead receives an idle/completion notification, then:

1. Reads the worker's commit (`git show <sha>` or `git diff <prev>..<sha>`).
2. Identifies the **target path** of the worker's slice (the directory the worker most heavily modified — typically `Sources/Features/<Feature>/` or `Sources/Features/HotelDetail/`).
3. Spawns **four auditor agents in parallel**, one per dimension:
   - `auditor-D1-{worker-name}` — code hygiene
   - `auditor-D2-{worker-name}` — architecture & abstraction
   - `auditor-D3-{worker-name}` — senior judgment & tech debt
   - `auditor-D4-{worker-name}` — system-as-a-whole
4. Each auditor agent receives the **per-dimension auditor template prompt** (next section), specialised to its dimension and the worker's target.
5. Auditors file findings as new `Remediate D{n}: …` tasks (with `addBlocks: [<original feature task id>]` so the feature task cannot be fully accepted until remediations resolve).
6. Auditors append a one-line summary entry to `ux-research/team/audit-log.md`.

### What constitutes "completion" for audit purposes

- Worker has set task `status: completed`
- Worker has pushed at least one commit on `main` referencing the feature
- Worker has run `scripts/audit.sh all <target>` themselves (per the inline DoD) and either: (a) zero failures, or (b) failures filed as Remediate-D{n} tasks pre-emptively

If a worker marks completed without satisfying the inline DoD, the team-lead reverts task status to `in_progress` via TaskUpdate and SendMessages the worker explaining what is missing. No exceptions.

### Cadence enforcement

Per the cadence directive (**after every feature / sub-criterion complete**):

- Architect commit → audit fires
- Worker A commit → audit fires
- Worker B commit → audit fires
- Worker C commit → audit fires
- Polish commit → final audit fires (D4-dominant)

**Do NOT batch.** Each completion triggers its own audit dispatch immediately.

---

## 2. Per-dimension auditor agent template

Each auditor agent is spawned with a prompt that follows this template. `{...}` placeholders are filled by team-lead at dispatch time.

```
You are auditor-D{N}-{WORKER} on team rp-transitions. Your job is a single
focused review of the {WORKER}'s commit against dimension {N}: {DIMENSION_NAME}.

## Required reading

1. ux-research/team/12-continuous-audit.json — spec; pay specific attention to
   the dimensions.D{N}_{key} block listing the items you must check.
2. ux-research/team/00-build-brief.md — mission, animation params, hard rules.
3. ux-research/team/09-auxiliary.md — this file (you are reading it).
4. The worker's commit: git show {COMMIT_SHA}

## Your scope

Audit the diff at {TARGET_PATH} for the items listed in dimension D{N}.
You are NOT auditing other dimensions — those have separate auditors.
You are NOT auditing pre-existing code unless the worker's diff modified it.

## Mechanical-check input

Run scripts/audit.sh {DIMENSION_KEY} {TARGET_PATH} and consume its output.
Mechanical findings are STARTING points; verify each before filing remediation
(some are false positives — e.g., animation magic numbers should NOT be flagged
as Theme-token violations, per the brief).

## Judgment-check process

For each item under dimensions.D{N}_{key}.checks where 'judgment' is non-N/A:
- Read the affected files in the diff.
- Apply the judgment check described.
- For each finding, decide severity: critical | major | minor.

## Output protocol

For each critical or major finding:
- TaskCreate with subject 'Remediate D{N}: {short-finding}'
- Description must include: the file:line, the specific check, the recommended
  remediation, the severity, the original feature task ID, and a 1-sentence
  rationale.
- Use TaskUpdate to add addBlocks: [{ORIGINAL_FEATURE_TASK_ID}] so the feature
  cannot be accepted until this remediation resolves.

For each minor finding:
- Append a line to ux-research/team/audit-log.md in the format described in
  section 4 of 09-auxiliary.md. No new task.

## Completion

After all checks complete:
- Append your one-line summary to ux-research/team/audit-log.md
- SendMessage to team-lead summarizing: count of critical/major/minor findings,
  list of Remediate-D{N} task IDs you filed, any cross-dimension concerns you
  noticed (those become input for other auditors).
- Mark your audit task completed via TaskUpdate.
```

---

## 3. Remediation task template

When an auditor files a remediation, the task description MUST include:

```
**Audit dimension:** D{n} — {dimension_name}
**Triggered by feature task:** #{original_task_id} ({feature_name})
**Severity:** critical | major | minor
**Affected file(s):** path/to/file.swift:line[, …]
**Specific check:** {name from 12-continuous-audit.json — e.g., "magic numbers"}

**Finding:**
{2-3 sentence description of what is wrong, why it matters, and what the
spec/brief expects instead}

**Recommended remediation:**
{2-3 sentence description of the fix, including the specific Theme token /
DI pattern / extraction the worker should apply}

**Acceptance criteria:**
- {bullet list of objective conditions that signal the remediation is complete}
- scripts/audit.sh {dimension_key} {target} no longer flags this specific
  finding (or remaining flags are filed as separate, accepted-as-known issues)
```

The team-lead reviews newly-filed Remediate tasks and either:
- Assigns them to the original worker (`TaskUpdate(owner: <worker-name>)`) for fix-forward, OR
- Assigns to a polish/cleanup agent if the worker has moved on, OR
- Waives with rationale documented in the task description AND the audit log

Waivers are RARE. The default is to fix.

---

## 4. Audit log file

Path: `ux-research/team/audit-log.md`

Append-only running log of every audit firing. Format:

```
## YYYY-MM-DD HH:MM — audit firing {N}

**Triggered by:** {worker-name} marking task #{id} ({title}) completed
**Commit:** {sha}
**Target:** {path}
**Dimensions audited:** D1, D2, D3, D4
**Mechanical results:**
- D1: {pass | fail with N findings}
- D2: {pass | fail with N findings}
- D3: {pass | fail with N findings}
- D4: {pass | fail (build/Maestro)}
**Judgment results:**
- D1 (auditor-D1-{worker}): {N critical, N major, N minor}
- D2: …
- D3: …
- D4: …
**Remediation tasks filed:** Remediate-D1-…(#X), Remediate-D2-…(#Y), …
**Minor observations (no task):**
- {file:line — brief note}
```

Each auditor agent appends its own summary; the team-lead appends the dispatch header. The log is committed at end of polish phase.

---

## 5. Auxiliary task list

These are tasks the team-lead creates IN ADDITION to the feature tasks (1–5). They are explicit, numbered tasks in the team's task list.

### After Architect (Task 1) completes

- **Task 6: Audit architect scaffold (D1, D2, D3, D4)** — owner: team-lead spawns 4 auditor agents
  - blockedBy: [1]
  - blocks: [2, 3, 4]   (workers don't start on bad foundation)

### After Worker A (Task 2) completes

- **Task 7: Audit Worker A diff (D1, D2, D3, D4)**
  - blockedBy: [2]
  - blocks: [5]   (polish blocked until A's audit clean)

### After Worker B (Task 3) completes

- **Task 8: Audit Worker B diff (D1, D2, D3, D4)**
  - blockedBy: [3]
  - blocks: [5]

### After Worker C (Task 4) completes

- **Task 9: Audit Worker C diff (D1, D2, D3, D4)**
  - blockedBy: [4]
  - blocks: [5]

### After Polish (Task 5) completes

- **Task 10: Final system audit (D4-dominant)** — full Maestro pass + judgment review of holistic flow
  - blockedBy: [5]

Each audit task expands into 4 dimension-specific subtasks (one per auditor agent) at dispatch time.

### Remediation tasks (created on demand)

- Subject pattern: `Remediate D{n}: {brief}`
- blockedBy: depends on whether fix is by worker (sequential) or by polish (parallel-eligible)
- blocks: [original feature task id] (so original cannot be accepted)

---

## 6. Tool-installation prerequisites

Before the audit infrastructure is fully operational, the project assumes:

- **xcodegen** (`brew install xcodegen`) — required by D4 mechanical
- **xcodebuild** (Xcode CLT) — required by D4 mechanical
- **maestro** (`curl -Ls "https://get.maestro.mobile.dev" | bash`) — required by D4 holistic flow
- **ast-grep** (`brew install ast-grep`) — OPTIONAL; tighter D1 DRY check when present
- **lizard** (`pip install lizard`) — OPTIONAL; tighter D3 complexity check when present

The audit script gracefully degrades when optional tools are missing — it reports the limitation rather than failing.

---

## 7. Anti-patterns to refuse

The audit infrastructure exists to prevent silent debt. The following must NOT happen:

- ❌ Worker marks task completed without running scripts/audit.sh themselves
- ❌ Audit findings filed as TODO comments in code instead of as Remediate tasks
- ❌ Auditor agent batches findings instead of filing per-finding tasks
- ❌ Team-lead spawns auditors after multiple workers complete (must be per-completion)
- ❌ Polish phase becomes "fix everything from earlier audits" — earlier audits must remediate before polish
- ❌ Waiver granted without rationale logged in both the task description AND audit-log.md

If any of these happen, the audit infrastructure has been bypassed and the next firing must reset the cycle for the affected slice.
