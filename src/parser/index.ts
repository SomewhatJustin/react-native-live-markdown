'worklet';

import type {MarkdownRange, MarkdownType} from '../commonTypes';
import {sortRanges, groupRanges} from '../rangeUtils';

const MAX_PARSABLE_LENGTH = 500000;

/**
 * Parse markdown text and return styling ranges.
 * All parsing logic is inlined for worklet compatibility.
 */
function parseMarkdown(markdown: string): MarkdownRange[] {
  if (markdown.length === 0 || markdown.length > MAX_PARSABLE_LENGTH) {
    return [];
  }

  const ranges: MarkdownRange[] = [];

  // =========================================================================
  // BLOCK PARSING
  // =========================================================================
  const lines = markdown.split('\n');
  let pos = 0;
  let inCodeBlock = false;
  let codeBlockStart = 0;
  let codeBlockFence = '';

  for (let lineIdx = 0; lineIdx < lines.length; lineIdx++) {
    const line = lines[lineIdx]!;
    const lineStart = pos;
    const lineEnd = pos + line.length;

    // Fenced code block
    const fenceMatch = line.match(/^( {0,3})(`{3,}|~{3,})(.*)$/);
    if (fenceMatch) {
      const fence = fenceMatch[2]!;
      if (!inCodeBlock) {
        inCodeBlock = true;
        codeBlockStart = lineStart;
        codeBlockFence = fence[0]!;
        // Include newline in opening fence syntax range
        const fenceLength = lineIdx < lines.length - 1 ? line.length + 1 : line.length;
        ranges.push({type: 'syntax', start: lineStart, length: fenceLength});
      } else if (fence[0] === codeBlockFence && fence.length >= codeBlockFence.length) {
        // Include newline in closing fence syntax range and pre block range
        const fenceLength = lineIdx < lines.length - 1 ? line.length + 1 : line.length;
        const preLength = lineIdx < lines.length - 1 ? lineEnd - codeBlockStart + 1 : lineEnd - codeBlockStart;
        ranges.push({type: 'syntax', start: lineStart, length: fenceLength});
        ranges.push({type: 'pre', start: codeBlockStart, length: preLength});
        inCodeBlock = false;
        codeBlockFence = '';
      }
      pos = lineEnd + 1;
      continue;
    }

    if (inCodeBlock) {
      pos = lineEnd + 1;
      continue;
    }

    // ATX Heading
    const headingMatch = line.match(/^( {0,3})(#{1,6})[ \t]+(.*)$/);
    if (headingMatch) {
      const indent = headingMatch[1]!;
      const hashes = headingMatch[2]!;
      const level = hashes.length;
      const headingType = ('h' + level) as MarkdownType;

      ranges.push({
        type: 'syntax',
        start: lineStart + indent.length,
        length: hashes.length + 1,
      });

      const contentStart = lineStart + indent.length + hashes.length + 1;
      // Include newline in heading range to fix scrolling issues
      const contentLength = lineIdx < lines.length - 1 ? lineEnd - contentStart + 1 : lineEnd - contentStart;
      if (contentLength > 0) {
        ranges.push({
          type: headingType,
          start: contentStart,
          length: contentLength,
        });
      }
      pos = lineEnd + 1;
      continue;
    }

    // Blockquote
    const bqMatch = line.match(/^( {0,3})>[ ]?/);
    if (bqMatch) {
      const markerLen = bqMatch[0].length;
      // Hide the "> " marker (using dedicated type to avoid scroll issues with 'syntax')
      ranges.push({type: 'blockquote-marker', start: lineStart, length: markerLen});
      // Style the entire line as blockquote
      ranges.push({type: 'blockquote', start: lineStart, length: line.length});
      pos = lineEnd + 1;
      continue;
    }

    // Horizontal rule: ---, ***, ___
    const hrMatch = line.match(/^( {0,3})([-*_])\2{2,}[ \t]*$/);
    if (hrMatch) {
      // Include the newline character in the range to fix scrolling issues
      const rangeLength = lineIdx < lines.length - 1 ? line.length + 1 : line.length;
      ranges.push({type: 'hr', start: lineStart, length: rangeLength});
      ranges.push({type: 'syntax', start: lineStart, length: rangeLength});
      pos = lineEnd + 1;
      continue;
    }

    // Task list: - [ ] or - [x] or - [X]
    const taskMatch = line.match(/^( {0,3})([-*+])[ \t]+\[([ xX])\][ \t]+/);
    if (taskMatch) {
      const checkChar = taskMatch[3]!;
      const isChecked = checkChar.toLowerCase() === 'x';
      const fullMatchLen = taskMatch[0].length;

      // Mark the "- [x] " as syntax (will be hidden)
      ranges.push({type: 'syntax', start: lineStart, length: fullMatchLen});
      // Mark the checkbox type
      ranges.push({
        type: isChecked ? 'task-checked' : 'task-unchecked',
        start: lineStart,
        length: fullMatchLen,
      });
      pos = lineEnd + 1;
      continue;
    }

    // Unordered list: -, *, +
    const ulMatch = line.match(/^( {0,3})([-*+])[ \t]+/);
    if (ulMatch) {
      const indent = ulMatch[1]!;
      const markerStart = lineStart + indent.length;
      // Mark the marker as syntax
      ranges.push({type: 'syntax', start: markerStart, length: ulMatch[0].length - indent.length});
      ranges.push({type: 'list-bullet', start: markerStart, length: 1});
      pos = lineEnd + 1;
      continue;
    }

    // Ordered list: 1., 2., etc.
    const olMatch = line.match(/^( {0,3})(\d{1,9})([.)])[ \t]+/);
    if (olMatch) {
      const indent = olMatch[1]!;
      const num = olMatch[2]!;
      const punct = olMatch[3]!;
      const markerStart = lineStart + indent.length;
      // Mark the marker as syntax
      ranges.push({type: 'syntax', start: markerStart, length: olMatch[0].length - indent.length});
      ranges.push({type: 'list-number', start: markerStart, length: num.length + punct.length});
      pos = lineEnd + 1;
      continue;
    }

    pos = lineEnd + 1;
  }

  // =========================================================================
  // INLINE PARSING
  // =========================================================================

  // Extract code block ranges for O(1) lookup during inline parsing
  // This avoids O(n*m) complexity from checking all ranges per character
  const codeBlockRanges: {start: number; end: number}[] = [];
  for (let r = 0; r < ranges.length; r++) {
    const range = ranges[r]!;
    if (range.type === 'pre') {
      codeBlockRanges.push({start: range.start, end: range.start + range.length});
    }
  }
  // Sort by start position (should already be roughly sorted from block parsing)
  codeBlockRanges.sort((a, b) => a.start - b.start);

  let codeBlockIdx = 0;
  let i = 0;
  while (i < markdown.length) {
    const char = markdown[i]!;

    // Efficiently check if we're inside a code block using sorted ranges
    // Advance the code block pointer past any ranges we've passed
    while (codeBlockIdx < codeBlockRanges.length && codeBlockRanges[codeBlockIdx]!.end <= i) {
      codeBlockIdx++;
    }
    // Check if current position is inside the current code block
    if (codeBlockIdx < codeBlockRanges.length &&
        i >= codeBlockRanges[codeBlockIdx]!.start &&
        i < codeBlockRanges[codeBlockIdx]!.end) {
      i++;
      continue;
    }

    // Code span: `code`
    if (char === '`') {
      let openCount = 0;
      let j = i;
      while (j < markdown.length && markdown[j] === '`') {
        openCount++;
        j++;
      }

      if (openCount > 0) {
        const closePattern = '`'.repeat(openCount);
        let searchPos = j;
        let found = false;

        while (searchPos < markdown.length) {
          const closeIndex = markdown.indexOf(closePattern, searchPos);
          if (closeIndex === -1) break;

          let closeEnd = closeIndex + openCount;
          while (closeEnd < markdown.length && markdown[closeEnd] === '`') {
            closeEnd++;
          }

          if (closeEnd - closeIndex === openCount) {
            ranges.push({type: 'syntax', start: i, length: openCount});
            ranges.push({type: 'code', start: j, length: closeIndex - j});
            ranges.push({type: 'syntax', start: closeIndex, length: openCount});
            i = closeEnd;
            found = true;
            break;
          }
          searchPos = closeEnd;
        }

        if (found) continue;
      }
    }

    // Bold: **text** or __text__
    if ((char === '*' || char === '_') && i + 1 < markdown.length && markdown[i + 1] === char) {
      const delim = char + char;
      const contentStart = i + 2;
      const closeIndex = markdown.indexOf(delim, contentStart);

      if (closeIndex !== -1 && closeIndex > contentStart) {
        // Make sure it's not more delimiters
        let valid = true;
        if (closeIndex > 0 && markdown[closeIndex - 1] === char) {
          valid = false;
        }

        if (valid) {
          ranges.push({type: 'syntax', start: i, length: 2});
          ranges.push({type: 'bold', start: contentStart, length: closeIndex - contentStart});
          ranges.push({type: 'syntax', start: closeIndex, length: 2});
          i = closeIndex + 2;
          continue;
        }
      }
    }

    // Italic: *text* or _text_
    if (char === '*' || char === '_') {
      const contentStart = i + 1;
      let closeIndex = -1;

      // Find closing delimiter that's not doubled
      for (let k = contentStart; k < markdown.length; k++) {
        if (markdown[k] === char) {
          // Make sure it's not a double delimiter
          if (k + 1 < markdown.length && markdown[k + 1] === char) {
            k++; // Skip the double
            continue;
          }
          closeIndex = k;
          break;
        }
      }

      if (closeIndex !== -1 && closeIndex > contentStart) {
        ranges.push({type: 'syntax', start: i, length: 1});
        ranges.push({type: 'italic', start: contentStart, length: closeIndex - contentStart});
        ranges.push({type: 'syntax', start: closeIndex, length: 1});
        i = closeIndex + 1;
        continue;
      }
    }

    // Strikethrough: ~~text~~ (GFM)
    if (char === '~' && i + 1 < markdown.length && markdown[i + 1] === '~') {
      const contentStart = i + 2;
      // Find closing ~~
      let closeIndex = -1;
      for (let k = contentStart; k < markdown.length - 1; k++) {
        if (markdown[k] === '~' && markdown[k + 1] === '~') {
          closeIndex = k;
          break;
        }
      }
      if (closeIndex !== -1 && closeIndex > contentStart) {
        ranges.push({type: 'syntax', start: i, length: 2});
        ranges.push({type: 'strikethrough', start: contentStart, length: closeIndex - contentStart});
        ranges.push({type: 'syntax', start: closeIndex, length: 2});
        i = closeIndex + 2;
        continue;
      }
    }

    // Link: [text](url)
    if (char === '[') {
      let bracketDepth = 1;
      let j = i + 1;
      while (j < markdown.length && bracketDepth > 0) {
        if (markdown[j] === '[') bracketDepth++;
        else if (markdown[j] === ']') bracketDepth--;
        j++;
      }

      if (bracketDepth === 0 && j < markdown.length && markdown[j] === '(') {
        const labelEnd = j - 1;
        j++; // skip (
        const urlStart = j;

        let parenDepth = 1;
        while (j < markdown.length && parenDepth > 0) {
          if (markdown[j] === '(') parenDepth++;
          else if (markdown[j] === ')') parenDepth--;
          j++;
        }

        if (parenDepth === 0) {
          const urlEnd = j - 1;
          ranges.push({type: 'syntax', start: i, length: 1});           // [
          ranges.push({type: 'syntax', start: labelEnd, length: 2});    // ](
          ranges.push({type: 'link', start: urlStart, length: urlEnd - urlStart});
          ranges.push({type: 'syntax', start: urlEnd, length: 1});      // )
          i = j;
          continue;
        }
      }
    }

    // Image: ![alt](url)
    if (char === '!' && i + 1 < markdown.length && markdown[i + 1] === '[') {
      let bracketDepth = 1;
      let j = i + 2;
      while (j < markdown.length && bracketDepth > 0) {
        if (markdown[j] === '[') bracketDepth++;
        else if (markdown[j] === ']') bracketDepth--;
        j++;
      }

      if (bracketDepth === 0 && j < markdown.length && markdown[j] === '(') {
        const labelEnd = j - 1;
        j++; // skip (
        const urlStart = j;

        let parenDepth = 1;
        while (j < markdown.length && parenDepth > 0) {
          if (markdown[j] === '(') parenDepth++;
          else if (markdown[j] === ')') parenDepth--;
          j++;
        }

        if (parenDepth === 0) {
          const urlEnd = j - 1;
          ranges.push({type: 'inline-image', start: i, length: j - i});
          ranges.push({type: 'syntax', start: i, length: 2});           // ![
          ranges.push({type: 'syntax', start: labelEnd, length: 2});    // ](
          ranges.push({type: 'link', start: urlStart, length: urlEnd - urlStart});
          ranges.push({type: 'syntax', start: urlEnd, length: 1});      // )
          i = j;
          continue;
        }
      }
    }

    i++;
  }

  // Sort and group ranges
  const sorted = sortRanges(ranges);
  const grouped = groupRanges(sorted);

  return grouped;
}

export default parseMarkdown;
