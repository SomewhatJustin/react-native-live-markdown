'worklet';

import type {BlockRule, BlockMatch, BlockState, Block, LineInfo} from './types';
import type {MarkdownRange} from '../commonTypes';
import {isBlankLine, removeLeadingSpaces} from './utils';

/**
 * Registry of block parsing rules.
 * Rules are checked in order - first match wins.
 */
const blockRules: BlockRule[] = [];

/**
 * Register a block parsing rule.
 */
export function registerBlockRule(rule: BlockRule): void {
  blockRules.push(rule);
}

/**
 * Get all registered block rules.
 */
export function getBlockRules(): BlockRule[] {
  return blockRules;
}

/**
 * Clear all registered block rules (for testing).
 */
export function clearBlockRules(): void {
  blockRules.length = 0;
}

// =============================================================================
// Built-in Block Rules
// =============================================================================

/**
 * ATX Heading: # heading, ## heading, etc.
 */
const atxHeadingRule: BlockRule = {
  name: 'atxHeading',

  match(line: string, _state: BlockState): BlockMatch | null {
    // Up to 3 spaces, then 1-6 # characters, then space or end of line
    const match = line.match(/^( {0,3})(#{1,6})(?:[ \t]+|$)/);
    if (!match) {
      return null;
    }

    const fullMatch = match[0]!;
    const indent = match[1]!;
    const hashes = match[2]!;
    const level = hashes.length;

    return {
      type: `h${level}`,
      consumed: fullMatch.length,
      contentOffset: fullMatch.length,
      data: {level, indentLength: indent.length, hashLength: hashes.length},
    };
  },

  process(match: BlockMatch, state: BlockState, lineInfo: LineInfo): boolean {
    const {level, indentLength, hashLength} = match.data as {level: number; indentLength: number; hashLength: number};
    const line = lineInfo.text;

    // Find content (may have trailing #s to remove)
    let content = line.substring(match.consumed);

    // Remove optional closing #s
    const closingMatch = content.match(/[ \t]+#+[ \t]*$/);
    let closingLength = 0;
    if (closingMatch) {
      closingLength = closingMatch[0].length;
      content = content.substring(0, content.length - closingLength);
    }

    // Trim trailing whitespace from content
    content = content.replace(/[ \t]+$/, '');

    const syntaxRanges: MarkdownRange[] = [];

    // Opening syntax: "# " or "## " etc.
    syntaxRanges.push({
      type: 'syntax',
      start: lineInfo.start + indentLength,
      length: hashLength + (match.consumed - indentLength - hashLength), // Include the space
    });

    // Closing syntax if present
    if (closingLength > 0) {
      syntaxRanges.push({
        type: 'syntax',
        start: lineInfo.start + line.length - closingLength,
        length: closingLength,
      });
    }

    const block: Block = {
      type: match.type,
      start: lineInfo.start,
      end: lineInfo.end,
      contentStart: lineInfo.start + match.consumed,
      contentEnd: lineInfo.start + line.length - closingLength,
      children: [],
      syntaxRanges,
      data: {level},
    };

    state.blocks.push(block);
    return false; // Headings are single-line, don't continue
  },
};

// MVP: Thematic breaks disabled - re-enable when ready
// /**
//  * Thematic break: ---, ***, ___
//  */
// const thematicBreakRule: BlockRule = {
//   name: 'thematicBreak',
//
//   match(line: string, _state: BlockState): BlockMatch | null {
//     // Up to 3 spaces, then 3+ of same char (-, *, _) with optional spaces between
//     const match = line.match(/^( {0,3})([-*_])(?:[ \t]*\2){2,}[ \t]*$/);
//     if (!match) {
//       return null;
//     }
//
//     return {
//       type: 'thematic-break',
//       consumed: line.length,
//       contentOffset: line.length,
//       data: {char: match[2]},
//     };
//   },
//
//   process(_match: BlockMatch, state: BlockState, lineInfo: LineInfo): boolean {
//     const block: Block = {
//       type: 'thematic-break',
//       start: lineInfo.start,
//       end: lineInfo.end,
//       contentStart: lineInfo.end,
//       contentEnd: lineInfo.end,
//       children: [],
//       syntaxRanges: [
//         {
//           type: 'syntax',
//           start: lineInfo.start,
//           length: lineInfo.text.length,
//         },
//       ],
//     };
//
//     state.blocks.push(block);
//     return false;
//   },
// };

/**
 * Fenced code block: ``` or ~~~
 */
const fencedCodeRule: BlockRule = {
  name: 'fencedCode',

  match(line: string, _state: BlockState): BlockMatch | null {
    // Up to 3 spaces, then 3+ backticks or tildes
    const match = line.match(/^( {0,3})(`{3,}|~{3,})([^`]*)$/);
    if (!match) {
      return null;
    }

    const indent = match[1]!;
    const fence = match[2]!;
    const info = match[3] || '';

    return {
      type: 'fencedCode',
      consumed: line.length,
      contentOffset: line.length,
      data: {
        fenceChar: fence[0]!,
        fenceLength: fence.length,
        indentLength: indent.length,
        info: info.trim(),
      },
    };
  },

  process(match: BlockMatch, state: BlockState, lineInfo: LineInfo): boolean {
    const {fenceChar, fenceLength, indentLength, info} = match.data as {
      fenceChar: string;
      fenceLength: number;
      indentLength: number;
      info: string;
    };

    const block: Block = {
      type: 'pre',
      start: lineInfo.start,
      end: lineInfo.end,
      contentStart: lineInfo.end + 1, // Content starts on next line
      contentEnd: lineInfo.end + 1,
      children: [],
      syntaxRanges: [],
      data: {fenceChar, fenceLength, indentLength, info, isOpen: true},
    };

    // Opening fence syntax
    block.syntaxRanges.push({
      type: 'syntax',
      start: lineInfo.start,
      length: lineInfo.text.length,
    });

    state.openBlocks.push(block);
    return true; // Continue to find closing fence
  },

  continues(line: string, block: Block, _state: BlockState): boolean {
    const {fenceChar, fenceLength} = block.data as {
      fenceChar: string;
      fenceLength: number;
    };

    // Check for closing fence
    const stripped = removeLeadingSpaces(line, 3);
    const closeMatch = stripped.match(new RegExp(`^(${fenceChar}{${fenceLength},})[ \\t]*$`));

    if (closeMatch) {
      return false; // Block is closed
    }

    return true; // Continue the block
  },

  finalize(block: Block, _state: BlockState): void {
    block.data = {...block.data, isOpen: false};
  },
};

/**
 * Blockquote: > quoted text
 */
const blockquoteRule: BlockRule = {
  name: 'blockquote',

  match(line: string, _state: BlockState): BlockMatch | null {
    // Up to 3 spaces, then >
    const match = line.match(/^( {0,3})>[ ]?/);
    if (!match) {
      return null;
    }

    return {
      type: 'blockquote',
      consumed: match[0].length,
      contentOffset: match[0].length,
    };
  },

  process(match: BlockMatch, state: BlockState, lineInfo: LineInfo): boolean {
    // Check if we're continuing an existing blockquote
    const lastOpen = state.openBlocks[state.openBlocks.length - 1];

    if (lastOpen && lastOpen.type === 'blockquote') {
      // Continue existing blockquote
      lastOpen.end = lineInfo.end;
      lastOpen.contentEnd = lineInfo.end;
      return true;
    }

    // Start new blockquote
    const block: Block = {
      type: 'blockquote',
      start: lineInfo.start,
      end: lineInfo.end,
      contentStart: lineInfo.start + match.consumed,
      contentEnd: lineInfo.end,
      children: [],
      syntaxRanges: [
        {
          type: 'syntax',
          start: lineInfo.start,
          length: match.consumed,
        },
      ],
      data: {depth: 1},
    };

    state.openBlocks.push(block);
    return true;
  },

  continues(line: string, _block: Block, _state: BlockState): boolean {
    // Blockquote continues if line starts with >
    return /^( {0,3})>/.test(line);
  },
};

/**
 * Paragraph: default block type for text
 */
const paragraphRule: BlockRule = {
  name: 'paragraph',

  match(line: string, _state: BlockState): BlockMatch | null {
    // Paragraph matches any non-blank line
    if (isBlankLine(line)) {
      return null;
    }

    return {
      type: 'paragraph',
      consumed: 0,
      contentOffset: 0,
    };
  },

  process(_match: BlockMatch, state: BlockState, lineInfo: LineInfo): boolean {
    // Check if we're continuing an existing paragraph
    const lastOpen = state.openBlocks[state.openBlocks.length - 1];

    if (lastOpen && lastOpen.type === 'paragraph') {
      // Continue existing paragraph
      lastOpen.end = lineInfo.end;
      lastOpen.contentEnd = lineInfo.end;
      return true;
    }

    // Start new paragraph
    const block: Block = {
      type: 'paragraph',
      start: lineInfo.start,
      end: lineInfo.end,
      contentStart: lineInfo.start,
      contentEnd: lineInfo.end,
      children: [],
      syntaxRanges: [],
    };

    state.openBlocks.push(block);
    return true;
  },

  continues(line: string, _block: Block, state: BlockState): boolean {
    // Paragraph continues if line is not blank and doesn't start another block
    if (isBlankLine(line)) {
      return false;
    }

    // Check if another block rule would match
    for (const rule of blockRules) {
      if (rule.name === 'paragraph') continue;
      if (rule.match(line, state)) {
        return false;
      }
    }

    return true;
  },
};

// Register built-in rules in priority order
registerBlockRule(atxHeadingRule);
// registerBlockRule(thematicBreakRule); // MVP: disabled
registerBlockRule(fencedCodeRule);
registerBlockRule(blockquoteRule);
registerBlockRule(paragraphRule);

export {atxHeadingRule, /* thematicBreakRule, */ fencedCodeRule, blockquoteRule, paragraphRule};
