---
name: review-standard
description: Standard code review — an omissions pass that hunts for what's missing (not just what's wrong) plus straightforward bug/logic-error spotting and nits. Invoked as `/review-standard <ref>` where `<ref>` is a branch name, a worktree (by path or name), or any git commit-ish, to review that ref's diff against the base branch — or `/review-standard` with no argument to review the current HEAD against the base branch. Use for a routine "did this ship anything broken or incomplete" pass — per-track review before merging, or any time the user wants the standard find-what's-wrong-and-missing review without the adversarial necessity framing.
---

# Standard Code Review

An omissions pass (what's missing, not just what's wrong) plus plain bug/logic-error spotting and nits. No rote multi-pass structural ritual, no necessity/alternatives challenge, no reading-order guide, no executive summary, no kudos, no verdict — the reviewer already knows what they're looking at and will decide for themselves whether to merge it.

Do not write or edit implementation code during this skill. The deliverable is the review report — nothing else. If you find real bugs worth fixing, report them; don't silently fix them mid-review.

## Step 0 — Resolve what to diff

Parse the skill argument as an optional `<ref>` — a branch name, a worktree (by path or name), or any other git commit-ish. None of these require a specific tool's worktree machinery; this skill only ever shells out to plain `git`.

**No argument given:** review the current `HEAD` against the base branch (see below). Skip to Step 1.

**Argument given:** figure out what it refers to before doing anything else, trying each in order and stopping at the first match:

1. **A worktree** — run `git worktree list --porcelain` from the repo root and match `<ref>` against the directory basename of each worktree path, or the branch checked out in it, case-insensitively. It doesn't matter how the worktree was created (plain `git worktree add`, an IDE, an agent harness) — if `git worktree list` reports it, it's fair game.
2. **A branch** — a local or remote branch matching `<ref>` by name.
3. **Any other commit-ish** — a tag, a SHA, `HEAD~2`, etc. that `git rev-parse` accepts.

If `<ref>` matches a worktree, scope every subsequent git command to that worktree's path explicitly (`git -C <path> ...`) — never change your own process's working directory to get there, so the review stays read-only and never leaks state into whatever else is running in this session. If `<ref>` matches a branch or other commit-ish instead, diff it directly by name/SHA without needing a working-tree checkout at all.

If `<ref>` matches none of the above, **do not guess** — tell the user what didn't match (no such worktree, branch, or revision) and ask them to clarify.

## Step 1 — Gather context

1. Determine the base branch (default `main`; fall back to `master` or the repo's actual default if `main` doesn't exist).
2. Diff the resolved target against the base branch — `git diff <base>...<ref>` (or `git -C <path> diff <base>...HEAD` when `<ref>` resolved to a worktree). When no argument was given, this is `git diff <base>...HEAD` from the current directory, plus `git diff HEAD` for any uncommitted working-tree/index changes — "the diff" in that case is the union of both.
3. `git status` (scoped the same way) — check untracked files too, not just the diff. A forgotten config/migration file, or a scratch file that shouldn't ship, won't show up in `git diff` at all. This only applies when reviewing an actual working tree (current directory or a worktree) — a bare branch/commit diff has no untracked-file concept.
4. Lines with `+` are additions, `-` are deletions. Don't critique deleted lines in isolation unless the removal itself introduces a bug or drops something a caller still depends on (checked in Step 2).
5. If there's a `plans/track-*.md` file for this work (this project's own convention — check there first) or a linked ticket, read it for the stated definition of done — including whatever reading-order guide the agent that wrote this diff was instructed to leave behind (per `/plan-parallel-implementation`). If one exists, use it as your own entry point instead of cold-reading the diff file-tree-order.

## Step 2 — Omissions pass (what's missing, not just what's wrong)

For every candidate below, don't flag it generically — state the concrete input/scenario that would exercise the gap and what actually happens (crash? wrong data persisted silently? a silent no-op?). "Add error handling here" is not a finding; "if `fetchUser` rejects on line 42, the caller has no catch and the whole request handler crashes uncaught" is.

Check for:
- Missing error handling (unhandled rejections, missing try/catch around a call that can fail)
- Missing input validation at trust boundaries (external input, not internal call sites already covered by types)
- Missing edge-case handling: null/undefined, empty collections, zero/negative numbers, duplicate entries, out-of-order or concurrent events, partial failures mid-operation, retries/timeouts, unexpectedly large input
- Missing permission/authorization checks on a new code path that needs one
- Missing idempotency — does re-running this on retry or crash-recovery double-apply an effect?
- Missing logs/telemetry/metrics on a path that will need to be debugged later
- Missing tests — not just "are there tests," but do they cover the edge cases above or only the happy path?
- Missing documentation updates (README, `CLAUDE.md`/`AGENTS.md`, API docs, design docs) where the change alters a documented contract or invariant
- Missing the inverse/reverse operation — a change that adds `create`/`encode`/`open` without a corresponding `delete`/`decode`/`close` is a common half-finished pattern
- Deletions that silently break a hidden dependency — grep for other callers of anything removed or narrowed before assuming it's dead

## Step 3 — Logic & bugs

Actual bugs and logic errors noticed while reading — wrong conditions, off-by-ones, race conditions, mismatched types papered over with a cast, a happy-path assumption that doesn't hold. This is plain reading-and-tracing, not a separate structural ritual — trace what the code actually does against what it claims to do, guided by whatever reading order the diff came with (Step 1.5).

## Step 4 — Structure the final report

- **Critical Logic & Edge Cases:** Step 3's findings. Rank `[Critical]` / `[Warning]`.
- **Missing / Omissions:** Step 2's findings, each stated as a concrete failure scenario, not a generic suggestion.
- **Readability & Nits:** prefixed `[Nit]` or `[Non-blocking]`.

No executive summary, no kudos section, no verdict — the reviewer already has context on the change and will decide whether to merge it themselves; this report's job is to surface what they might not have already noticed, not to render a judgment for them.

## Feedback style

- Ask questions rather than issuing demands where genuine judgment calls exist: "Would this need a catch if the upstream call can reject?" not "Add a try/catch."
- Prefix minor items with `[Nit]` so they read as clearly non-blocking.
