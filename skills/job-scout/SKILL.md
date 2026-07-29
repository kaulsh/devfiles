---
name: job-scout
description: Research companies matching a free-text hiring/stage description (e.g. funding stage signals, seniority, role type) via web search — never job portals or LinkedIn scraping — and compile results into a Google Sheet with career-page/role links, evidence, and a confidence rationale for any fuzzy criteria. Reusable across sessions: pass an existing Sheet URL to keep appending deduped rows, or omit it to create a new one. Use when the user wants to find companies to apply to based on a criteria description, asks to "find companies hiring for X," or invokes this skill directly.
---

# Job Scout

Turns a free-text description of target companies/roles into a deduped, evidence-backed list of companies in a Google Sheet, with links to specific open roles where possible. No job portals, no LinkedIn scraping, no browser/computer-use tooling — this environment doesn't have one, and `WebSearch` + `WebFetch` are the deliberately chosen cheap alternative (both return condensed text, not rendered pages).

Invoked as `/job-scout <criteria text>`, optionally followed by a Google Sheet URL to continue an existing list.

## Step 0 — Parse the invocation

- **Criteria text (required):** arbitrary free text describing the target companies — funding stage, role type, seniority, industry, anything the user wrote. It will be different every time; nothing about a specific criteria (e.g. Series A signals) is hardcoded into this skill.
- **Sheet URL (optional):** if given, it's the target to append to. If not given, ask the user whether to create a new sheet or whether they meant to point at an existing one — don't silently create a persistent artifact they didn't ask for.

## Step 1 — Surface ambiguities before researching

Read the criteria text and sort it into:

- **Objective, directly checkable** signals (e.g. "raised a Series A," "backend engineer," "remote").
- **Fuzzy/indirect** signals that require a judgment call to evaluate (e.g. inferring an unannounced raise from seed-round timing plus secondary evidence like customer-logo changes on a website).
- **Underspecified** dimensions the criteria didn't mention (location/remote stance, company size, industry bounds, what "senior" means here).

For fuzzy or underspecified points that would materially change which companies qualify, ask the user via `AskUserQuestion` before starting the research loop. Only ask about genuine, consequential ambiguity — don't block on details that have an obvious sensible default; note the assumption instead and move on. If the criteria are already fully objective, skip straight to Step 2.

## Step 2 — Connect to the Google Sheet

- Make sure the Google Drive connector is authenticated: call `mcp__claude_ai_Google_Drive__authenticate` if its real tools aren't showing up yet, relay the auth URL to the user, and complete with `mcp__claude_ai_Google_Drive__complete_authentication` once they hand back the callback URL.
- Once authenticated, run `ToolSearch` for "sheets" / "drive" to see the actual tool surface the connector exposes right now — don't assume specific function names or whether it supports range-level read/append vs. whole-file operations; check fresh each time, since this can change between the skill being written and being run.
- **Existing sheet given:** read just enough to build a dedup key set (company name and/or domain per existing row). If the only available operation is a whole-file export, pull just the identifying column(s) for dedup and don't drag the rest into context.
- **No sheet given, user wants a new one:** create a spreadsheet with the header row from the schema below, and report its URL back immediately — that URL is what makes future invocations reusable, so surface it before doing anything else.

## Step 3 — Research loop

No browser tool exists here — don't reach for one even as a fallback for a JS-heavy page. `WebSearch` (cheap snippets, use for discovery and to confirm signals) and `WebFetch` (fetches + condenses through a small model, use to confirm/extract specifics) are the entire toolkit, chosen because they're materially cheaper than screenshot-driven browsing.

Target **~10-15 net-new (non-duplicate) qualifying companies** per invocation as a cost/time bound, not a hard promise — if sources run dry first, stop and say so rather than padding with weak matches.

Per candidate company surfaced by search:

1. Confirm the qualifying signal with 1-2 targeted `WebFetch` calls against the most authoritative source available (news article, the company's own blog/press page). Don't re-fetch a page already seen for a prior candidate.
2. Find the careers page — search `"<company> careers"` or common ATS patterns (Greenhouse, Lever, Ashby, Workable boards are usually static/JSON and `WebFetch`-friendly). Look for postings matching the requested function(s) and seniority.
3. If a specific role-level link is extractable, use it. If the board is JS-rendered and nothing specific can be pulled out, link the general careers page instead and say so in the row — never guess a role URL.
4. Skip the company outright if it's already in the Step 2 dedup set.

## Step 4 — Row schema

| Column | Notes |
|---|---|
| Company | |
| Description | one line, what they do |
| Qualifying signal + evidence | what was found, with source link(s) |
| Confidence | Confirmed / Likely / Speculative, with a short rationale — fill in even for objective criteria, since "Confirmed via a press release" and "Confirmed via a single blog mention" aren't the same |
| Matching role(s) | title + seniority found |
| Application link | specific posting, or careers page if no specific link was extractable |
| Date added | |

## Step 5 — Write and report

- Append all new rows in a single batched write, not one call per row — keeps tool round-trips and tokens down.
- Tell the user: how many new rows were added, the sheet URL, any assumptions made in Step 1, and whether the run stopped at the target batch size or because sources ran out.

## Notes for future invocations

- This skill is meant to be re-invoked in fresh sessions against the same sheet. Always rebuild the dedup set from the sheet itself (Step 2) — never assume anything is remembered from an earlier conversation.
- Criteria can differ completely between runs on the same sheet (different industry, different role type) — that's fine. Dedup is by company identity only; a company already in the sheet from an earlier, differently-themed run is still a duplicate.
