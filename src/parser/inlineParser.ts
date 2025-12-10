'worklet';

import type {Block, InlineContext} from './types';
import type {MarkdownRange, MarkdownType} from '../commonTypes';
import {getRulesForTrigger, getTriggers} from './inlineRules';

/**
 * Parse inline content within a block.
 * Returns ranges for inline formatting.
 */
export function parseInlines(text: string, baseOffset: number): MarkdownRange[] {
  const ranges: MarkdownRange[] = [];
  const triggerList = getTriggers();
  // Use object for O(1) lookup instead of Set (worklet-compatible)
  const triggers: Record<string, boolean> = {};
  for (const t of triggerList) {
    triggers[t] = true;
  }

  const ctx: InlineContext = {
    text,
    baseOffset,
    ranges,
    position: 0,
    output: '',

    emit(type: MarkdownType, start: number, length: number) {
      ranges.push({type, start, length});
    },

    emitSyntax(start: number, length: number) {
      ranges.push({type: 'syntax', start, length});
    },

    appendText(t: string) {
      ctx.output += t;
    },

    advance(count: number) {
      ctx.position += count;
    },
  };

  let pos = 0;

  while (pos < text.length) {
    const char = text[pos]!;

    // Check if this character triggers any rules
    if (triggers[char]) {
      const rules = getRulesForTrigger(char);
      let matched = false;

      for (const rule of rules) {
        const match = rule.parse(text, pos, ctx);
        if (match) {
          // Add the ranges from the match
          ranges.push(...match.ranges);
          ctx.output += match.text;
          pos += match.consumed;
          matched = true;
          break;
        }
      }

      if (matched) {
        continue;
      }
    }

    // No rule matched, treat as plain text
    ctx.output += char;
    pos++;
  }

  ctx.position = pos;

  return ranges;
}

/**
 * Parse inline content for all blocks and return combined ranges.
 */
export function parseAllInlines(blocks: Block[], input: string): MarkdownRange[] {
  const allRanges: MarkdownRange[] = [];

  for (const block of blocks) {
    // Skip blocks that don't have inline content
    if (block.type === 'pre' || block.type === 'thematic-break') {
      continue;
    }

    // Get the inline content
    const contentStart = block.contentStart;
    const contentEnd = block.contentEnd;

    if (contentStart >= contentEnd) {
      continue;
    }

    const content = input.substring(contentStart, contentEnd);

    // Parse inlines within this block's content
    const inlineRanges = parseInlines(content, contentStart);
    allRanges.push(...inlineRanges);

    // Recurse into child blocks
    if (block.children.length > 0) {
      const childRanges = parseAllInlines(block.children, input);
      allRanges.push(...childRanges);
    }
  }

  return allRanges;
}

/**
 * Create the default inline context for parsing.
 */
export function createInlineContext(text: string, baseOffset: number): InlineContext {
  const ranges: MarkdownRange[] = [];

  return {
    text,
    baseOffset,
    ranges,
    position: 0,
    output: '',

    emit(type: MarkdownType, start: number, length: number) {
      ranges.push({type, start, length});
    },

    emitSyntax(start: number, length: number) {
      ranges.push({type: 'syntax', start, length});
    },

    appendText(t: string) {
      this.output += t;
    },

    advance(count: number) {
      this.position += count;
    },
  };
}
