# hermes-team

A plan/build/verify pattern for [Hermes Agent](https://hermes-agent.nousresearch.com):
the parent session writes a markdown plan, fans independent tasks out to child
agents in one `delegate_task` call, and then re-runs the acceptance check itself
instead of trusting the children's summaries. It is a port of the ideas in
[requix/kiro-team](https://github.com/requix/kiro-team) to Hermes primitives —
skills, subagents, markdown plans, git worktrees.

## What this is not

- **Not a copy of kiro-team.** Its `.kiro/agents/*.json`, `trustedAgents`,
  `@skill` references and `todo` tool exist only inside `kiro-cli`. None of them
  can be imported here. See `docs/DESIGN.md` for the mapping and what was
  dropped.
- **Not a claim that teams beat single agents.** Teams buy parallel wall clock.
  They do not produce better code by construction, and this repo has no evidence
  that they do. kiro-team's README withdrew its own quality numbers after its
  acceptance checks turned out to score untouched fixtures at 50-67%.
- **Not an eval framework.** `evals/` is one scenario plus a baseline and a
  timed runner. It reports pass/fail and seconds. It does not rank models or
  agents on quality.

## Quick start

```bash
# 1. structural checks on the skill and repo (20 checks)
bash scripts/validate-skill.sh

# 2. install into a Hermes profile (validates first, refuses to clobber)
bash scripts/install.sh
HERMES_HOME=/tmp/hh bash scripts/install.sh   # install into a scratch profile

# 3. prove the eval's acceptance check is not vacuous
bash evals/baseline.sh              # must print: baseline result: FAIL (0%)
bash evals/run.sh off-by-one        # dry structural run, no tokens spent
bash evals/run.sh off-by-one --live # actually runs an agent, writes metrics.json
```

Then read `skills/hermes-agent-team/SKILL.md` and `templates/plan.md`.

## The protocol

1. **Plan in the parent.** Fill `templates/plan.md`: one block per task with id,
   role, write scope, dependencies, the context the child must receive, the
   acceptance command, and the expected output. A task without a named
   acceptance command is not ready to delegate.
2. **Fan out in one call.** Independent tasks go into a single `delegate_task`
   call. Each `context` is self-contained — the child sees nothing of the plan,
   this conversation, or its siblings. Paste real paths, real schema, real
   credentials.
3. **Verify the load-bearing claim.** When results arrive, the parent re-runs
   the thing that matters: the test, the query, the `curl`. A child saying
   "done" is a self-report.
4. **Report, with the split.** Say which claims were verified by re-execution
   and which rest on a child's word.

| Role | Toolset | Prompt shape | Why it pays |
|---|---|---|---|
| explorer | read-only: grep, read, `psql` SELECT | report `file:line` and exact rows, change nothing | keeps a large codebase or table dump out of the parent's context |
| builder | write, restricted to one directory | write these files, run this command, paste raw output | parallel writes to disjoint trees, no merge conflicts |
| validator | read-only + can run a command | re-run this command, report its exit code, fix nothing | catches the self-report lie |

A validator only earns its tokens when it re-executes something. One that
re-reads a diff is theatre.

## When not to fan out

One file, one query, one endpoint, anything a single tool call closes: the
plan costs more than the work. Tasks sharing a write scope: that is a merge
conflict with extra steps. Work that needs a user decision mid-flight: children
cannot call `clarify`. Anything where you would be guessing the acceptance
check: a team with a vague gate produces confident garbage at double the price.

## Evidence

All numbers below were measured on a 4-core, 5.9 GB VPS running Hermes with
profile `fivbuk`, model `deepseek-flash`.

| Item | Value |
|---|---|
| `delegation.max_concurrent_children` | 10 |
| `delegation.max_spawn_depth` | 1 (children cannot spawn grandchildren) |
| `delegation.orchestrator_enabled` | true |
| Model | `deepseek-flash`, inherited by children |
| One `delegate_task` batch, 2 children, wall clock | **35.37 s** |
| child A work time (wrote and ran a Go program) | 34.65 s |
| child B work time (counted files) | 18.14 s |
| Same work run sequentially, estimated | 52.79 s |
| Parent then re-ran `go run main.go` itself | printed `5050` |

That is the only measurement behind this repo. It shows the batch overlapped
the two children and finished in less wall clock than running them one after
another. It says nothing about the quality of what the children wrote — the
parent had to re-run the program to know it worked, which is the whole point of
step 3.

## Layout

```
README.md
LICENSE
.gitignore
skills/hermes-agent-team/SKILL.md     the canonical skill
templates/plan.md                     fill-in plan, one block per task
scripts/validate-skill.sh             14 structural checks, exits non-zero on failure
scripts/install.sh                    copies the skill into a Hermes profile
evals/baseline.sh                     requires the acceptance check to fail untouched
evals/run.sh                          dry structural run, or --live timed run
evals/scenarios/off-by-one/
    task.md                           the task text for an agent arm
    acceptance.sh                     runs tests.py, exits with its code
    fixture/solution.py               deliberately off-by-one
    fixture/tests.py                  plain asserts, no pytest
examples/fivbuk-search.md             a filled plan for a real project
docs/DESIGN.md                        kiro-team mapping and dropped parts
```

## Known limits

- **No dependency enforcement.** The runtime does not know that T3 needs T1.
  Tier 2 of a plan means a second `delegate_task` call and another round trip.
- **One fan-out level.** `max_spawn_depth: 1`. A three-tier plan does not work.
- **No per-task model.** The model is pinned by `delegation.model` for the whole
  profile, so you cannot send the cheap tasks to a cheap model.
- **Children cannot ask.** No `clarify`, no user question, no `memory` write.
  Anything a child must decide had to be decided in the plan.
- **Evals are thin.** One scenario, ten assertions, a plain-python runner. It
  proves the harness works and that the gate is not vacuous. It does not
  establish that a team helps.
- **Wall clock overhead is real.** kiro-team's own README reports 1.5-2.1x
  overhead versus a single agent. Expect the same shape here for small tasks.

## License

MIT. See `LICENSE`.
