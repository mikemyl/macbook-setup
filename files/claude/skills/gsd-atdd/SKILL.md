---
name: gsd-atdd
description: Enforces Acceptance Test Driven Development and mutation testing gates in GSD workflows. Loaded when planning, executing, or verifying GSD phases. Complements the tdd and mutation-testing skills with GSD-specific enforcement via marker files and the atdd-gate.js hook.
user-invocable: false
---

# ATDD Enforcement for GSD

This skill adds hard enforcement of acceptance testing and mutation testing to GSD workflows. It works alongside the `tdd` skill (red-green-refactor process) and `mutation-testing` skill (test effectiveness analysis) — load those for general patterns. This skill focuses on the GSD-specific enforcement protocol.

## Core Rule

**No implementation without acceptance scenarios. No SUMMARY.md without passing tests. No phase completion without mutation testing.**

This overrides any optional language about testing in GSD agent personas. The `atdd-gate.js` PreToolUse hook mechanically blocks SUMMARY.md writes without proof of passing tests (exit 2 = hard block). This skill tells agents how to satisfy the gate.

## Enforcement Architecture

```
Skill (this file)          → tells agents what to do (guidance)
atdd-gate.js hook          → blocks SUMMARY.md writes without markers (enforcement)
.tests-passed marker       → proof that acceptance tests passed
.mutation-passed marker    → proof that mutation score meets threshold
```

## Project Configuration

Projects opt in via `.planning/config.json`:

```json
{
  "atdd": {
    "enabled": true,
    "test_command": "npm test",
    "test_file_patterns": ["**/*.test.ts", "**/*.spec.ts"],
    "feature_file_patterns": ["**/*.feature"],
    "mutation": {
      "enabled": true,
      "command": "npx stryker run --mutate",
      "threshold": 80,
      "on_phase_complete": true
    }
  }
}
```

When `atdd.enabled` is false or absent, all enforcement is skipped (hook is a no-op).

---

## For the Planner

### Acceptance Scenarios in Plan Frontmatter

Every plan MUST include `acceptance_scenarios` in `must_haves`:

```yaml
must_haves:
  acceptance_scenarios:
    - scenario: "User can log in with valid credentials"
      given: "a registered user with email test@example.com"
      when: "they submit the login form with valid credentials"
      then: "they are redirected to the dashboard"
      test_file: "tests/auth/login.test.ts"
    - scenario: "Login fails with invalid password"
      given: "a registered user"
      when: "they submit the login form with wrong password"
      then: "they see an error message"
      test_file: "tests/auth/login.test.ts"
  truths:
    - "Login form submits credentials to /api/auth/login"
  artifacts:
    - path: "src/auth/login.ts"
```

### Wave 0 Rule

If acceptance test files don't exist yet, Wave 0 MUST create them as **failing tests**. Implementation waves MUST come strictly after test waves.

```
Wave 0: Create failing acceptance tests (RED — tests must fail)
Wave 1+: Implementation (GREEN — make tests pass)
```

Never put tests and implementation in the same wave.

### Planner Checklist (append to existing)

- [ ] Every plan has `acceptance_scenarios` in `must_haves`
- [ ] Every scenario has `given`, `when`, `then`, and `test_file`
- [ ] Wave 0 creates failing acceptance tests
- [ ] No implementation task shares a wave with its test task

---

## For the Executor

### Execution Order

1. **Read acceptance scenarios** from plan frontmatter
2. **Write failing tests** (RED) — create files from `test_file` fields
3. **Run tests — they MUST fail.** If tests pass before implementation, they are vacuous. Stop and fix them.
4. **Implement** — minimum code to make acceptance tests pass
5. **Run tests — they MUST pass** (GREEN)
6. **Write the `.tests-passed` marker:**

```bash
echo '{"timestamp":'$(date +%s)',"test_command":"<command>","scenarios_passed":<count>}' > <phase_dir>/.tests-passed
```

7. **Only then** write SUMMARY.md

The `atdd-gate.js` hook blocks the SUMMARY.md write if `.tests-passed` is missing or stale (> 2 hours). This is a hard block (exit 2), not a warning.

### Commit Convention

```
test(<phase>-<plan>): add failing acceptance tests for <feature>     # RED
feat(<phase>-<plan>): implement <feature>                            # GREEN
refactor(<phase>-<plan>): clean up <feature>                         # REFACTOR (optional)
```

---

## For the Verifier

### Mutation Testing Gate

Load the `mutation-testing` skill for operator analysis patterns and mutant classification guidance. Use those patterns to classify surviving mutants when the score is below threshold.

After goal-backward verification passes and acceptance tests are green:

1. Read mutation config from `.planning/config.json` (`atdd.mutation`)
2. Identify files changed in this phase (from plan `files_modified` or git diff)
3. Run: `{mutation_command} --mutate {changed_files}`
4. Compare mutation score against threshold (default: 80%)

**If score >= threshold**, write the `.mutation-passed` marker:

```bash
echo '{"score":<N>,"threshold":<N>,"timestamp":'$(date +%s)',"tool":"<tool>","killed":<N>,"survived":<N>,"no_coverage":<N>,"timeout":<N>}' > <phase_dir>/.mutation-passed
```

**If score < threshold**, report `gaps_found` with surviving mutants classified per the `mutation-testing` skill:

- **Weak assertion** (Survived) — test runs code but doesn't assert outcome → fix assertion
- **Missing test** (No Coverage) — no test covers this branch → write new test
- **Equivalent mutant** — mutation doesn't change observable behavior → document and skip

Weak assertions and missing tests enter the gap-closure cycle.

### Phase Completion Requirements

A phase CANNOT be marked complete unless:

1. `.tests-passed` marker exists for every plan in the phase
2. `.mutation-passed` marker exists in the phase dir (if mutation enabled)
3. Goal-backward verification passes (existing GSD requirement)

---

## Marker File Reference

| Marker | Written by | Checked by | Location | Required for |
|--------|-----------|------------|----------|-------------|
| `.tests-passed` | Executor | `atdd-gate.js` | `{phase_dir}/` | Writing SUMMARY.md |
| `.mutation-passed` | Verifier | `atdd-gate.js` | `{phase_dir}/` | Phase completion |

Both markers must be fresh (< 2 hours) to prevent stale results from passing the gate.
