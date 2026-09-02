/**
 * LiquidCalc Backend E2E Test Suite - Common Utilities & Assertions
 */

export const colors = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  cyan: '\x1b[36m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  magenta: '\x1b[35m',
  blue: '\x1b[34m',
  gray: '\x1b[90m',
};

export class AssertionError extends Error {
  constructor(message, actual, expected) {
    super(message);
    this.name = 'AssertionError';
    this.actual = actual;
    this.expected = expected;
  }
}

export function assert(condition, message = 'Assertion failed') {
  if (!condition) {
    throw new AssertionError(message, condition, true);
  }
}

export function assertEqual(actual, expected, message = '') {
  if (actual !== expected) {
    throw new AssertionError(
      `${message || 'Values not strictly equal'}\n  Expected: ${JSON.stringify(expected)}\n  Actual:   ${JSON.stringify(actual)}`,
      actual,
      expected
    );
  }
}

export function assertDeepEqual(actual, expected, message = '') {
  const actualStr = JSON.stringify(actual);
  const expectedStr = JSON.stringify(expected);
  if (actualStr !== expectedStr) {
    throw new AssertionError(
      `${message || 'Deep equality mismatch'}\n  Expected: ${expectedStr}\n  Actual:   ${actualStr}`,
      actual,
      expected
    );
  }
}

export function assertIncludes(actual, search, message = '') {
  if (typeof actual === 'string') {
    if (!actual.includes(search)) {
      throw new AssertionError(
        `${message || 'String does not include substring'}\n  Expected to include: ${JSON.stringify(search)}\n  In: ${JSON.stringify(actual.slice(0, 200))}`,
        actual,
        search
      );
    }
  } else if (Array.isArray(actual)) {
    if (!actual.includes(search)) {
      throw new AssertionError(
        `${message || 'Array does not include item'}\n  Expected item: ${JSON.stringify(search)}`,
        actual,
        search
      );
    }
  } else {
    throw new AssertionError('assertIncludes target must be a string or array', actual, search);
  }
}

export function assertMatches(actual, regex, message = '') {
  if (!regex.test(actual)) {
    throw new AssertionError(
      `${message || 'Regex pattern did not match'}\n  Pattern:  ${regex.toString()}\n  Actual:   ${JSON.stringify(actual)}`,
      actual,
      regex.toString()
    );
  }
}

export function assertStatus(response, expectedStatus, message = '') {
  if (response.status !== expectedStatus) {
    throw new AssertionError(
      `${message || 'HTTP Status code mismatch'}\n  Expected: ${expectedStatus}\n  Actual:   ${response.status} (${response.statusText})`,
      response.status,
      expectedStatus
    );
  }
}

export function assertValidXml(xmlString, message = '') {
  assert(typeof xmlString === 'string' && xmlString.trim().length > 0, 'XML must be non-empty string');
  assert(xmlString.includes('<?xml') || xmlString.includes('<!DOCTYPE') || xmlString.includes('<plist'), `${message} XML must have valid XML declaration or root tag`);
  
  // Basic tag matching check for well-formedness
  const tags = [];
  const tagRegex = /<(\/)?([a-zA-Z0-9_-]+)(\s+[^>]*)?(\/)?>/g;
  let match;
  while ((match = tagRegex.exec(xmlString)) !== null) {
    const isClosing = match[1] === '/';
    const tagName = match[2];
    const isSelfClosing = match[4] === '/' || ['br', 'hr', 'img', 'input'].includes(tagName.toLowerCase());
    
    if (match[0].startsWith('<?') || match[0].startsWith('<!')) {
      continue;
    }
    
    if (isSelfClosing) {
      continue;
    }
    
    if (!isClosing) {
      tags.push(tagName);
    } else {
      const lastTag = tags.pop();
      if (lastTag !== tagName) {
        throw new AssertionError(
          `${message || 'XML malformed: unmatched tag'}\n  Expected </${lastTag}> but found </${tagName}>`,
          tagName,
          lastTag
        );
      }
    }
  }
  
  if (tags.length > 0) {
    throw new AssertionError(
      `${message || 'XML malformed: unclosed tags remaining'}: ${tags.join(', ')}`,
      tags,
      []
    );
  }
}

export async function fetchWithTimeout(url, options = {}, timeoutMs = 15000) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  
  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    return response;
  } catch (err) {
    if (err.name === 'AbortError') {
      throw new Error(`Request to ${url} timed out after ${timeoutMs}ms`);
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }
}

export async function readSSEStream(response, maxChunks = 50, timeoutMs = 15000) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  const chunks = [];
  let fullText = '';
  let doneReceived = false;
  
  const startTime = Date.now();
  
  while (chunks.length < maxChunks && Date.now() - startTime < timeoutMs) {
    const { done, value } = await reader.read();
    if (done) break;
    
    const chunkText = decoder.decode(value, { stream: true });
    fullText += chunkText;
    
    const lines = chunkText.split('\n');
    for (const line of lines) {
      if (line.startsWith('data:')) {
        const jsonStr = line.replace(/^data:\s*/, '').trim();
        if (jsonStr) {
          try {
            const parsed = JSON.parse(jsonStr);
            chunks.push(parsed);
            if (parsed.done === true) {
              doneReceived = true;
            }
          } catch {
            chunks.push({ raw: jsonStr });
          }
        }
      }
    }
    if (doneReceived) break;
  }
  
  return { chunks, fullText, doneReceived };
}

export async function measureTime(fn) {
  const start = performance.now();
  const result = await fn();
  const durationMs = Math.round(performance.now() - start);
  return { result, durationMs };
}
