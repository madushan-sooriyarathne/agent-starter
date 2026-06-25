---
paths:
  - "**/*.ts"
---

# Hono Rules

Applies when the project uses Hono as its API framework. Skip if Hono isn't a dependency.

## Routes

Define routes in dedicated route modules and mount them with `app.route("/path", router)` rather than registering every handler on one giant `app.ts`. Keep middleware order deliberate — auth/session middleware must run before the handler that depends on it, not after.

## Validation

Validate every input (body, query, params) with `@hono/zod-validator` at the handler boundary. Treat a Hono handler exactly like a Next.js server action: it's a public endpoint, never trust the caller.

## Errors

Centralize error handling in `app.onError`, returning a consistent error shape. Don't scatter ad hoc `try/catch` + custom JSON error bodies across individual handlers.

## Client

When a frontend calls this API, generate the RPC client from the Hono app type (`hc<AppType>("/")`) and share that type across the boundary, instead of hand-typing `fetch` calls and response shapes on the client. A route's input/output types should flow from the backend definition, not be re-declared.
