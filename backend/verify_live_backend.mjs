#!/usr/bin/env node

/**
 * LiquidCalc Backend E2E Test Suite - Master Live Verification Runner
 *
 * Runs comprehensive opaque-box E2E test suites (Tier 1 to Tier 4) against
 * any local (http://localhost:3000) or live Vercel deployment (https://*.vercel.app).
 *
 * Usage:
 *   node backend/verify_live_backend.mjs --url https://liquidcalc.vercel.app
 *   node backend/verify_live_backend.mjs --url http://localhost:3000 --tier 1
 *   node backend/verify_live_backend.mjs --tier all --verbose
 */

import { colors, measureTime } from './tests/test_utils.mjs';
import { runTier1 } from './tests/tier1_features.mjs';
import { runTier2 } from './tests/tier2_boundaries.mjs';
import { runTier3 } from './tests/tier3_cross_feature.mjs';
import { runTier4 } from './tests/tier4_real_world.mjs';

function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    url: 'http://localhost:3000',
    tier: 'all',
    verbose: false,
    timeout: 15000,
    apiKey: process.env.GEMINI_API_KEY || '',
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--url' && args[i + 1]) {
      options.url = args[++i].replace(/\/$/, '');
    } else if (arg.startsWith('--url=')) {
      options.url = arg.split('=')[1].replace(/\/$/, '');
    } else if (arg === '--tier' && args[i + 1]) {
      options.tier = args[++i].toLowerCase();
    } else if (arg.startsWith('--tier=')) {
      options.tier = arg.split('=')[1].toLowerCase();
    } else if (arg === '--verbose' || arg === '-v') {
      options.verbose = true;
    } else if (arg === '--timeout' && args[i + 1]) {
      options.timeout = parseInt(args[++i], 10);
    } else if (arg === '--key' && args[i + 1]) {
      options.apiKey = args[++i];
    } else if (arg.startsWith('--key=')) {
      options.apiKey = arg.split('=')[1];
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    }
  }

  return options;
}

function printHelp() {
  console.log(`
${colors.cyan}${colors.bold}LiquidCalc Live Backend Verification Runner${colors.reset}

Options:
  --url <URL>        Target server URL (default: http://localhost:3000)
  --tier <TIER>      Run specific tier: 1, 2, 3, 4, or all (default: all)
  --key <KEY>        Gemini API key for AI endpoints (default: process.env.GEMINI_API_KEY)
  --timeout <MS>     Per-request timeout in milliseconds (default: 15000)
  --verbose, -v      Enable verbose logging of request details
  --help, -h         Show this help message

Examples:
  node verify_live_backend.mjs --url http://localhost:3000
  node verify_live_backend.mjs --url https://liquidcalc.vercel.app --tier all
  node verify_live_backend.mjs --tier 1 --verbose
`);
}

function printBanner(options) {
  console.log(`
${colors.cyan}╔════════════════════════════════════════════════════════════════════╗
║    ⚡ LIQUIDCALC SERVERLESS BACKEND LIVE VERIFICATION SUITE ⚡    ║
╚════════════════════════════════════════════════════════════════════╝${colors.reset}
${colors.gray}Target URL:${colors.reset}    ${colors.bold}${options.url}${colors.reset}
${colors.gray}Selected Tier:${colors.reset} ${colors.magenta}${options.tier.toUpperCase()}${colors.reset}
${colors.gray}Timeout:${colors.reset}       ${options.timeout}ms
${colors.gray}API Key:${colors.reset}       ${options.apiKey ? colors.green + 'Configured' + colors.reset : colors.yellow + 'Not Provided (Auth Fallbacks Exercised)' + colors.reset}
${colors.gray}Timestamp:${colors.reset}     ${new Date().toISOString()}
`);
}

async function executeTier(name, testFactory, baseUrl, options, stats) {
  console.log(`\n${colors.cyan}${colors.bold}─── [ ${name} ] ───────────────────────────────────────────${colors.reset}`);
  
  const tests = await testFactory(baseUrl, options);
  
  for (const test of tests) {
    process.stdout.write(`  ${colors.gray}•${colors.reset} ${test.name.padEnd(58)} `);
    
    try {
      const { result, durationMs } = await measureTime(async () => {
        return await test.run();
      });
      
      stats.passed++;
      stats.durations.push(durationMs);
      
      const noteStr = result && result.note ? ` ${colors.gray}(${result.note})${colors.reset}` : '';
      console.log(`${colors.green}✓ PASS${colors.reset} ${colors.dim}(${durationMs}ms)${colors.reset}${noteStr}`);
      
      if (options.verbose) {
        console.log(`    ${colors.gray}Desc: ${test.description}${colors.reset}`);
      }
    } catch (err) {
      stats.failed++;
      console.log(`${colors.red}✗ FAIL${colors.reset}`);
      console.log(`    ${colors.red}${colors.bold}Error:${colors.reset} ${err.message}`);
      if (options.verbose && err.stack) {
        console.log(`    ${colors.gray}${err.stack.split('\n').slice(1, 4).join('\n    ')}${colors.reset}`);
      }
    }
  }
}

async function main() {
  const options = parseArgs();
  printBanner(options);

  const startTime = performance.now();
  const stats = {
    passed: 0,
    failed: 0,
    skipped: 0,
    durations: [],
  };

  try {
    if (options.tier === 'all' || options.tier === '1') {
      await executeTier('TIER 1: Baseline Feature Coverage', runTier1, options.url, options, stats);
    }
    if (options.tier === 'all' || options.tier === '2') {
      await executeTier('TIER 2: Boundary & Corner Cases', runTier2, options.url, options, stats);
    }
    if (options.tier === 'all' || options.tier === '3') {
      await executeTier('TIER 3: Cross-Feature Combinations', runTier3, options.url, options, stats);
    }
    if (options.tier === 'all' || options.tier === '4') {
      await executeTier('TIER 4: Real-World Scenarios', runTier4, options.url, options, stats);
    }
  } catch (fatalError) {
    console.error(`\n${colors.red}${colors.bold}Fatal Suite Error:${colors.reset} ${fatalError.message}`);
    process.exit(1);
  }

  const totalTime = Math.round(performance.now() - startTime);
  const totalTests = stats.passed + stats.failed + stats.skipped;
  const avgLatency = stats.durations.length > 0
    ? Math.round(stats.durations.reduce((a, b) => a + b, 0) / stats.durations.length)
    : 0;
  const passRate = totalTests > 0 ? Math.round((stats.passed / totalTests) * 100) : 0;

  console.log(`
${colors.cyan}══════════════════════════════════════════════════════════════════════${colors.reset}
${colors.bold}VERIFICATION SUMMARY${colors.reset}
  ${colors.gray}Total Tests Run:${colors.reset}    ${colors.bold}${totalTests}${colors.reset}
  ${colors.gray}Passed:${colors.reset}            ${colors.green}${colors.bold}${stats.passed}${colors.reset}
  ${colors.gray}Failed:${colors.reset}            ${stats.failed > 0 ? colors.red + colors.bold + stats.failed : '0'}${colors.reset}
  ${colors.gray}Pass Rate:${colors.reset}          ${passRate === 100 ? colors.green : colors.yellow}${colors.bold}${passRate}%${colors.reset}
  ${colors.gray}Total Execution:${colors.reset}    ${totalTime}ms
  ${colors.gray}Average Latency:${colors.reset}    ${avgLatency}ms
${colors.cyan}══════════════════════════════════════════════════════════════════════${colors.reset}
`);

  if (stats.failed > 0) {
    console.log(`${colors.red}${colors.bold}💥 Live Verification FAILED with ${stats.failed} defect(s).${colors.reset}\n`);
    process.exit(1);
  } else {
    console.log(`${colors.green}${colors.bold}✨ All tests PASSED. LiquidCalc Backend is 100% verified & operational!${colors.reset}\n`);
    process.exit(0);
  }
}

main();
