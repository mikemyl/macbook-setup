# How I Work

## Workflow

I use [GSD (get-shit-done)](https://github.com/trek-e/get-shit-done) for structured project work. For each project phase: Discuss -> Plan -> Execute -> Verify. Use `/gsd:progress` to see where things stand.

For small tasks outside the phase workflow, use `/gsd:quick` or `/gsd:fast`.

## Testing

ATDD is mandatory. Acceptance scenarios must be defined before implementation. The `atdd-gate.js` hook hard-blocks SUMMARY.md writes without passing acceptance tests. Mutation testing is required before phase completion when enabled. See the `gsd-atdd` skill for the full protocol.

## Code Navigation

Use the LSP tool for code navigation in TypeScript, Go, and Java projects. Prefer LSP (go to definition, find references, hover for types) over Grep for navigating code — it understands the type system and gives precise results.

## Practices

- Domain-Driven Design where applicable (ubiquitous language, bounded contexts, value objects)
- Functional patterns preferred (immutability, pure functions, composition)
- TypeScript strict mode on TS projects

## Style

- Be direct. Implementation-level answers, not marketing copy.
- Don't sugarcoat assessments. If something is wrong, say so.
- When I ask about a tool or framework, look at the actual implementation, not what the docs claim.

## Skills Update

Standalone skills in `~/.claude/skills/` are manually managed. To update them, check the source repos:
- https://github.com/citypaul/.dotfiles (tdd, testing, mutation-testing, functional, typescript-strict, front-end-testing, react-testing, refactoring, planning, expectations, ci-debugging, best-practices, accessibility, performance, domain-driven-design, hexagonal-architecture, test-design-reviewer)
- MCP builder, claude-md-improver, find-skills are symlinks from `~/.agents/skills/`

Plugin-provided skills (superpowers, frontend-design, code-simplifier, claude-md-management) auto-update with their plugins.
