# Agent instructions for chrome_XD

## Repository facts

- This is an Origin-mirrored repo: the workspace remote (`origin.cursor.com`)
  transparently proxies to `github.com/SijanC147/chrome_XD`. Pull requests,
  Actions, and reviews live on **GitHub**, not Origin.
- CI: `.github/workflows/release-build.yml` builds, signs, and notarizes the
  macOS app on published releases / `v*` tags / manual dispatch. It runs on
  GitHub-hosted `macos-latest` runners.
- If a fine-grained GitHub token is provisioned (conventionally at
  `/tmp/.ghtoken`, or as `GH_TOKEN`), use it with `curl` against the GitHub
  REST/GraphQL APIs for anything not covered by available tooling
  (dispatching workflows, downloading run logs, resolving review threads via
  the GraphQL `resolveReviewThread` mutation). Never print the token.

## Greptile code review — manual triggering policy (credit-conscious)

Greptile does NOT auto-review PRs in this repository (auto-review burns
credits too quickly). A review is triggered manually by posting a PR comment
containing exactly `@greptileai`.

Agents decide when to trigger a review themselves, but must be
**conservative**:

1. **Never trigger per-commit.** Batch all related commits for the current
   task and trigger at most once the branch reaches a review-ready state:
   - all planned work for the task is committed and pushed;
   - lint/tests/local validation pass;
   - no further commits are expected imminently for this task.
2. **Typical cadence is two reviews per PR**: one when the PR is complete and
   ready for review, and one after a batched round of review-fix commits.
   If you know more changes are coming (multi-step task, ongoing debugging,
   queued user follow-ups), hold off and keep batching.
3. **Never re-trigger when the PR head SHA is unchanged** since Greptile's
   last review, and never trigger on work-in-progress/draft states unless the
   user explicitly asks.
4. **Budget guard**: do not exceed three triggered reviews on a single PR
   without asking the user first.

## Pull request / review protocol (mandatory)

Before a PR may be merged (and before declaring PR work complete):

1. When the PR is review-ready per the policy above, post the `@greptileai`
   trigger comment, then **stand by and monitor the PR**: poll for Greptile's
   review to appear (its review comments/submission from `greptile-apps`),
   rather than ending the session or moving on.
2. Fetch all review comments left by the Greptile bot (`greptile-apps`).
3. For each comment, assess validity. If valid, implement the fix; add
   clarifying code comments where the reviewer flagged unclear behavior.
   If invalid, prepare a reasoned justification instead.
4. Commit and push all fixes **as one batched round**.
5. Reply to every Greptile comment individually, stating what changed (with
   the commit SHA) or why no change was needed.
6. Resolve each addressed review thread (GraphQL `resolveReviewThread` when a
   token is available; otherwise ask the user to resolve).
7. Re-trigger `@greptileai` once for the batched fix round, stand by and
   monitor again, and repeat steps 2-7 until the review passes completely
   with no new comments to address and the PR `mergeable_state` is "clean"
   (subject to the budget guard above — ask the user before a 4th review).
8. **Merging**: once a PR has passed all checks and every review comment has
   been addressed and resolved per the steps above, agents are cleared to
   merge it without asking — unless the user has instructed otherwise for
   that PR/task, or extenuating circumstances apply (e.g. risky/irreversible
   changes, doubts about correctness, unresolved discussion with the user).
   Use squash merge to match this repository's history style.

## Release / CI notes

- Tags must be `v<major>[.<minor>[.<patch>]]` (e.g. `v1.2.3`); the workflow
  rejects malformed versions.
- Use the `force_adhoc=true` dispatch input to exercise the build pipeline
  without consuming signing/notarization (useful for CI debugging).
- Signing/notarization requires the six repository secrets documented in
  `README.md`; partial configuration fails fast by design.
