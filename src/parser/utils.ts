'worklet';

import type {LineInfo} from './types';

/**
 * Split input text into lines with position information.
 */
export function splitLines(input: string): LineInfo[] {
  const lines: LineInfo[] = [];
  let lineNumber = 0;

  // Handle both \n and \r\n line endings
  let i = 0;
  while (i <= input.length) {
    const nextLF = input.indexOf('\n', i);
    const lineEnd = nextLF === -1 ? input.length : nextLF;

    // Check for \r\n
    let textEnd = lineEnd;
    if (lineEnd > 0 && input[lineEnd - 1] === '\r') {
      textEnd = lineEnd - 1;
    }

    lines.push({
      text: input.substring(i, textEnd),
      start: i,
      end: textEnd,
      lineNumber,
    });

    if (nextLF === -1) {
      break;
    }

    i = nextLF + 1;
    lineNumber++;
  }

  return lines;
}

/**
 * Check if a character is ASCII punctuation.
 */
export function isAsciiPunctuation(char: string): boolean {
  const code = char.charCodeAt(0);
  // !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~
  return (
    (code >= 0x21 && code <= 0x2f) || // !"#$%&'()*+,-./
    (code >= 0x3a && code <= 0x40) || // :;<=>?@
    (code >= 0x5b && code <= 0x60) || // [\]^_`
    (code >= 0x7b && code <= 0x7e) // {|}~
  );
}

/**
 * Check if a character is Unicode whitespace.
 */
export function isUnicodeWhitespace(char: string): boolean {
  const code = char.charCodeAt(0);
  // Space, tab, newline, form feed, carriage return
  return code === 0x20 || code === 0x09 || code === 0x0a || code === 0x0c || code === 0x0d;
}

/**
 * Check if a character is a Unicode whitespace character (broader definition).
 */
export function isWhitespaceChar(char: string): boolean {
  return /\s/.test(char);
}

/**
 * Count leading spaces in a string.
 */
export function countLeadingSpaces(str: string): number {
  let count = 0;
  for (let i = 0; i < str.length; i++) {
    if (str[i] === ' ') {
      count++;
    } else if (str[i] === '\t') {
      // Tab counts as up to 4 spaces to next tab stop
      count += 4 - (count % 4);
    } else {
      break;
    }
  }
  return count;
}

/**
 * Remove leading spaces/tabs from a string up to a maximum count.
 */
export function removeLeadingSpaces(str: string, maxSpaces: number): string {
  let removed = 0;
  let i = 0;

  while (i < str.length && removed < maxSpaces) {
    if (str[i] === ' ') {
      removed++;
      i++;
    } else if (str[i] === '\t') {
      const tabWidth = 4 - (removed % 4);
      if (removed + tabWidth <= maxSpaces) {
        removed += tabWidth;
        i++;
      } else {
        // Partial tab - we stop here
        break;
      }
    } else {
      break;
    }
  }

  return str.substring(i);
}

/**
 * Check if a string is blank (only whitespace).
 */
export function isBlankLine(str: string): boolean {
  for (let i = 0; i < str.length; i++) {
    const char = str[i];
    if (char !== ' ' && char !== '\t') {
      return false;
    }
  }
  return true;
}

/**
 * Escape special regex characters in a string.
 */
export function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Create a simple character set check function.
 */
export function createCharSet(chars: string): (char: string) => boolean {
  const set = new Set(chars.split(''));
  return (char: string) => set.has(char);
}

/**
 * Find the end of a link destination (URL).
 * Returns the index after the destination, or -1 if invalid.
 */
export function findLinkDestinationEnd(text: string, start: number): number {
  if (start >= text.length) {
    return -1;
  }

  // Angle-bracketed destination
  if (text[start] === '<') {
    for (let i = start + 1; i < text.length; i++) {
      const char = text[i];
      if (char === '>') {
        return i + 1;
      }
      if (char === '<' || char === '\n') {
        return -1;
      }
      if (char === '\\' && i + 1 < text.length) {
        i++; // Skip escaped character
      }
    }
    return -1;
  }

  // Regular destination (balanced parentheses)
  let parenDepth = 0;
  let i = start;

  while (i < text.length) {
    const char = text[i]!;

    if (isWhitespaceChar(char)) {
      break;
    }

    if (char === '\\' && i + 1 < text.length) {
      i += 2; // Skip escaped character
      continue;
    }

    if (char === '(') {
      parenDepth++;
    } else if (char === ')') {
      if (parenDepth === 0) {
        break;
      }
      parenDepth--;
    }

    i++;
  }

  if (parenDepth !== 0) {
    return -1;
  }

  return i;
}

/**
 * Find the end of a link title.
 * Returns the index after the title (including closing delimiter), or -1 if invalid.
 */
export function findLinkTitleEnd(text: string, start: number): number {
  if (start >= text.length) {
    return -1;
  }

  const delimiter = text[start];
  let closeDelimiter: string;

  if (delimiter === '"') {
    closeDelimiter = '"';
  } else if (delimiter === "'") {
    closeDelimiter = "'";
  } else if (delimiter === '(') {
    closeDelimiter = ')';
  } else {
    return -1;
  }

  for (let i = start + 1; i < text.length; i++) {
    const char = text[i];

    if (char === closeDelimiter) {
      return i + 1;
    }

    if (char === '\\' && i + 1 < text.length) {
      i++; // Skip escaped character
    }
  }

  return -1;
}
