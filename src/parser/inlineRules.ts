'worklet';

import type {InlineRule, InlineMatch, InlineContext} from './types';
import type {MarkdownRange} from '../commonTypes';
import {isAsciiPunctuation, isUnicodeWhitespace, findLinkDestinationEnd, findLinkTitleEnd} from './utils';

/**
 * Registry of inline parsing rules.
 * Rules are looked up by trigger character.
 * Using plain object instead of Map for worklet compatibility.
 */
const inlineRules: Record<string, InlineRule[]> = {};

/**
 * Register an inline parsing rule.
 */
export function registerInlineRule(rule: InlineRule): void {
  for (const trigger of rule.triggers) {
    if (!inlineRules[trigger]) {
      inlineRules[trigger] = [];
    }
    inlineRules[trigger]!.push(rule);
  }
}

/**
 * Get rules for a trigger character.
 */
export function getRulesForTrigger(trigger: string): InlineRule[] {
  return inlineRules[trigger] || [];
}

/**
 * Get all trigger characters.
 */
export function getTriggers(): string[] {
  return Object.keys(inlineRules);
}

/**
 * Clear all registered inline rules (for testing).
 */
export function clearInlineRules(): void {
  for (const key of Object.keys(inlineRules)) {
    delete inlineRules[key];
  }
}

// =============================================================================
// Built-in Inline Rules
// =============================================================================

/**
 * Code span: `code` or ``code with `backticks` ``
 */
const codeSpanRule: InlineRule = {
  name: 'codeSpan',
  triggers: ['`'],

  parse(text: string, pos: number, ctx: InlineContext): InlineMatch | null {
    // Count opening backticks
    let openCount = 0;
    let i = pos;
    while (i < text.length && text[i] === '`') {
      openCount++;
      i++;
    }

    if (openCount === 0) {
      return null;
    }

    // Find matching closing backticks
    const closePattern = '`'.repeat(openCount);
    let searchPos = i;

    while (searchPos < text.length) {
      const closeIndex = text.indexOf(closePattern, searchPos);
      if (closeIndex === -1) {
        return null; // No matching close
      }

      // Make sure we have exactly the right number of backticks
      let closeEnd = closeIndex + openCount;
      while (closeEnd < text.length && text[closeEnd] === '`') {
        closeEnd++;
      }

      if (closeEnd - closeIndex === openCount) {
        // Found matching close
        let content = text.substring(i, closeIndex);

        // Strip one leading and trailing space if both present and content is not all spaces
        if (content.length >= 2 && content[0] === ' ' && content[content.length - 1] === ' ' && !/^ +$/.test(content)) {
          content = content.substring(1, content.length - 1);
        }

        // Collapse internal whitespace to single spaces
        content = content.replace(/[\n\r]+/g, ' ');

        const ranges: MarkdownRange[] = [
          {type: 'syntax', start: ctx.baseOffset + pos, length: openCount},
          {type: 'code', start: ctx.baseOffset + i, length: closeIndex - i},
          {type: 'syntax', start: ctx.baseOffset + closeIndex, length: openCount},
        ];

        return {
          ranges,
          consumed: closeEnd - pos,
          text: '`'.repeat(openCount) + content + '`'.repeat(openCount),
        };
      }

      searchPos = closeEnd;
    }

    return null;
  },
};

/**
 * Emphasis: *italic*, **bold**, _italic_, __bold__
 *
 * This implements a simplified version of the CommonMark delimiter algorithm.
 */
const emphasisRule: InlineRule = {
  name: 'emphasis',
  triggers: ['*', '_'],

  parse(text: string, pos: number, ctx: InlineContext): InlineMatch | null {
    const char = text[pos];
    if (char !== '*' && char !== '_') {
      return null;
    }

    // Count delimiter run
    let runLength = 0;
    let i = pos;
    while (i < text.length && text[i] === char) {
      runLength++;
      i++;
    }

    // Check if this can be an opener
    const charBefore: string = pos > 0 ? text[pos - 1]! : ' ';
    const charAfter: string = i < text.length ? text[i]! : ' ';

    const leftFlanking =
      !isUnicodeWhitespace(charAfter) && (!isAsciiPunctuation(charAfter) || isUnicodeWhitespace(charBefore) || isAsciiPunctuation(charBefore));

    const rightFlanking =
      !isUnicodeWhitespace(charBefore) && (!isAsciiPunctuation(charBefore) || isUnicodeWhitespace(charAfter) || isAsciiPunctuation(charAfter));

    // _ has additional restrictions
    const canOpen = char === '*' ? leftFlanking : leftFlanking && (!rightFlanking || isAsciiPunctuation(charBefore));

    if (!canOpen) {
      return null;
    }

    // Look for closing delimiter
    // For simplicity, we do a greedy search for matching delimiters
    const isDouble = runLength >= 2;
    const delimCount = isDouble ? 2 : 1;
    const closeDelim = char.repeat(delimCount);

    // Find closing delimiter
    let searchPos = i;
    while (searchPos < text.length) {
      const closeIndex = text.indexOf(closeDelim, searchPos);
      if (closeIndex === -1) {
        break;
      }

      // Check if this can be a closer
      const beforeClose: string = closeIndex > 0 ? text[closeIndex - 1]! : ' ';
      const afterClose: string = closeIndex + delimCount < text.length ? text[closeIndex + delimCount]! : ' ';

      const closeRightFlanking =
        !isUnicodeWhitespace(beforeClose) && (!isAsciiPunctuation(beforeClose) || isUnicodeWhitespace(afterClose) || isAsciiPunctuation(afterClose));

      const canClose = char === '*' ? closeRightFlanking : closeRightFlanking && (!leftFlanking || isAsciiPunctuation(afterClose));

      if (canClose) {
        // Make sure it's exactly the right number of delimiters (not more)
        let closeEnd = closeIndex + delimCount;
        let extraDelims = 0;
        while (closeEnd < text.length && text[closeEnd] === char) {
          extraDelims++;
          closeEnd++;
        }

        // If there are extra delimiters, they should be counted separately
        // For now, we match greedily with just the delimiters we need

        const content = text.substring(i, closeIndex);
        const type = isDouble ? 'bold' : 'italic';
        const syntaxChar = isDouble ? char + char : char;

        const ranges: MarkdownRange[] = [
          {type: 'syntax', start: ctx.baseOffset + pos, length: delimCount},
          {type, start: ctx.baseOffset + i, length: content.length},
          {type: 'syntax', start: ctx.baseOffset + closeIndex, length: delimCount},
        ];

        return {
          ranges,
          consumed: closeIndex + delimCount - pos,
          text: syntaxChar + content + syntaxChar,
        };
      }

      searchPos = closeIndex + 1;
    }

    return null;
  },
};

/**
 * Link: [text](url) or [text](url "title")
 */
const linkRule: InlineRule = {
  name: 'link',
  triggers: ['['],

  parse(text: string, pos: number, ctx: InlineContext): InlineMatch | null {
    if (text[pos] !== '[') {
      return null;
    }

    // Find closing ]
    let bracketDepth = 1;
    let i = pos + 1;

    while (i < text.length && bracketDepth > 0) {
      if (text[i] === '\\' && i + 1 < text.length) {
        i += 2;
        continue;
      }
      if (text[i] === '[') {
        bracketDepth++;
      } else if (text[i] === ']') {
        bracketDepth--;
      }
      i++;
    }

    if (bracketDepth !== 0) {
      return null;
    }

    const labelEnd = i - 1;
    const label = text.substring(pos + 1, labelEnd);

    // Must be followed by (
    if (i >= text.length || text[i] !== '(') {
      return null;
    }

    i++; // Skip (

    // Skip optional whitespace
    while (i < text.length && (text[i] === ' ' || text[i] === '\t' || text[i] === '\n')) {
      i++;
    }

    // Find destination
    const destEnd = findLinkDestinationEnd(text, i);
    if (destEnd === -1) {
      return null;
    }

    const destination = text.substring(i, destEnd);
    i = destEnd;

    // Skip optional whitespace
    while (i < text.length && (text[i] === ' ' || text[i] === '\t' || text[i] === '\n')) {
      i++;
    }

    // Optional title (we parse it but don't use it in ranges currently)
    if (i < text.length && (text[i] === '"' || text[i] === "'" || text[i] === '(')) {
      const titleEnd = findLinkTitleEnd(text, i);
      if (titleEnd !== -1) {
        // Skip over the title
        i = titleEnd;

        // Skip optional whitespace after title
        while (i < text.length && (text[i] === ' ' || text[i] === '\t' || text[i] === '\n')) {
          i++;
        }
      }
    }

    // Must end with )
    if (i >= text.length || text[i] !== ')') {
      return null;
    }

    i++; // Skip )

    // Clean up destination (remove angle brackets if present)
    let cleanDest = destination;
    if (cleanDest.startsWith('<') && cleanDest.endsWith('>')) {
      cleanDest = cleanDest.substring(1, cleanDest.length - 1);
    }

    const ranges: MarkdownRange[] = [
      {type: 'syntax', start: ctx.baseOffset + pos, length: 1}, // [
      // Label content would get inline-parsed separately
      {type: 'syntax', start: ctx.baseOffset + labelEnd, length: 2}, // ](
      {type: 'link', start: ctx.baseOffset + pos + 1 + label.length + 2, length: cleanDest.length},
      {type: 'syntax', start: ctx.baseOffset + i - 1, length: 1}, // )
    ];

    const fullText = text.substring(pos, i);

    return {
      ranges,
      consumed: i - pos,
      text: fullText,
    };
  },
};

/**
 * Image: ![alt](url) or ![alt](url "title")
 */
const imageRule: InlineRule = {
  name: 'image',
  triggers: ['!'],

  parse(text: string, pos: number, ctx: InlineContext): InlineMatch | null {
    if (text[pos] !== '!' || pos + 1 >= text.length || text[pos + 1] !== '[') {
      return null;
    }

    // Use link rule logic starting from [
    const linkMatch = linkRule.parse(text, pos + 1, {
      ...ctx,
      baseOffset: ctx.baseOffset + 1,
    });

    if (!linkMatch) {
      return null;
    }

    // Adjust ranges for the leading !
    const adjustedRanges: MarkdownRange[] = [
      {type: 'syntax', start: ctx.baseOffset + pos, length: 1}, // !
      ...linkMatch.ranges.map((r) => ({
        ...r,
        start: r.start + 1,
      })),
    ];

    // Mark the whole thing as inline-image
    const totalLength = 1 + linkMatch.consumed;
    adjustedRanges.unshift({
      type: 'inline-image',
      start: ctx.baseOffset + pos,
      length: totalLength,
    });

    return {
      ranges: adjustedRanges,
      consumed: totalLength,
      text: '!' + linkMatch.text,
    };
  },
};

/**
 * Autolink: <url> or <email@example.com>
 */
const autolinkRule: InlineRule = {
  name: 'autolink',
  triggers: ['<'],

  parse(text: string, pos: number, ctx: InlineContext): InlineMatch | null {
    if (text[pos] !== '<') {
      return null;
    }

    // Find closing >
    const closeIndex = text.indexOf('>', pos + 1);
    if (closeIndex === -1) {
      return null;
    }

    const content = text.substring(pos + 1, closeIndex);

    // Check for URI autolink (absolute URI)
    const uriMatch = content.match(/^[a-zA-Z][a-zA-Z0-9+.-]{1,31}:[^\s<>]*$/);
    if (uriMatch) {
      return {
        ranges: [
          {type: 'syntax', start: ctx.baseOffset + pos, length: 1},
          {type: 'link', start: ctx.baseOffset + pos + 1, length: content.length},
          {type: 'syntax', start: ctx.baseOffset + closeIndex, length: 1},
        ],
        consumed: closeIndex - pos + 1,
        text: '<' + content + '>',
      };
    }

    // Check for email autolink
    const emailMatch = content.match(/^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/);
    if (emailMatch) {
      return {
        ranges: [
          {type: 'syntax', start: ctx.baseOffset + pos, length: 1},
          {type: 'link', start: ctx.baseOffset + pos + 1, length: content.length},
          {type: 'syntax', start: ctx.baseOffset + closeIndex, length: 1},
        ],
        consumed: closeIndex - pos + 1,
        text: '<' + content + '>',
      };
    }

    return null;
  },
};

/**
 * Hard line break: backslash at end of line or two+ spaces at end of line
 */
const hardBreakRule: InlineRule = {
  name: 'hardBreak',
  triggers: ['\\', ' '],

  parse(text: string, pos: number, ctx: InlineContext): InlineMatch | null {
    // Backslash before newline
    if (text[pos] === '\\' && pos + 1 < text.length && text[pos + 1] === '\n') {
      return {
        ranges: [{type: 'syntax', start: ctx.baseOffset + pos, length: 1}],
        consumed: 2,
        text: '\\\n',
      };
    }

    // Two or more spaces before newline
    if (text[pos] === ' ') {
      let spaceCount = 0;
      let i = pos;
      while (i < text.length && text[i] === ' ') {
        spaceCount++;
        i++;
      }

      if (spaceCount >= 2 && i < text.length && text[i] === '\n') {
        return {
          ranges: [{type: 'syntax', start: ctx.baseOffset + pos, length: spaceCount}],
          consumed: spaceCount + 1,
          text: ' '.repeat(spaceCount) + '\n',
        };
      }
    }

    return null;
  },
};

// Register built-in rules
registerInlineRule(codeSpanRule);
registerInlineRule(emphasisRule);
registerInlineRule(linkRule);
registerInlineRule(imageRule);
registerInlineRule(autolinkRule);
registerInlineRule(hardBreakRule);

export {codeSpanRule, emphasisRule, linkRule, imageRule, autolinkRule, hardBreakRule};
