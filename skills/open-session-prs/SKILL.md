---
name: open-session-prs
description: Opens pull requests for every branch worked on in the current session, targeting `master` unless told otherwise, with a short fixed-format description that ignores the repo's PR template. Use when the user asks to open PRs, raise PRs, or ship the branches from this session.
disable-model-invocation: true
---

# Open Session PRs

## Steps

1. **Collect branches.** List every branch created, committed to, or pushed in this session, across all repos in the workspace. Confirm each with `git -C <repo> branch --show-current` / `git log`. Skip branches with no commits ahead of the base.
2. **Check state.** If a branch has uncommitted changes, ask the user before committing. Push each branch with `git push -u origin <branch>`.
3. **Pick the base.** Use `master`, unless the user named a different base for this request.
4. **Draft each description** using the template below. Do NOT use the repo's PR template (`.github/pull_request_template.md` or similar).
5. **Open the PR** with `gh pr create --base <base> --head <branch> --title "<title>" --body-file <tmpfile>`. If a PR already exists for the branch, update it with `gh pr edit` instead of creating a duplicate.
   **If any `gh` command fails with an invalid token or auth error:** the sandbox is the likely cause, so re-run the same command outside the sandbox (request `all` permissions). Only if it still fails outside the sandbox, stop and ask the user to run `gh auth refresh`, then retry once they confirm. Do not attempt `gh auth login` or `gh auth refresh` yourself.
6. **Cross-link.** Once all PRs exist, add the sibling PR URLs to each PR's `### Links` section via `gh pr edit`.
7. **Draft the Slack message** for `#developers-product` (see below) covering all the PRs from this session.
8. **Report** the PR URLs (with repo and branch), then show the drafted Slack message in a code block so the user can copy it. **Never send it.** Do not call any Slack send, schedule, or draft tool. The user posts it themselves when ready.

## Title

Match the branch's existing commit style. Prefix the Linear issue ID when one exists (e.g. `SNA-1234: Short summary`).

## Description template

Use these headings exactly, in this order. Keep every section short.

```
### Links
[Bullet points containing links to linear issue(s) and related PR(s)]

### What does this PR do?
[Answer the question and keep it simple. No particular format, but use bullet points to keep the readable content short and concise. This section should take no longer than 30 seconds to read.]

### How to review
[Short flow diagram on what files/modules/functions to review]

### How this was tested
[If the session describes a test plan or manual test cases, summarize them here into small 1 line bullet points]

### Notes
[any exceptions that the reviewer should consider]
[any changes in decisions made that might contradict the linear issue description or comments]
[any database migrations]
[any new environment variables]
```

## Filling it in

- **Links**: Linear issues from the session, branch name, or commits, plus the sibling PRs from step 6.
- **How to review**: A compact text flow, e.g. `route -> controller -> service -> datastore`, naming the key files or functions.
- **How this was tested**: Only what the session actually ran or planned. If nothing was tested, say so in one line. Do not invent test cases.
- **Notes**: Include only items that apply. Drop any bullet with nothing to report. Always call out migrations and new env vars when present, and any place the implementation departs from the Linear issue.

## Slack message (draft only)

- Start with `@engineering please review:` (plain text, since the real group mention does not survive copy-paste; the user re-selects the mention in Slack).
- One top-level bullet (`•`) per ticket. Lead with the Linear issue as a markdown link, `[TICKET-ID](url)`, then an em dash, then a short plain-language summary of what changed, written for a reader who has not seen the PR. No file names or jargon. A few sentences is fine when the change needs them.
- Mention a feature flag (by name) or a migration inside that summary only if it changes how the reviewer should approach the PR, in a few words. Skip what does not apply.
- Under each bullet, nest one line (`◦`) per PR: full repo name, a colon, then the URL (e.g. `siena-api-knowledge-base: https://github.com/...`).
- Add an optional nested `cc @name @name` line when there are people to loop in.
- If several unrelated changes were opened, give each its own top-level bullet with its own summary. Related PRs for the same ticket stay nested under one bullet.
- Keep it short. No headings, no template, no "Sent using" footer.
- One message per session, not one per PR.

Example:

```
@engineering please review:
• [EAA-3941](https://linear.app/siena/issue/EAA-3941/journey-improvement-loop-over-the-mcp-diagnose-fix-on-a-version-split) — Siena MCP now has tools that can allow for a journey improvement loop. It finds which journeys hand off the most, edits a draft, sends up to 10% of traffic to it, and reads how that draft compares with the live version. Promoting still happens in the app, and the new operations only show up when journey versions are on.
   ◦ siena-api-knowledge-base: https://github.com/siena-ai/siena-api-knowledge-base/pull/7457
   ◦ cc @Constantin Şuiu @Nico
• [TICKET-ID-2](http://link) — Summary
   ◦ repo-name: PR link
   ◦ repo-name: PR link
   ◦ [optional] cc @name @name
```
