# Project Quality Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Perform a full ShareSurfer project quality review using multiple independent review standards and preserve the results as durable Markdown notes.

**Architecture:** Use independent subagents for separate review lenses, then synthesize their reports into a repo-local review package. Keep this slice documentation-only: do not implement product fixes while reviewing.

**Tech Stack:** Markdown, GitHub issue tracking, local repository inspection, focused validation with `git diff --check`.

**Tracking Issue:** #233

---

## File Structure

- Create `docs/reviews/project-quality-review-2026-06-15/README.md`
  - Entry point and reading order for the review package.
- Create `docs/reviews/project-quality-review-2026-06-15/builder-review.md`
  - Builder/maintainer lens.
- Create `docs/reviews/project-quality-review-2026-06-15/critic-review.md`
  - Risk, defect, and regression lens.
- Create `docs/reviews/project-quality-review-2026-06-15/strategist-review.md`
  - Product, adoption, and roadmap lens.
- Create `docs/reviews/project-quality-review-2026-06-15/quality-gatekeeper-review.md`
  - Validation, release, and acceptance lens.
- Create `docs/reviews/project-quality-review-2026-06-15/comparison-and-synthesis.md`
  - Cross-review agreement, disagreement, priorities, and recommended follow-up.
- Create `docs/reviews/project-quality-review-2026-06-15/follow-up-issue-candidates.md`
  - Candidate GitHub issues produced from the review.

---

## Task 1: Review Setup

**Files:**
- Create: `docs/superpowers/plans/2026-06-15-project-quality-review.md`
- Create: `docs/reviews/project-quality-review-2026-06-15/`

- [x] **Step 1: Create a tracking issue**

Create a GitHub issue describing the multi-standard review and deliverables.

Expected issue: `#233`.

- [x] **Step 2: Create a branch**

Create a branch for review artifacts:

```bash
git switch -c codex/project-quality-review-2026-06-15
```

- [x] **Step 3: Create review artifact directory**

Create:

```bash
mkdir -p docs/reviews/project-quality-review-2026-06-15 docs/superpowers/plans
```

## Task 2: Independent Review Agents

**Files:**
- Create: `docs/reviews/project-quality-review-2026-06-15/builder-review.md`
- Create: `docs/reviews/project-quality-review-2026-06-15/critic-review.md`
- Create: `docs/reviews/project-quality-review-2026-06-15/strategist-review.md`
- Create: `docs/reviews/project-quality-review-2026-06-15/quality-gatekeeper-review.md`

- [x] **Step 1: Run Builder review**

Use a goal-driven subagent with this review standard:

```text
/goal Perform the Builder review standard for ShareSurfer quality review issue #233.
```

The report evaluates architecture, maintainability, command ergonomics, data model extensibility, test ergonomics, release ergonomics, documentation, and contributor experience.

- [x] **Step 2: Run Critic review**

Use a goal-driven subagent with this review standard:

```text
/goal Perform the Critic review standard for ShareSurfer quality review issue #233.
```

The report evaluates likely bugs, regressions, bad assumptions, security/privacy risks, supportability gaps, confusing operator outcomes, broken docs, release traps, and missing tests.

- [x] **Step 3: Run Strategist review**

Use a goal-driven subagent with this review standard:

```text
/goal Perform the Strategist review standard for ShareSurfer quality review issue #233.
```

The report evaluates product coherence, adoption journey, roadmap sequence, business value, migration readiness value, owner/OBS discovery, nonpermissive environments, dashboard/report delivery, lab validation, and release adoption.

- [x] **Step 4: Run Quality Gatekeeper review**

Use a goal-driven subagent with this review standard:

```text
/goal Perform the Quality Gatekeeper review standard for ShareSurfer quality review issue #233.
```

The report evaluates CI, local tests, PowerShell 5.1 compatibility, release packaging, dependency-age policy, static dashboard packaging, lab evidence, acceptance criteria, documentation checks, support bundle/redaction baseline, and unproven assumptions.

## Task 3: Synthesis

**Files:**
- Create: `docs/reviews/project-quality-review-2026-06-15/README.md`
- Create: `docs/reviews/project-quality-review-2026-06-15/comparison-and-synthesis.md`
- Create: `docs/reviews/project-quality-review-2026-06-15/follow-up-issue-candidates.md`

- [x] **Step 1: Save individual reports**

Write each subagent report into its matching Markdown file.

- [x] **Step 2: Compare and contrast**

Create a synthesis report that includes:

- Findings shared by two or more reviewers.
- Findings unique to one review lens.
- Places where reviewers disagree on priority or timing.
- Recommended issue sequence.
- Risk rating for each top theme.

- [x] **Step 3: Write the package README**

Create a short entry point that explains:

- Why the review exists.
- Which review standards were used.
- The recommended reading order.
- Which follow-ups should become issues.

## Task 4: Validation And Closeout

**Files:**
- All review Markdown files.

- [x] **Step 1: Run documentation hygiene checks**

Run:

```bash
git diff --check
rg -n "<placeholder-marker>|<internal-visual-label>|<legacy-environment-label>" docs/reviews/project-quality-review-2026-06-15 docs/superpowers/plans/2026-06-15-project-quality-review.md
```

Expected:

- `git diff --check` is clean.
- No accidental placeholder markers or internal tool labels in review artifacts.
- No public-facing references to legacy internal test-environment labels in review artifacts.

- [x] **Step 2: Commit and push**

Commit message:

```bash
docs: add multi-standard project quality review (#233)
```

- [x] **Step 3: Comment on issue #233**

Post a Markdown body-file issue comment with:

- Commit SHA.
- What changed.
- Validation run.
- High-level follow-up list.

- [x] **Step 4: Open PR to main**

Open a ready PR for the review artifacts.

---

## Self-Review

- Spec coverage: The plan covers at least three review standards and uses four: Builder, Critic, Strategist, and Quality Gatekeeper.
- Placeholder scan: No implementation placeholders are needed because this is a review artifact plan.
- Type consistency: File paths and review labels match the requested output package.
