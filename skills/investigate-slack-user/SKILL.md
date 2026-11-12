---
name: investigate-slack-user
description: >-
  Investigate a Siena person, account, invite, membership, or access problem
  reported in Slack. Use when the user pastes a slack.com/archives link and
  asks what is going on, the current state, or how to unblock that person.
  Read the thread, then the prod read replica (siena_auth and siena_users) and
  Honeycomb production, in that order. Read-only. Do not use for Honeycomb
  alert triage or inbox conversation bugs (debug-issue), or for reviewing pull
  requests linked from Slack.
---

# Investigate a user issue from a Slack link

Read-only. Do not update the replica, send Slack, or open a pull request unless the user asks. A diagnosis already in the thread is a hypothesis, not a finding.

This is for a **person**: account, invite, role, membership, login, SSO. A Honeycomb alert or an `app.siena.cx/inbox` conversation bug is `debug-issue`. A Slack link whose job is to review pull requests is `pr-review`.

Discover each tool's schema before calling it. Namespaces:

| Namespace | Tools |
| --- | --- |
| `plugin-slack-slack` | `slack_read_thread`, `slack_read_file` for images |
| `user-prod-read-only-replica` | `postgres_mcp_list_connection_profiles`, `postgres_mcp_connect`, `postgres_mcp_query` |
| `plugin-honeycomb-honeycomb` | `get_workspace_context`, `run_query`, `get_trace` |

## 1. Read the thread

Parse `https://<workspace>.slack.com/archives/<channel_id>/p<digits>`:

- `channel_id` is the `C...` or `G...` segment.
- `message_ts` is the `p` number with a `.` before the last 6 digits (`p1794389420355479` -> `1794389420.355479`).
- If the URL has `?thread_ts=`, use that as `message_ts`.

Call `slack_read_thread` with `channel_id`, `message_ts`, and `response_format: detailed`. Extract the person, email, organization names, the error text they saw, and the times. If an email or organization is missing, say so and stop before scanning the replica. Read images with `slack_read_file` when the report depends on them.

## 2. Find the error in code

Search the service that owns the error before querying. For account, invite, and membership errors that is `siena-api-auth`:

| What the person saw | Where it is thrown | What to read in the replica |
| --- | --- | --- |
| `Account already exists, please check your email for the link` | `createUser` in `src/datastore/user.js` | Active `users` row with that email. Invite acceptance calls this only when the invite has no `user_uuid` and no existing account was resolved. |
| `User already exists` | `sendInvitations` in `userService.js` | Staff sending an org invite, not team-invite acceptance. |
| `Invitation token is invalid` | `signUpTeamMembership` | `team_memberships.expires_on`, status, token. A null `expires_on` is already expired. |
| `User is already registered, please login instead` | same | Status `ACCEPTED` or `REGISTERED`. |

Team-invite acceptance is `POST /v1/auth/user/sign_up_team_member`. The page is `siena-web/apps/web/pages/team-invite.tsx`. It sends `user_exists` from `GET /v1/auth/user/sign_up_token/verify/:token` and, when that is true, submits with no password.

`siena_auth` is the source of truth. `siena_users` is the copy People reads, filled by SQS. A row can exist in auth days before it exists in users.

## 3. Prod read replica

`postgres_mcp_list_connection_profiles`, then connect to the profile named `prod-read-only-replica`. Do not hardcode the profile id. Connect once per database (`siena_auth`, then `siena_users`). Other databases on that server (`siena_knowledge_base`, `siena_analytics`) are for a different kind of question.

`postgres_mcp_query` is one read-only statement. Format it with line breaks. Every literal needs a `validationQueries` entry. If validation fails, the tool returns distinct values; use those and retry. Organization names are often misspelled (`Live Consious`). Search with `ILIKE`, then keep the uuid.

For a person, in **both** databases:

1. `users` where `lower(email)` matches. Note `uuid`, `is_active`, `workos_id`, `created_at`.
2. `org_users` for that uuid, joined to `organizations` and `roles`.
3. `team_memberships` where the email matches **or** `user_uuid` matches, joined the same way. Note `status`, `user_uuid`, whether `token` is set, `expires_on`, `created_at`, `updated_at`.

Compare the two databases by **uuid**, not by organization name. Names diverge (`Scale Media` in auth, `Scale Media 1MD` in users). `created_at` in `siena_users` is when the sync landed, not when auth created the account.

A `SENT` invite with a null `user_uuid` was sent before the account existed. Accepting it still depends on the code resolving the account by email. Check `origin/master` for that resolution. A local branch is not production.

## 4. Honeycomb

Call `get_workspace_context` first. Use environment `production`.

Auth HTTP is the `auth` dataset. The span `name` is the route (`POST /v1/auth/user/sign_up_team_member`). Anchor the first query on the replica timestamps, a few minutes on either side. Widen only when that window is empty.

Do not start with `contains` over multiple days. Pair a body search with `name` `=` the route, and keep the range tight. Set `include_markers` false unless the question is a deploy.

Raw columns that are actually populated: `name`, `http.status_code`, `http.request.body`, `trace.trace_id`. `http.response.body` and `exception.message` are often empty on that span. Confirm the error string from the code that returns the status, not from a missing column. Passwords and tokens are redacted (`hmac:` prefix). Group retries by that fingerprint. Do not try to recover the token.

`get_trace` often returns only the root span for these requests. One span is still the request.

Honeycomb keeps about 60 days and truncates silently. Do not report a month-over-month trend from Honeycomb alone. Run an unfiltered `COUNT` over the intended range and confirm rows exist at the start before trusting it.

## 5. Answer

Lead with the current state. Then a table of the rows (workspace, status, `user_uuid`, link still present, expiry). Then what Honeycomb showed: status codes, timestamps in UTC, and which link was retried. Then the code path, and what the person still has to do.

Say whether the fix is on `master`. If acceptance will work on the existing links, say that they must open each link, and give the `expires_on` in UTC. Mention the reporter's calendar day when UTC falls on a different date for them.

When auth and users disagree, say which database is ahead and by how long. Do not tell the person to retry until the users consumer will accept a repeated `users` INSERT, or People stays pending behind that message.

## Worked shape

Slack: Julia cannot accept Scale Media, Live Conscious, and Tru Alchemy. Error: "Account already exists."

Replica: one active user, created in auth when Essential Elements was accepted. That invite is `ACCEPTED` with her `user_uuid`. The other three are `SENT`, `user_uuid` null, token still set, same email. Users has the same statuses; its user row appeared days later. Org names differ; uuids match.

Honeycomb: one `200` on `POST /v1/auth/user/sign_up_team_member` at the auth `created_at`, then `400`s on the other invite fingerprints, including retries days later. Every body has `user_exists: false`, which is what verify returns when `user_uuid` is null.

Code: `createUser` throws because those invites never stored her uuid. After the membership change is on `master` and the users consumer ignores a repeated user INSERT, she opens the three existing links and signs in with the password she already has. SSO does not add the other workspaces, because she already belongs to one.
