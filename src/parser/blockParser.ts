'worklet';

import type {Block, BlockState} from './types';
import type {MarkdownRange} from '../commonTypes';
import {getBlockRules} from './blockRules';
import {splitLines, isBlankLine} from './utils';

/**
 * Parse block structure from markdown input.
 * Returns a list of top-level blocks with their positions and syntax ranges.
 */
export function parseBlocks(input: string): Block[] {
  const lines = splitLines(input);
  const rules = getBlockRules();

  const state: BlockState = {
    openBlocks: [],
    blocks: [],
    currentLine: lines[0] || {text: '', start: 0, end: 0, lineNumber: 0},
    lines,
    lineIndex: 0,
  };

  for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    const lineInfo = lines[lineIndex]!;
    state.currentLine = lineInfo;
    state.lineIndex = lineIndex;

    // Handle blank lines
    if (isBlankLine(lineInfo.text)) {
      // Close any open blocks that don't continue through blank lines
      closeOpenBlocks(state, true);
      continue;
    }

    // Check if any open blocks continue
    let continuedBlock = false;
    for (let i = state.openBlocks.length - 1; i >= 0; i--) {
      const block = state.openBlocks[i]!;
      const rule = rules.find((r) => r.name === block.type || r.name === getBlockRuleName(block.type));

      if (rule && rule.continues) {
        if (rule.continues(lineInfo.text, block, state)) {
          // Update block end position
          block.end = lineInfo.end;
          block.contentEnd = lineInfo.end;

          // Add syntax range for blockquote continuation
          if (block.type === 'blockquote') {
            const match = lineInfo.text.match(/^( {0,3})>[ ]?/);
            if (match) {
              block.syntaxRanges.push({
                type: 'syntax',
                start: lineInfo.start,
                length: match[0].length,
              });
            }
          }

          continuedBlock = true;
          break;
        } else {
          // Close this block
          closeBlock(state, i);
        }
      }
    }

    if (continuedBlock) {
      continue;
    }

    // Try to match a new block
    let matched = false;
    for (const rule of rules) {
      const match = rule.match(lineInfo.text, state);
      if (match) {
        const shouldContinue = rule.process(match, state, lineInfo);
        matched = true;

        if (!shouldContinue) {
          // Single-line block, close it if it was pushed to openBlocks
          const lastOpen = state.openBlocks[state.openBlocks.length - 1];
          if (lastOpen && lastOpen.type === match.type) {
            closeBlock(state, state.openBlocks.length - 1);
          }
        }
        break;
      }
    }

    if (!matched) {
      // This shouldn't happen if paragraph rule is registered as fallback
      console.warn('[parser] No block rule matched line:', lineInfo.text);
    }
  }

  // Close all remaining open blocks
  closeOpenBlocks(state, false);

  return state.blocks;
}

/**
 * Get the rule name from a block type.
 * Handles cases like h1, h2, etc. mapping to atxHeading.
 */
function getBlockRuleName(blockType: string): string {
  if (/^h[1-6]$/.test(blockType)) {
    return 'atxHeading';
  }
  if (blockType === 'pre') {
    return 'fencedCode';
  }
  return blockType;
}

/**
 * Close a specific open block by index.
 */
function closeBlock(state: BlockState, index: number): void {
  const rules = getBlockRules();
  const block = state.openBlocks[index];

  if (!block) {
    return;
  }

  // Call finalize if rule has it
  const rule = rules.find((r) => r.name === block.type || r.name === getBlockRuleName(block.type));
  if (rule && rule.finalize) {
    rule.finalize(block, state);
  }

  // Remove from open blocks and add to completed blocks
  state.openBlocks.splice(index, 1);
  state.blocks.push(block);
}

/**
 * Close all open blocks that should be closed.
 * @param blankLine - Whether this is due to a blank line
 */
function closeOpenBlocks(state: BlockState, blankLine: boolean): void {
  // Close from innermost to outermost
  for (let i = state.openBlocks.length - 1; i >= 0; i--) {
    const block = state.openBlocks[i]!;

    // Paragraphs are closed by blank lines
    if (blankLine && block.type === 'paragraph') {
      closeBlock(state, i);
      continue;
    }

    // Fenced code blocks continue through blank lines
    if (block.type === 'pre' && block.data?.isOpen) {
      continue;
    }

    // Close other blocks on blank lines
    if (blankLine) {
      closeBlock(state, i);
    }
  }
}

/**
 * Collect all ranges from blocks.
 */
export function collectBlockRanges(blocks: Block[]): MarkdownRange[] {
  const ranges: MarkdownRange[] = [];

  function collectFromBlock(block: Block): void {
    // Add block's own syntax ranges
    ranges.push(...block.syntaxRanges);

    // Add block type range (for non-paragraph blocks)
    if (block.type !== 'paragraph') {
      const typeRange: MarkdownRange = {
        type: block.type as any,
        start: block.start,
        length: block.end - block.start,
      };

      // Add depth for blockquotes
      if (block.type === 'blockquote' && block.data?.depth) {
        typeRange.depth = block.data.depth as number;
      }

      ranges.push(typeRange);
    }

    // Recurse into children
    for (const child of block.children) {
      collectFromBlock(child);
    }
  }

  for (const block of blocks) {
    collectFromBlock(block);
  }

  return ranges;
}
