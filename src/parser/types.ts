'worklet';

import type {MarkdownRange, MarkdownType} from '../commonTypes';

/**
 * Information about a single line in the source text.
 */
export interface LineInfo {
  /** Line content without the newline character */
  text: string;
  /** Byte offset of line start in source */
  start: number;
  /** Byte offset of line end (before newline) */
  end: number;
  /** Line number (0-indexed) */
  lineNumber: number;
}

/**
 * A block-level element in the document.
 */
export interface Block {
  /** Block type identifier */
  type: string;
  /** Position of block start in source (including syntax) */
  start: number;
  /** Position of block end in source */
  end: number;
  /** Where inline content begins (after syntax markers) */
  contentStart: number;
  /** Where inline content ends */
  contentEnd: number;
  /** Child blocks (for containers like blockquotes, lists) */
  children: Block[];
  /** Ranges for block-level syntax markers */
  syntaxRanges: MarkdownRange[];
  /** Additional block-specific data */
  data?: Record<string, unknown>;
}

/**
 * Result of a block rule match.
 */
export interface BlockMatch {
  /** The type of block matched */
  type: string;
  /** Number of characters consumed from line start */
  consumed: number;
  /** Where content starts within the matched portion */
  contentOffset: number;
  /** Additional data from the match */
  data?: Record<string, unknown>;
}

/**
 * State maintained during block parsing.
 */
export interface BlockState {
  /** Stack of open container blocks */
  openBlocks: Block[];
  /** All completed blocks */
  blocks: Block[];
  /** Current line being processed */
  currentLine: LineInfo;
  /** All lines in the document */
  lines: LineInfo[];
  /** Current line index */
  lineIndex: number;
}

/**
 * A block parsing rule.
 */
export interface BlockRule {
  /** Rule identifier */
  name: string;
  /** Check if line starts this block type */
  match: (line: string, state: BlockState) => BlockMatch | null;
  /** Process matched block, return whether to continue to next line */
  process: (match: BlockMatch, state: BlockState, lineInfo: LineInfo) => boolean;
  /** Check if line continues this block (for multi-line blocks) */
  continues?: (line: string, block: Block, state: BlockState) => boolean;
  /** Called when block is closed */
  finalize?: (block: Block, state: BlockState) => void;
}

/**
 * Result of an inline rule match.
 */
export interface InlineMatch {
  /** Ranges produced by this match */
  ranges: MarkdownRange[];
  /** Number of characters consumed */
  consumed: number;
  /** Text content to append (may differ from consumed chars) */
  text: string;
}

/**
 * Context for inline parsing.
 */
export interface InlineContext {
  /** Full text being parsed */
  text: string;
  /** Offset to add to all positions (from parent block) */
  baseOffset: number;
  /** Accumulated ranges */
  ranges: MarkdownRange[];
  /** Current position in text */
  position: number;
  /** Accumulated output text */
  output: string;

  /** Emit a styled range */
  emit: (type: MarkdownType, start: number, length: number) => void;
  /** Emit a syntax marker range */
  emitSyntax: (start: number, length: number) => void;
  /** Append text to output */
  appendText: (text: string) => void;
  /** Advance position without emitting */
  advance: (count: number) => void;
}

/**
 * An inline parsing rule.
 */
export interface InlineRule {
  /** Rule identifier */
  name: string;
  /** Characters that trigger this rule */
  triggers: string[];
  /** Parse from current position, return match or null */
  parse: (text: string, pos: number, ctx: InlineContext) => InlineMatch | null;
}

/**
 * Parse result containing text and ranges.
 */
export interface ParseResult {
  /** The parsed text (should match input for valid markdown) */
  text: string;
  /** Styling ranges */
  ranges: MarkdownRange[];
}
