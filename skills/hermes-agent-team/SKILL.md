---
name: hermes-agent-team
description: "Use when a task needs parallel builder+validator subagents."
version: 1.1.0
author: FivBuk Builder
license: MIT
metadata:
  hermes:
    tags: [multi-agent, delegate, orchestration, team]
---

# Team of subagents: plan, build, verify

A pattern for splitting one task across several Hermes children: the parent
session plans, children build in disjoint write scopes, and a read-only child
re-runs what they built. Ported from `requix/kiro-team` (Kiro CLI) and
re-expressed for Hermes. Nothing here is a `.kiro/` config — roles are prompts
and the runtime is `delegate_task`.

## When to Use

Use when a task splits into 2+ independent workstreams that each take more than
a couple of minutes (backend + frontend, three crawlers, refactor + test suite),
or when an independent check must re-execute what another agent produced.

Do not use for a single edit, a single query, or anything one tool call closes.
The fan-out costs wall clock overhead and returns nothing for small tasks.

## Runtime facts

Verified against Hermes `delegation` config and measured on a 4-core VPS:

- `delegation.max_concurrent_children: 10`, `max_spawn_depth: 1`. One level of
  fan-out, up to ten wide. Children cannot spawn grandchildren, so a plan with
  three tiers does not work — flatten it.
- Children inherit the parent model. Pin per workload with
  `delegation.provider` / `delegation.model`, not per task; there is no per-task
  model field.
- Each child gets its own conversation and terminal. Python variables, shell
  state and `cd` do NOT survive between children or back to the parent. Every
  path, schema and credential a child needs goes into its `context` string.
- Children cannot call `delegate_task`, `clarify`, `memory` or `cronjob`. A child
  can never be the thing that asks the user a question — if the task needs a
  decision, the parent asks before fanning out.
- Results arrive as background messages only after the parent ends its turn.
  Never poll a transcript or wait on an artifact file. Do the work that does not
  depend on the children, then end the turn.

## Roles

| Role | Toolset | Prompt shape | Why it pays |
|---|---|---|---|
| explorer | read-only: grep, read, `psql` SELECT | "report file:line and the exact rows, change nothing" | keeps a large codebase or table dump out of the parent's context |
| builder | write, in ONE directory | "write these files, run this command, paste raw output" | parallel writes to separate trees, no merge conflict |
| validator | read-only, plus the ability to run a command | "re-run `<acceptance command>`, report its exit code and output, do not fix anything" | catches the self-report lie |

A validator is worth it only when it re-executes something: a test, a query, a
`curl`. A validator that only re-reads the diff is theatre — it costs tokens and
returns the same information the parent already has.

## Protocol

1. Parent writes the plan itself, before delegating. Use
   `templates/plan.md`: one block per task with id, role, write scope, depends
   on, the context the child must be given, the acceptance command and the
   expected output. If the parent cannot name the acceptance command for a task,
   that task is not ready to be delegated.
2. Fan out independent tasks in ONE `delegate_task` call. Each `context` is
   self-contained: absolute paths, the real column list, the real credentials,
   the expected output shape. A child knows nothing about this conversation.
3. On results, verify the load-bearing claim yourself: the file exists, the
   query returns N rows, the test passes. A child summary is a self-report, not
   a fact. This one step is the difference between a team and a rumour mill.
4. Only then report to the user, and say which claims you verified and which
   you are taking on the child's word.

Run the eval harness with `bash evals/run.sh <scenario>` (dry by default), and
add `--live` only when you want a timed single-agent run for comparison.

## When not to fan out

- One file, one query, one endpoint — a normal tool call is faster than writing
  the plan.
- Tasks that share a write scope. Two children editing the same file is a merge
  conflict with extra steps.
- Work that needs a user decision mid-flight; children cannot ask.
- Anything where you would be guessing the acceptance check. A team with a vague
  acceptance check produces confident-looking garbage at 2x the cost.

## Pitfalls

- **Child summary is a self-report.** "Uploaded successfully" from a child is a
  claim, not a result. Require a verifiable handle (URL, absolute path, commit
  sha, row count) in the child's output schema and check it yourself.
- **A validator that only re-reads a diff is theatre.** It must run the command.
- **Never let a child guess a schema.** Paste the real column list into
  `context`. A child that invents `books.description` when the column is
  `book.description_text` writes code that runs and returns nothing.
- **Disjoint write scope or nothing.** Assign directories, not files, and never
  let two builders touch the same tree.
- **Fan-out is not free.** kiro-team's own README reports 1.5-2.1x wall-clock
  overhead versus a single agent. Fan out when the work is genuinely parallel,
  not because the tool exists.
- **Do not claim better code.** kiro-team withdrew its quality numbers after its
  acceptance checks scored untouched fixtures at 50-67%. Treat acceptance checks
  as hygiene, and prove them by making them fail on the untouched fixture first
  — that is what `evals/baseline.sh` does.
- **A background result may never be consumed.** Do not build a plan whose next
  step depends on polling a child; end the turn and let the result arrive.
