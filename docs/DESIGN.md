# Design note: from kiro-team to hermes-team

## Why kiro-team cannot be copied

`requix/kiro-team` is built on primitives that only exist inside `kiro-cli`:

- `.kiro/agents/*.json` — agent definitions read by the Kiro CLI loader. Hermes
  has no such file format; a "role" here is a prompt string in `context`.
- `trustedAgents` — a Kiro permission concept for which agent may invoke which.
  Hermes' equivalent is process-level: a child either has a tool or it does not.
- `@skill` references — Kiro's in-prompt skill include. Hermes loads skills by
  name into a session, and a child session gets whatever its own prompt and
  config give it.
- the `todo` tool — Kiro's structured task list. Hermes' equivalent is a
  markdown file on disk that the parent reads and writes.
- `/agent swap` — swapping the active agent inside one session. Hermes keeps one
  agent per session and creates a new session per child.
- 67 static checks and 14 evals — tied to Kiro's config schema. Porting them
  would mean re-implementing a validator for a format this repo does not have.

Copying the JSON would produce files that no Hermes build reads. That would look
like a port and do nothing.

## 1-1 mapping

| kiro-team | hermes-team |
|---|---|
| team lead agent | the parent session; it plans and verifies, never builds in parallel |
| builder subagent | child from `delegate_task` with filesystem + terminal |
| validator subagent | read-only child that re-runs the acceptance command |
| documenter subagent | a separate later child, spawned after verification, never in the same batch |
| TODO tool state | `templates/plan.md` filled in and checked off by the parent |
| worktree isolation | `git worktree` / `hermes -w` per builder, so parallel writes never collide |
| 67 static checks + 14 evals | **not ported** — see below |

## What was deliberately dropped

- **The 67 static checks.** They assert the shape of Kiro config files. This repo
  has no config files to assert. `scripts/validate-skill.sh` is the replacement,
  and it checks the thing that can actually break here: frontmatter, required
  headings, path hygiene, and the presence of the files the docs promise.
- **The 14 evals.** They measured a CLI this repo does not run. One scenario
  survives, `off-by-one`, because what it tests is the harness rather than the
  product: does the acceptance check fail before the work and pass after it.
- **The quality claims.** kiro-team's README originally reported that teams
  produced better code. It withdrew those numbers once its acceptance checks
  were found to score untouched fixtures at 50-67%. This repo keeps the lesson
  (`evals/baseline.sh` fails hard if the untouched fixture passes) and makes no
  quality claim at all.
- **The agent-config DSL.** Roles here are four table rows in the skill, not a
  schema. If the prompt shape is wrong, edit the string.
