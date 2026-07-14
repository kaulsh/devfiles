---
name: review-adversarial
description: Runs a single adversarial pass over a diff — steelmans the strongest case for why the change shouldn't exist at all, or should be smaller/simpler/reuse an existing pattern, then rebuts that case with evidence. No omissions hunting, no bug-hunting, no reading-order guide, no verdict — those live in `/review-standard`. Diffs the current working directory against a base branch (default `main`); does not target a specific worktree — meant to be run once, from wherever the parent agent/user already is, e.g. after several worktrees have been merged back into one consolidated state and there isn't bandwidth to adversarially re-litigate each one individually. Invoked as `/review-adversarial` (diffs against `main`) or `/review-adversarial <base-branch>` to diff against a different base. Use when the user wants a skeptical "should this exist" pass, a necessity/alternatives challenge, or explicitly invokes this skill by name.
---

# Adversarial Code Review

One job: argue against the diff as written, as strongly as honestly possible, then resolve that argument with evidence. Nothing else — no omissions pass, no logic-bug hunting, no nits, no reading-order guide (see `/review-standard` for all of that), no worktree targeting (this reviews wherever the caller already is, diffed against a base branch).

Do not write or edit implementation code during this skill. The deliverable is the Necessity & Alternatives report — nothing else.

## Step 0 — Gather the diff

1. Determine the base branch: the skill argument if one was given, otherwise `main` (fall back to `master` or the repo's actual default if `main` doesn't exist).
2. `git diff <base>...HEAD` for committed changes since branching, plus `git diff HEAD` for any uncommitted working-tree/index changes. "The diff" for this review is the union of both, in the current working directory — this skill does not resolve or switch into a worktree; whoever invoked it (a parent agent orchestrating several merged tracks, or the user directly) is assumed to already be standing in the right place.
3. Look for why the change exists: a linked ticket, a `plans/*.md` file in this repo (the convention this project's own planning skill uses for per-track specs), or `CLAUDE.md`/`AGENTS.md` for constraints and prior decisions. The necessity challenge below is impossible to run honestly without knowing what problem the change claims to solve and what's already been decided about how to solve it.

## Step 1 — Adversarial pass (steelman, then rebut)

Argue *against* the change as written, using the strongest case available — then resolve that argument with evidence rather than leaving it hanging. An unresolved devil's-advocate point isn't useful feedback, it's noise; every challenge raised here must end in either "this concern holds, here's why" or "this concern is addressed, here's where."

Work through, in order:

1. **Necessity challenge** — could this problem be solved with no code change at all? Does an existing feature, config flag, library capability, or already-established pattern in this codebase already cover it? Would doing nothing be defensible?
2. **Alternative-approach challenge** — what's the smallest, simplest change that would solve the same problem? Could an existing abstraction already in the codebase be reused instead of introducing a new one, a new dependency, or a new layer?
3. **Complexity-vs-value challenge** — does the surface area this change adds (new types, new config knobs, new failure modes, new files) pay for itself given how often the scenario it handles will actually occur?

For each: write the strongest one-paragraph case a skeptical senior reviewer would make, as if arguing to reject the change outright — then rebut it using specific evidence from the diff or codebase (a concrete line, an existing test, a stated requirement), not vibes. State plainly whether the steelmanned concern holds up or not.

**This is not reflexive contrarianism.** If the change is clearly the right, minimal-necessary approach, say so in one line and move on — manufacturing a false controversy wastes the reader's time as much as missing a real one would. When reviewing a consolidated diff across several merged tracks, expect most individual tracks to clear this bar easily; concentrate real scrutiny on whichever track(s) actually added a new abstraction, dependency, or pattern.

## Step 2 — Report

One section: **Necessity & Alternatives** — each of the three challenges above, as steelman + rebuttal + resolution ("concern holds" or "concern resolved because …"). No executive summary, no omissions list, no bug list, no nits, no verdict — this skill answers exactly one question (should this exist, as built?) and stops there.

## Feedback style

State the case directly and assertively — hedging defeats the purpose of steelmanning. Always pair the assertion with its rebuttal/resolution so it reads as settled analysis, not a drive-by complaint.
