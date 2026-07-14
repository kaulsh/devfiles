---
name: plan-parallel-implementation
description: Turn a design-doc path or a task description into a phased implementation plan — a sequential foundation only when the codebase actually needs one, plus a handful of independent parallel tracks — write one self-contained plan file per track into `plans/`, and draft copy-pasteable prompts so other coding agents implement each track from its own file. Planning-only: never implements a track itself, never creates worktrees or branches. Use whenever the user wants to parallelize implementation work across multiple agents, asks to "partition," "split up," or "parallelize" a project, or invokes this skill directly.
---

# Parallel Implementation Plan

**This skill is planning-only.** It never implements any track itself — including a foundational one, when there is one — and it never creates git worktrees or branches. Its entire output is: a phased plan, one self-contained markdown file per track under `plans/`, and prompt(s) that hand every track to an external coding agent working from its own plan file. If you find yourself about to write application code, or about to reason "I'll just take this one track myself since I already have the context loaded," stop — that is exactly the failure mode this skill exists to prevent. Every track, with no exception, is handed off.

Invoked as `/parallel-implementation-plan <path>` where `<path>` points to design documentation, or with a short description of the task instead of a path — a path isn't always available.

Do not write implementation code during this skill. The deliverables are the plan, the per-track files in `plans/`, and the prompt(s) — nothing else. This skill does not create git worktrees or branches itself.

## Step 0 — Read context

- If the argument is a path, read every design doc there in full — all markdown files if it's a folder, not a sample.
- If the argument is a task description with no path, gather context yourself instead: look for design docs, existing `plans/*.md` specs, and read enough of the current relevant code that the plan is grounded in what's actually there, not just in how the task was phrased.
- Check the repo root for `CLAUDE.md`/`AGENTS.md` either way — these encode invariants and conventions the plan must respect and take precedence over your own judgment on anything they've already decided.
- Asking a clarifying question is available, not required. If something material is genuinely ambiguous once you've read what's there — which doc is actually in scope, which of two real interpretations of a short task description is meant — ask. Don't treat it as a mandatory gate, and don't manufacture an ambiguity just to justify asking one.

## Step 1 — Decide whether a sequential foundation is needed

Not every plan needs a Phase 0. Before proposing one, check:

1. Do the parallel seams you're about to identify in Step 2 actually depend on something not yet decided or built — a schema, a shared interface, a data model?
2. If so, does that thing already exist in the current codebase, fully decided? A foundation that's already in place isn't something to rebuild — treat it as given context for every track instead.

Only define a **Phase 0** when there's a real, currently-missing dependency that multiple tracks would otherwise redundantly invent or conflict over. When one exists, state explicitly:
- What gets built.
- Which doc sections (or task requirements) it covers.
- Which later tracks actually name it as a dependency — this is what proves it's foundational, not just convenient to build first.

If the seams are genuinely independent of each other and of anything undecided, **skip Phase 0 entirely** and say so explicitly — go straight to Step 2's tracks. Don't force a foundation phase out of habit.

When a Phase 0 is warranted, it's a track like any other for the purposes of this skill: it gets its own plan file (Step 4) and its own handoff in the prompt(s) (Step 5). The only thing that makes it different is *sequencing* — it must land before the parallel tracks start, since building against a schema that's still being decided guarantees conflicts. It is never something this planning session builds itself.

## Step 2 — Find the natural parallel seams

Scan for places the design already describes something as pluggable, swappable, provider/loader-based, or an interface the rest of the system only talks to abstractly (never a concrete implementation). These are the only safe seams for parallel work — a track built against a stable contract doesn't need the other track's implementation to exist yet, so the two agents never block each other or read each other's in-progress code.

**Do not invent seams the source material doesn't already imply.** If the system is genuinely tightly coupled with no natural interface boundaries, say so directly and propose sequential phases instead of forcing an artificial split — over-partitioning a coupled system creates more merge conflict than working through it one phase at a time would have.

**Cap it at 2–4 tracks.** More than that increases coordination overhead past what a single review pass can catch, and defeats the point of parallelizing.

For each candidate track, specify:
- **Goal** — one line.
- **Scope** — doc sections implemented, or the slice of the task it covers.
- **Dependencies** — ideally "Phase 0 only," or "none" when there's no Phase 0. If a track depends on another track's output, it isn't actually parallel — merge it into that track or resequence it into its own phase.
- **Interface contract** — the exact shape (types, function signatures, schema) this track must produce or consume to merge cleanly without touching the other track's files.
- **File-level footprint** — the directories/files this track is expected to touch. If two tracks would touch the same file, that's not a real parallel split; call it out and resequence or merge them.

Don't assign branch names to tracks — that's not this skill's decision to make (see Step 5).

## Step 3 — Present the plan for confirmation

- Present the full breakdown to the user: Phase 0 (if any) plus every parallel track, exactly as specified in Steps 1–2, including your reasoning for whether a foundation phase was actually needed.
- List any coordination points that still need a human decision before tracks start — e.g. a shared type file, a migration everything depends on.
- **Do not recommend that this session take any track, including Phase 0.** There is no "which one should I take" decision to make — none of them are taken by this session. If asked to reconsider, hold this line; it's a fixed property of the skill, not a per-project judgment call.
- Wait for the user to approve or amend the plan before proceeding to Step 4.

## Step 4 — Write per-track plan files

Once approved, create a `plans/` directory at the repo root if it doesn't already exist, and write one self-contained markdown file per track — including Phase 0, if there is one. Each file must give an agent everything it needs to work independently, without re-deriving anything from a conversation it wasn't part of:

- **Filename convention:** `plans/00-foundation.md` for Phase 0 when one exists, then `plans/track-a-<slug>.md`, `plans/track-b-<slug>.md`, etc. for the parallel tracks, using the slug from the track's goal.
- **File contents:** goal, exact scope to implement (with enough excerpted context that the agent doesn't have to guess which parts of a large doc or task apply), interface contract to produce/consume, file-level footprint, dependencies, and a concrete definition of done.
- **Definition of done must always include a self-authored reading-order guide.** Once implementation is complete, the agent produces a short reading-order guide for whoever reviews its diff — which files/functions to read, in what order, prioritized by risk (state mutation, external calls, concurrency, auth first; mechanical/generated/renamed files last) — sized to how large that track's own diff actually turned out to be (near-nothing for a small track, a real prioritized list for a large one). The agent that wrote the code is best positioned to say what's safe to skim vs. what needs careful reading — don't leave this for a downstream review skill to reconstruct after the fact from a cold read of the diff.
- Also write a short `plans/00-index.md` listing every track file, its one-line goal, and the run order (Phase 0 first if one exists; the rest in any order relative to each other) — this is what the user reviews to get the whole picture before greenlighting execution, and what each agent can cross-check against.

Show the user the list of files you wrote (not their full contents inline) and let them know they're free to review or edit any of them before the prompt(s) are run.

## Step 5 — Generate the coding-agent prompt(s)

This is the final deliverable.

- **If a Phase 0 exists:** produce two deliverables — a **foundation prompt** (single task: implement `plans/00-foundation.md`, merge it back to the current/base branch, confirm completion before anything else begins) and a **parallel-tracks prompt** (one entry per remaining track) that explicitly must not be run until the foundation prompt has completed and merged.
- **If no Phase 0 exists:** produce a single prompt covering all tracks.

Each task entry should be short: point at its `plans/track-*.md` (or `00-foundation.md`) file rather than restating its contents, and instruct the agent to read that file, `CLAUDE.md`/`AGENTS.md` (if present), and the referenced doc sections before writing any code. Restate the reading-order-guide requirement from Step 4 explicitly in the prompt too — don't rely on the agent finding it buried in the plan file alone, since it's easy to skip once the "real" implementation work feels done.

**Branches:** don't instruct the agent to create a specifically-named branch per task. If the target tool creates its own worktree per task (this is the tool's behavior, not something this skill controls), it should branch from the current/base branch — say so explicitly if the prompt discusses worktrees at all, so nothing invents a branching scheme this skill didn't ask for.

**Formatting — make every task/prompt easy to isolate and copy individually:**
- Separate each task entry within a multi-task prompt with a `---` line.
- When both a foundation prompt and a parallel-tracks prompt exist, separate them with a `---` line as well, in addition to giving each its own labeled, fenced code block, in run order, so the user can copy each one as-is with no editing required.

Both/all prompts must satisfy:
- **Independence** — no task should require reading another task's not-yet-written code. If a task seems to need another track's output, that dependency belongs in Phase 0; go back and fix Step 1/2 rather than papering over it here.
- **Point to files, don't restate them** — each prompt's job is to route an agent to its plan file, not duplicate that file's contents inline.

## What not to do

- Don't force a Phase 0 when nothing currently missing actually blocks the parallel tracks — check the codebase first, not just the doc's structure.
- Don't parallelize a sequential foundation, when one exists — it's sequential precisely because parallelizing it is unsafe.
- Don't assign any track to this planning session, including Phase 0 — every track, no exceptions, is handed to an external agent.
- Don't propose more than 2–4 parallel tracks.
- Don't invent interface boundaries the source material doesn't already describe.
- Don't let two tracks share file-level ownership of the same files.
- Don't create git worktrees or branches yourself, and don't prescribe branch names for tracks — if worktrees get created downstream, they branch from the current/base branch.
- Don't treat a clarifying question as a required step — ask only when something material is genuinely ambiguous.
- Don't write any implementation code as part of this skill — the plan, the `plans/` files, and the prompt(s) are the entire output.
