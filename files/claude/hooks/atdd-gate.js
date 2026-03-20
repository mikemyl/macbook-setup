#!/usr/bin/env node
// ATDD Gate — PreToolUse hook
//
// Hard enforcement: blocks SUMMARY.md writes unless acceptance tests have passed.
// Optionally blocks phase completion without mutation testing score above threshold.
//
// Enforcement: exit 2 = block tool call (same convention as pre-tool-guard.sh)
// Silent pass: exit 0 = allow tool call
//
// Marker files (written by executor/verifier per gsd-atdd skill):
//   {phase_dir}/.tests-passed     — written after acceptance tests pass
//   {phase_dir}/.mutation-passed  — written after mutation score meets threshold
//
// Configuration: .planning/config.json → atdd.enabled = true
// When atdd is not enabled or .planning/ doesn't exist, this hook is a no-op.

'use strict';

const fs = require('fs');
const path = require('path');

const STALE_MINUTES = 120;

let input = '';
const stdinTimeout = setTimeout(() => process.exit(0), 3000);
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  try {
    const data = JSON.parse(input);
    const toolName = data.tool_name;

    // Only gate Write and Edit
    if (toolName !== 'Write' && toolName !== 'Edit') {
      process.exit(0);
    }

    const filePath = data.tool_input?.file_path || data.tool_input?.path || '';

    // Only gate SUMMARY.md files inside .planning/
    if (!filePath.includes('SUMMARY.md') || !filePath.includes('.planning')) {
      process.exit(0);
    }

    const cwd = data.cwd || process.cwd();

    // Load ATDD config
    const configPath = path.join(cwd, '.planning', 'config.json');
    let config = {};
    if (fs.existsSync(configPath)) {
      try {
        config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      } catch (e) {
        process.exit(0); // Don't block on config parse errors
      }
    }

    if (!config.atdd?.enabled) {
      process.exit(0);
    }

    // Resolve phase directory from SUMMARY.md path
    const absPath = filePath.startsWith('/') ? filePath : path.join(cwd, filePath);
    const phaseDir = path.dirname(absPath);
    const relPhaseDir = path.relative(cwd, phaseDir);

    // ── Gate 1: Acceptance tests must have passed ──────────────────────────
    const testsMarker = path.join(phaseDir, '.tests-passed');

    if (!fs.existsSync(testsMarker)) {
      process.stdout.write(
        'ATDD GATE: Cannot write SUMMARY.md \u2014 acceptance tests have not passed.\n\n' +
        'Expected marker: ' + relPhaseDir + '/.tests-passed\n\n' +
        'Before writing SUMMARY.md you must:\n' +
        '  1. Run the acceptance tests defined in the plan\'s acceptance_scenarios\n' +
        '  2. Verify ALL tests pass\n' +
        '  3. Write the marker file to ' + relPhaseDir + '/.tests-passed\n\n' +
        'Then retry writing the SUMMARY.md.'
      );
      process.exit(2);
    }

    // Check marker freshness
    const testsAge = (Date.now() - fs.statSync(testsMarker).mtimeMs) / 1000 / 60;
    if (testsAge > STALE_MINUTES) {
      process.stdout.write(
        'ATDD GATE: Acceptance test marker is stale (' + Math.round(testsAge) + ' minutes old).\n\n' +
        'Re-run acceptance tests and update the marker before writing SUMMARY.md.'
      );
      process.exit(2);
    }

    // ── Gate 2: Mutation testing (if enabled) ──────────────────────────────
    if (config.atdd?.mutation?.enabled && config.atdd?.mutation?.on_phase_complete) {
      // Only enforce on the last summary in the phase
      let plans = 0;
      let summaries = 0;
      try {
        const files = fs.readdirSync(phaseDir);
        plans = files.filter(f => f.includes('-PLAN.md')).length;
        // +1 because the current SUMMARY is about to be written
        summaries = files.filter(f => f.includes('-SUMMARY.md')).length + 1;
      } catch (e) {}

      if (summaries >= plans && plans > 0) {
        const mutationMarker = path.join(phaseDir, '.mutation-passed');
        const threshold = config.atdd.mutation.threshold || 80;
        const cmd = config.atdd.mutation.command || 'npx stryker run';

        if (!fs.existsSync(mutationMarker)) {
          process.stdout.write(
            'ATDD GATE: Last plan in phase \u2014 mutation testing is required.\n\n' +
            'Expected marker: ' + relPhaseDir + '/.mutation-passed\n\n' +
            'Run mutation testing before completing this phase:\n' +
            '  ' + cmd + '\n' +
            'Minimum score: ' + threshold + '%\n\n' +
            'Write the marker with the score, then retry.'
          );
          process.exit(2);
        }

        // Verify score meets threshold
        try {
          const mutData = JSON.parse(fs.readFileSync(mutationMarker, 'utf8'));
          if (typeof mutData.score === 'number' && mutData.score < threshold) {
            process.stdout.write(
              'ATDD GATE: Mutation score ' + mutData.score + '% is below threshold ' + threshold + '%.\n\n' +
              'Surviving mutants indicate weak or missing tests.\n' +
              'Strengthen assertions or add missing test cases before completing.'
            );
            process.exit(2);
          }
        } catch (e) {
          // Unparseable marker — warn but allow
          const output = {
            hookSpecificOutput: {
              hookEventName: 'PreToolUse',
              additionalContext: 'ATDD WARNING: Could not parse ' + relPhaseDir +
                '/.mutation-passed. Verify mutation testing results manually.'
            }
          };
          process.stdout.write(JSON.stringify(output));
          process.exit(0);
        }

        // Check mutation marker freshness
        const mutAge = (Date.now() - fs.statSync(mutationMarker).mtimeMs) / 1000 / 60;
        if (mutAge > STALE_MINUTES) {
          process.stdout.write(
            'ATDD GATE: Mutation testing marker is stale (' + Math.round(mutAge) + ' minutes old).\n\n' +
            'Re-run mutation testing and update the marker before completing the phase.'
          );
          process.exit(2);
        }
      }
    }

    // All gates passed
    process.exit(0);
  } catch (e) {
    // Silent fail — never block on hook errors
    process.exit(0);
  }
});
