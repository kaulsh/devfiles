---
name: pr-review
description: Reviews peers' GitHub pull requests in the user's staged style - explain the PR plainly first, then review code for simplification, database performance, Siena capability authorization, and AI-bot review comments, then draft numbered comments for the user to approve before posting. Use only when the user invokes /pr-review with one or more PR links.
disable-model-invocation: true
---

# PR Review (peer PRs, GitHub)

Input: `/pr-review <link> [<link> ...]`, where each link is a GitHub PR URL or a Slack message URL that contains PR links.

**Hard rules**

- Never launch subagents (Task tool). Reviewing without full context of the surrounding code produces bad comments. Do all the reading yourself.
- Never post anything to GitHub until the user approves specific comment numbers.
- Never approve, request changes, or merge. Post as a plain `COMMENT` review.
- Use `gh` for everything. Run `gh auth status` first; if the token is invalid, stop and tell the user to run `gh auth refresh -h github.com`.

## Phase 0: Resolve Slack links into PR links

Skip this phase if every link is already a `github.com/<owner>/<repo>/pull/<n>` URL.

For each Slack link (`https://<workspace>.slack.com/archives/<channel_id>/p<digits>`):

1. Parse it. `channel_id` is the `C...` / `G...` segment. `message_ts` is the `p` number with a `.` inserted before the last 6 digits (`p1700000000123456` -> `1700000000.123456`). If the URL has `?thread_ts=<ts>`, use that as `message_ts` instead (the linked message is a reply in that thread).
2. Read it with `slack_read_thread` (`channel_id`, `message_ts`). Using the thread read also catches PR links posted in replies. If it returns only the single message, that is fine.
3. Extract every `github.com/.../pull/<n>` URL from the message text, attachments, and replies. Dedupe against any GitHub links the user passed directly.
4. Tell the user in one line what was found (e.g. "Slack message from <author> -> 3 PRs: #101, #102, #103") and carry the Slack message's own text forward as extra context for the Phase 2 explanation (it often says why the PR matters or what the author wants reviewed).
5. If no PR links are found, or the Slack read fails (private channel, no access), stop and tell the user. Do not guess.

Then continue with the resolved PR list.

## Phase 1: Fetch descriptions only (no diff, no code)

For all PR links, in parallel, one `gh` call each:

```bash
gh pr view <url> --json number,title,body,author,baseRefName,headRefName,headRefOid,state,isDraft,additions,deletions,changedFiles,files,statusCheckRollup,labels
```

Use `files[].path` only for names (never fetch patches here). It tells you which areas are touched (routes, migrations, datastore, web) so the explanation and the later review can be targeted. Also pull any linked Linear ticket text from the body if the Linear MCP is available and a ticket ID is present; skip otherwise.

## Phase 2: Explain like I'm dumb

Do not review yet. For each PR, write:

```
### PR #<n> - <title>  (<author>, +<add>/-<del>, <changedFiles> files, CI: <pass/fail/pending>)
**One line:** <what it does, 15 words max>
**Before:** <what was broken or missing, plain words>
**After:** <what is different now, plain words>
**Touches:** <areas, e.g. "one API route + one DB query + a settings page">
**Heads-up:** <anything risky or odd from the description or file list: migration, auth route, no tests, huge size, draft, CI red. Omit if nothing.>
**Review depth:** Skim | Normal | Careful - <5-word reason>
```

Rules for this explanation: no jargon without a one-clause definition, use an everyday analogy only when it genuinely helps, keep each PR under ~10 lines. If several PRs, give all of them, then ask which to review and whether any questions come first.

Then stop and wait. The user may ask questions (answer from the description and file list; if the answer needs code, say so and offer to proceed) or say to proceed.

## Phase 3: Build full context, then review

Only after the user says proceed.

### 3a. Get the code, with full context

1. Map the PR repo to the local clone: `/Users/kaulsh/Documents/Workspace/@siena-ai/<repo-name>`.
2. Create an isolated worktree so the user's working copy is untouched:
   ```bash
   git -C <repo> fetch origin pull/<n>/head:pr-<n>
   git -C <repo> worktree add /tmp/pr-review/<repo>-<n> pr-<n>
   ```
   Fall back to `gh pr diff <url>` plus reading files from the default branch if the worktree fails.
3. Read the diff (`gh pr diff <url>`), then read **every changed file in full** in the worktree, not just the hunks.
4. Follow the code outward until you understand it: callers, callee implementations, the route registration, the datastore functions touched, the related migrations, types, and existing tests. Compare with how sibling code in the same folder does the same thing.
5. Only start forming comments once you can explain the whole flow end to end.

### 3b. Review lenses

Review the PR for these four things only. Do not comment on style, naming, or formatting unless it hides a real problem.

1. **Simplification.** Dead or duplicated code, needless abstraction or config, logic that an existing helper already does, branches that cannot happen, over-defensive error handling, code that could be deleted. Suggest the simpler shape concretely.
2. **Database performance.** N+1 queries or queries inside loops, missing `LIMIT` or unbounded reads, missing indexes for new `WHERE` / `JOIN` / `ORDER BY` columns (check migrations and existing indexes), `SELECT *` on wide or JSON-heavy tables, `OFFSET` pagination on large tables, multiple round trips that could be one query, long transactions or locks, migrations that rewrite or lock big tables, missing `organization_uuid` scoping that causes scans. Cite the query and the table.
3. **Authorization.** Read `/Users/kaulsh/Documents/Workspace/@siena-ai/siena-api-knowledge-base/.agents/skills/siena-permissions/SKILL.md` (and its `references/` when reuse/create/split is in question) before judging. Apply it to the diff:
   - Does the change add or modify a KB route, Ask Siena / MCP tool operation, or web page, nav item, button, or form that reads or writes organization data? If not, write "N/A: <reason>" and move on.
   - Is each route gated with a real capability ID (view ID for reads, write ID for writes)? Verify the ID exists in the auth catalog: search `siena-api-auth` migrations and `siena-web/apps/web/rbac/capabilities.ts`. Flag invented IDs, the near-miss IDs listed in the skill, `authorize_user`, `VIEW_*`/`EDIT_*` strings, new `auth_policy_file` keys.
   - Tools in `TOOL_CAPABILITIES`; `routeCapabilityWiring.test.ts` updated; web gating uses `CapabilityGuard` / `PermissionTooltip` / `ReadOnlyFields` / `usePermissionGuard`; feature flags not used as authorization; deploy order (auth migration before callers).
   - Also check the basics the skill assumes: org scoping on every query (no cross-tenant reads), IDs taken from the session not the body.
   - If it is unclear whether gating is needed or which ID fits, make that a question comment, do not guess.
4. **AI reviewer comments (CodeRabbit, cubic, similar bots).** Fetch all three sources:
   ```bash
   gh api repos/<owner>/<repo>/pulls/<n>/comments --paginate      # inline review comments
   gh api repos/<owner>/<repo>/pulls/<n>/reviews --paginate       # review summaries
   gh api repos/<owner>/<repo>/issues/<n>/comments --paginate     # plain PR comments
   ```
   Keep only authors like `coderabbitai[bot]`, `cubic-dev-ai[bot]`, and other bot accounts. For each, **verify it against the real code** before surfacing it. Surface only the ones that are correct and meaningful (real bugs, security, data loss, perf). Drop nitpicks, stale ones (code already changed), and wrong ones. List dropped ones in one line with a reason so the user knows they were seen. Credit the bot in the comment ("CodeRabbit also flagged this") but restate it in your own words with a verified file and line.

## Phase 4: Present numbered review comments (do not post)

Output exactly this structure.

```
## Review: PR #<n> - <title>
**Verdict:** <Looks good | Minor changes | Needs changes | Blocked> - <one sentence why>
**Coverage:** Simplify <n> | DB perf <n> | Auth <n or N/A> | AI bots <n kept / n dropped>

### Must fix
**#1** `<path>:<line>` - <Simplify | DB | Auth | Bot> - <Blocker | Should fix>
- **In plain words (for you):** <1-2 sentences, no jargon, what is wrong and what could happen>
- **Comment to post:**
  > <short peer-toned comment, 1-4 sentences, concrete fix or suggestion block>

### Should fix
**#2** ...

### Nits / optional
**#3** ...

### Questions to ask the author
**#4** ... (same shape; the comment is phrased as a question)

### Bot comments I dropped
- <bot>: "<gist>" - <why dropped, one clause>

### Looks good
<One line on what was done well; the user can post it as a closing note if wanted.>
```

Rules:

- Sort by severity, number continuously across sections so approval is by number only.
- Each comment: one issue, anchored to a real `path:line` on the PR head commit. Verify the line number in the worktree.
- "In plain words" is for the user only and is never posted. "Comment to post" is what goes on GitHub: short, kind, specific, no lecture, with a code suggestion where it saves the author a step.
- Never invent problems to fill sections. Empty section means omit it. If nothing is wrong, say so.
- With multiple PRs, present one review block per PR, with numbering restarting per PR and prefixed (`#1-1`, `#2-1`) so a single reply can approve across PRs.
- End with: "Which numbers should I post? (e.g. `1,3,4`, `all`, or `none`. You can also ask me to reword any.)"

## Phase 5: Post approved comments

1. Post only the approved numbers, using the "Comment to post" text verbatim (apply any rewording the user asked for).
2. Submit as **one** review with inline comments, event `COMMENT`:
   ```bash
   gh api repos/<owner>/<repo>/pulls/<n>/reviews --method POST --input review.json
   ```
   where `review.json` has `commit_id` (the `headRefOid` from Phase 1, re-check it has not moved), `event: "COMMENT"`, an optional short `body`, and `comments: [{path, line, side: "RIGHT", body}]`.
3. If a line cannot be anchored (not in the diff), fold it into the review `body` instead of failing.
4. Report the posted comment count and the review URL, then remove the worktree (`git worktree remove /tmp/pr-review/<repo>-<n>` and delete `pr-<n>`).
