# Worked example: FivBuk search (Go handler + Next.js page)

A filled plan for a real task on FivBuk: a book search endpoint and the page
that calls it. FivBuk reads a PostgreSQL database named `vault` through a
read-only role, `library_ro`, over 50,383 books. Writes never happen here.

**Goal.** `GET /api/books?q=<term>` returns matching book cards, and
`/search?q=<term>` renders them.

**Acceptance for the whole plan.** `curl -s 'http://127.0.0.1:8090/api/books?q=trinh+th%C3%A1m'`
returns JSON whose `total` is greater than 0 and whose first item has a non-empty
`title`; `npm run build` in `web/` exits 0.

---

## T1 — Go search handler

- **Role:** builder
- **Write scope:** `api/internal/search/` only
- **Depends on:** none
- **Context the child must be given:**
  - paths: `api/internal/search/`, `api/cmd/server/main.go`, `api/internal/db/`
  - schema: the real column list of `book`, pasted verbatim from the project's
    DB reference — `id, title, author_name, folder_path, file_name, file_size,
    format, ...`. The child gets the list; it does not get told to go read a
    file it might skim.
  - credentials / env: `DATABASE_URL` already exported in the parent shell; the
    child connects as `library_ro`, SELECT only.
  - constraint: no route registration edits outside `api/internal/search/`; the
    parent wires the router. No ORM, `pgx/v5` only.
- **Acceptance command:** `cd api && go build ./... && go test ./internal/search/ -run TestSearch -count=1`
- **Expected output:** `ok  .../internal/search` and exit 0.

## T2 — Next.js search page

- **Role:** builder
- **Write scope:** `web/app/search/` and `web/components/book-card.tsx` only
- **Depends on:** none (codes against the agreed response shape)
- **Context the child must be given:**
  - paths: `web/app/search/`, `web/components/`
  - data shape: the JSON contract, pasted — `{ total: number, items: [{ id,
    title, author_name }] }`. The child does not infer it from the Go code; two
    builders racing on a guessed contract is how the page ends up reading
    `book.author` when the API sends `author_name`.
  - credentials / env: `API_BASE_URL=http://127.0.0.1:8090`
  - constraint: no changes to `web/app/layout.tsx` or the design tokens.
- **Acceptance command:** `cd web && npm run build`
- **Expected output:** exit 0, and `.next/` present.

## T3 — verify

- **Role:** validator
- **Write scope:** none
- **Depends on:** T1, T2
- **Context the child must be given:**
  - the exact acceptance commands from T1 and T2, verbatim
  - the API must be running: `cd api && go run ./cmd/server &` on port 8090
  - the claim to test: "the endpoint returns matching books and the page builds"
- **Acceptance command:** the whole-plan acceptance command above, plus
  `curl -s 'http://127.0.0.1:8090/api/books?q=zzzznotabook'` which must return
  `total: 0` rather than an error.
- **Expected output:** both checks pass; on failure, the raw output and the first
  line that contradicts the builder's claim.

---

## How this was fanned out

T1 and T2 go in one `delegate_task` call: disjoint write scopes, no shared file,
each `context` carrying the column list or the JSON contract. T3 goes in a
second call after both return, because it needs the endpoint running.

Both builders received the real DB column list in their context. The parent
never lets a child guess the schema — a child that invents a column writes Go
that compiles, runs, and returns empty rows, which reads like a data problem and
costs an hour to find.
