---
name: nextjs
description: "INVOKE when writing or reviewing Next.js code: App Router, Server Components, route handlers, server actions, data fetching, caching, rendering, or deployment. Covers our conventions, then escalates to live docs."
---

# Next.js

Our conventions for Next.js work, then the escalation ladder for anything this skill doesn't settle.

## Conventions

- **App Router by default.** New routes go under `app/`. Reach for the Pages Router only in an existing Pages-based codebase.
- **Server Components by default.** Add `"use client"` only at the leaf that actually needs interactivity, state, or browser APIs. Keep client bundles small by pushing data fetching and heavy logic to the server.
- **Fetch on the server, colocated with the component that needs it.** Parallelize independent fetches; never chain awaits that could run together. This is where most Next.js latency hides.
- **Server Actions** for mutations from Server Components. Authenticate and validate every action as if it were a public API route, because it is one.
- **Caching is explicit.** State the caching intent (`force-cache`, `no-store`, `revalidate`, `cache: 'force-cache'`) at every fetch and route. Don't rely on remembered defaults; they change between Next.js majors.
- **The performance rules live in the `vercel-react-best-practices` skill.** For waterfalls, bundle size, RSC serialization, and re-render discipline, read that skill first. It is the authoritative React/Next.js performance source here.

## Escalation ladder

Follow this in order. Stop at the first rung that answers the question.

1. **This skill and `vercel-react-best-practices`** for conventions and performance patterns.
2. **Context7 MCP** for current, version-specific API detail (App Router APIs, `next/*` modules, config options). Call `resolve-library-id` for `next.js`, then `get-library-docs` with the resolved ID (usually `/vercel/next.js`). Next.js moves fast and its caching and routing APIs change across majors, so prefer live docs over memory whenever the exact signature or default matters.
3. **Your own knowledge** only when the source skill and the MCP both come up short. Say so when you do, so the gap can be filled later.
</content>
