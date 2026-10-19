# devops-interview-api

Minimal CRUD API backed by Postgres. You containerize and deploy this.

## Endpoints

- `GET /livez` — liveness
- `GET /readyz` — readiness (checks DB connectivity)
- `GET /items` — list items
- `GET /items/:id` — view one item
- `POST /items` — add an item, body: `{"name": "...", "value": "..."}`
- `PUT /items/:id` — modify an item, body: `{"name": "...", "value": "..."}`

## Configuration

Copy `.env.example` to `.env` and set `DATABASE_URL` (or the standard
`PGHOST`/`PGPORT`/`PGDATABASE`/`PGUSER`/`PGPASSWORD` env vars).

## Running locally

```bash
npm install
npm run migrate   # applies migrations/*.sql
npm start
```
