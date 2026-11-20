# Plan: <short title>

**Goal.** <one sentence, the outcome, not the activity.>

**Acceptance for the whole plan.** `<one command that proves the goal is met, and
what its output must contain.>`

Parent verifies this itself after the children return. Children do not declare
the plan done.

---

## T1 — <task id and short name>

- **Role:** explorer | builder | validator
- **Write scope:** `path/to/dir/` (a directory, not a single file; no other
  child may write here)
- **Depends on:** none | T0
- **Context the child must be given:**
  - paths: `<absolute path 1>`, `<absolute path 2>`
  - schema / data shape: `<paste the real column list or type definition here —
    never tell the child to go look it up if a wrong guess would compile>`
  - credentials / env: `<exact variable names and how to export them>`
  - constraint: `<what it must not touch>`
- **Acceptance command:** `<command the child runs and the parent re-runs>`
- **Expected output:** `<the substring, exit code, row count or file size that
  means pass>`

## T2 — <task id and short name>

- **Role:**
- **Write scope:**
- **Depends on:**
- **Context the child must be given:**
  - paths:
  - schema / data shape:
  - credentials / env:
  - constraint:
- **Acceptance command:**
- **Expected output:**

## T3 — verify

- **Role:** validator
- **Write scope:** none (read-only)
- **Depends on:** T1, T2
- **Context the child must be given:**
  - paths:
  - the acceptance commands from T1 and T2, verbatim
  - the claim each builder made, so the validator can contradict it
- **Acceptance command:** the whole-plan acceptance command above
- **Expected output:** exit code 0 and the expected substring; on failure, the
  raw output and the first line that differs from the claim.

---

## How to fan out

Send every independent task in ONE `delegate_task` call. Each child's `context`
is a self-contained string built from that task's block — the child does not see
this plan, this conversation, or another child's output. Dependencies are not
something the runtime enforces: if T3 depends on T1, T3 goes in a second call
after T1 returns, and only a plan where tier 2 is worth the round trip is worth
writing.

After the results arrive, re-run the load-bearing claim yourself. Then mark each
task done or not done in this file, with the command you ran and what it
printed.
