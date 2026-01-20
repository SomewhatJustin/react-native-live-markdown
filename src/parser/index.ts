'worklet';

import type {MarkdownRange, MarkdownType /* , TableAlignment */} from '../commonTypes'; // MVP: TableAlignment disabled
import {sortRanges, groupRanges} from '../rangeUtils';

const MAX_PARSABLE_LENGTH = 500000;

function isBlankLine(line: string): boolean {
  for (let i = 0; i < line.length; i++) {
    const char = line[i]!;
    if (char !== ' ' && char !== '\t') {
      return false;
    }
  }
  return true;
}

function getIndentSyntaxLength(line: string): number {
  if (isBlankLine(line)) {
    return 0;
  }

  let columns = 0;
  let chars = 0;
  while (chars < line.length && columns < 4) {
    const char = line[chars]!;
    if (char === ' ') {
      columns++;
      chars++;
      continue;
    }
    if (char === '\t') {
      const tabWidth = 4 - (columns % 4);
      columns += tabWidth;
      chars++;
      continue;
    }
    break;
  }

  return columns >= 4 ? chars : 0;
}

function isIndentedCodeLine(line: string): boolean {
  return getIndentSyntaxLength(line) > 0;
}

function hasFollowingIndentedLine(lines: string[], startIndex: number): boolean {
  for (let i = startIndex; i < lines.length; i++) {
    const line = lines[i]!;
    if (isBlankLine(line)) {
      continue;
    }
    return isIndentedCodeLine(line);
  }
  return false;
}

// MVP: Tables disabled - re-enable when ready
// /**
//  * Check if a line contains an unescaped pipe character.
//  */
// function lineContainsPipe(line: string): boolean {
//   for (let i = 0; i < line.length; i++) {
//     if (line[i] === '|' && (i === 0 || line[i - 1] !== '\\')) {
//       return true;
//     }
//   }
//   return false;
// }
//
// /**
//  * Parse a delimiter row and extract column alignments.
//  * Returns null if not a valid delimiter row.
//  * A valid delimiter row: |:---|:---:|---:| or :---|:---:|---: (pipes optional on sides)
//  */
// function parseDelimiterRow(line: string): TableAlignment[] | null {
//   // Trim leading/trailing whitespace
//   const trimmed = line.trim();
//
//   // Split by pipe, accounting for escaped pipes
//   const parts: string[] = [];
//   let current = '';
//   let i = 0;
//
//   while (i < trimmed.length) {
//     if (trimmed[i] === '\\' && i + 1 < trimmed.length && trimmed[i + 1] === '|') {
//       current += '|';
//       i += 2;
//     } else if (trimmed[i] === '|') {
//       parts.push(current.trim());
//       current = '';
//       i++;
//     } else {
//       current += trimmed[i];
//       i++;
//     }
//   }
//   if (current.length > 0 || trimmed.endsWith('|')) {
//     parts.push(current.trim());
//   }
//
//   // Remove empty parts from beginning and end (from outer pipes)
//   if (parts.length > 0 && parts[0] === '') {
//     parts.shift();
//   }
//   if (parts.length > 0 && parts[parts.length - 1] === '') {
//     parts.pop();
//   }
//
//   if (parts.length === 0) {
//     return null;
//   }
//
//   // Each cell must match: :?-{3,}:?
//   const alignments: TableAlignment[] = [];
//   for (const part of parts) {
//     const cell = part.trim();
//     // Must have at least 3 dashes
//     const match = cell.match(/^(:?)-{1,}(:?)$/);
//     if (!match) {
//       return null;
//     }
//     const leftColon = match[1] === ':';
//     const rightColon = match[2] === ':';
//
//     if (leftColon && rightColon) {
//       alignments.push('center');
//     } else if (rightColon) {
//       alignments.push('right');
//     } else {
//       alignments.push('left');
//     }
//   }
//
//   return alignments;
// }
//
// interface TableCell {
//   start: number;
//   end: number;
//   content: string;
// }
//
// interface TableRowParsed {
//   cells: TableCell[];
//   pipePositions: number[];
// }
//
// /**
//  * Parse a table row into cells, handling escaped pipes.
//  * Returns cells and pipe positions relative to lineStart.
//  */
// function parseTableRow(line: string, lineStart: number): TableRowParsed {
//   const cells: TableCell[] = [];
//   const pipePositions: number[] = [];
//
//   let i = 0;
//   // Skip leading whitespace
//   while (i < line.length && (line[i] === ' ' || line[i] === '\t')) {
//     i++;
//   }
//
//   // Track if we have a leading pipe
//   if (i < line.length && line[i] === '|') {
//     pipePositions.push(lineStart + i);
//     i++;
//   }
//
//   let cellStart = lineStart + i;
//   let cellContent = '';
//
//   while (i < line.length) {
//     if (line[i] === '\\' && i + 1 < line.length && line[i + 1] === '|') {
//       // Escaped pipe, include the literal pipe in content
//       cellContent += '|';
//       i += 2;
//     } else if (line[i] === '|') {
//       // End of cell
//       const trimmedContent = cellContent.trim();
//       // Find actual content bounds within the cell (excluding whitespace)
//       let contentStart = cellStart;
//       let contentLen = i - (cellStart - lineStart);
//
//       // Trim leading whitespace from position
//       let j = cellStart - lineStart;
//       while (j < i && (line[j] === ' ' || line[j] === '\t')) {
//         contentStart++;
//         j++;
//       }
//       // Trim trailing whitespace
//       let k = i - 1;
//       while (k >= j && (line[k] === ' ' || line[k] === '\t')) {
//         k--;
//       }
//       contentLen = k - j + 1;
//       if (contentLen < 0) contentLen = 0;
//
//       cells.push({
//         start: contentStart,
//         end: contentStart + contentLen,
//         content: trimmedContent,
//       });
//
//       pipePositions.push(lineStart + i);
//       cellStart = lineStart + i + 1;
//       cellContent = '';
//       i++;
//     } else {
//       cellContent += line[i];
//       i++;
//     }
//   }
//
//   // Handle trailing content (if no trailing pipe)
//   if (cellContent.trim().length > 0) {
//     const trimmedContent = cellContent.trim();
//     let contentStart = cellStart;
//     let j = cellStart - lineStart;
//     while (j < line.length && (line[j] === ' ' || line[j] === '\t')) {
//       contentStart++;
//       j++;
//     }
//     let k = line.length - 1;
//     while (k >= j && (line[k] === ' ' || line[k] === '\t')) {
//       k--;
//     }
//     const contentLen = Math.max(0, k - j + 1);
//
//     cells.push({
//       start: contentStart,
//       end: contentStart + contentLen,
//       content: trimmedContent,
//     });
//   }
//
//   return {cells, pipePositions};
// }
//
// /**
//  * Check if a line could be a table row (contains unescaped pipe).
//  */
// function isTableRow(line: string): boolean {
//   return lineContainsPipe(line) && !isBlankLine(line);
// }

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

    const isPotentialList = /^([ \t]*)(?:[-*+]|\d{1,9}[.)])[ \t]+/.test(line);

    // Indented code block: 4+ spaces or a tab
    if (isIndentedCodeLine(line) && !isPotentialList) {
      const blockStart = lineStart;
      let blockEndIdx = lineIdx;
      let blockEndLineEnd = lineEnd;

      const indentLength = getIndentSyntaxLength(line);
      if (indentLength > 0) {
        ranges.push({type: 'syntax', start: lineStart, length: indentLength});
      }

      let scanIdx = lineIdx;
      let scanLineEnd = lineEnd;
      while (scanIdx + 1 < lines.length) {
        const nextIdx = scanIdx + 1;
        const nextLine = lines[nextIdx]!;
        const nextLineStart = scanLineEnd + 1;
        const nextLineEnd = nextLineStart + nextLine.length;

        if (isIndentedCodeLine(nextLine)) {
          const nextIndentLength = getIndentSyntaxLength(nextLine);
          if (nextIndentLength > 0) {
            ranges.push({type: 'syntax', start: nextLineStart, length: nextIndentLength});
          }
          blockEndIdx = nextIdx;
          blockEndLineEnd = nextLineEnd;
          scanIdx = nextIdx;
          scanLineEnd = nextLineEnd;
          continue;
        }

        if (isBlankLine(nextLine) && hasFollowingIndentedLine(lines, nextIdx + 1)) {
          blockEndIdx = nextIdx;
          blockEndLineEnd = nextLineEnd;
          scanIdx = nextIdx;
          scanLineEnd = nextLineEnd;
          continue;
        }

        break;
      }

      const blockLength = blockEndIdx < lines.length - 1 ? blockEndLineEnd - blockStart + 1 : blockEndLineEnd - blockStart;
      ranges.push({type: 'pre', start: blockStart, length: blockLength});

      lineIdx = blockEndIdx;
      pos = blockEndLineEnd + 1;
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

    // Blockquote (with nesting support)
    const bqMatch = line.match(/^( {0,3})((?:>[ ]?)+)/);
    if (bqMatch) {
      const markers = bqMatch[2]!;
      // Count depth by counting > characters
      let depth = 0;
      for (let c = 0; c < markers.length; c++) {
        if (markers[c] === '>') depth++;
      }
      const markerLen = bqMatch[0].length;
      // Hide the "> " markers (using dedicated type to avoid scroll issues with 'syntax')
      ranges.push({type: 'blockquote-marker', start: lineStart, length: markerLen});
      // Style the entire line as blockquote, include newline for empty blockquote lines
      // to ensure the vertical bar still renders when marker is hidden
      const includeNewline = lineIdx < lines.length - 1;
      const rangeLength = includeNewline ? line.length + 1 : line.length;
      ranges.push({type: 'blockquote', start: lineStart, length: rangeLength, depth});
      pos = lineEnd + 1;
      continue;
    }

    // MVP: Horizontal rules disabled - re-enable when ready
    // // Horizontal rule: ---, ***, ___
    // const hrMatch = line.match(/^( {0,3})([-*_])\2{2,}[ \t]*$/);
    // if (hrMatch) {
    //   // Include the newline character in the range to fix scrolling issues
    //   const rangeLength = lineIdx < lines.length - 1 ? line.length + 1 : line.length;
    //   ranges.push({type: 'hr', start: lineStart, length: rangeLength});
    //   // Note: We don't push a 'syntax' range here - hr handler manages visibility directly
    //   pos = lineEnd + 1;
    //   continue;
    // }

    // MVP: Tables disabled - re-enable when ready
    // // GFM Table detection
    // // A table requires: header row with pipes, delimiter row (|---|), 0+ body rows
    // if (lineContainsPipe(line) && lineIdx + 1 < lines.length) {
    //   const nextLine = lines[lineIdx + 1]!;
    //   const alignments = parseDelimiterRow(nextLine);
    //
    //   if (alignments && alignments.length > 0) {
    //     // This is a table! Parse the entire table block
    //     const tableStartPos = lineStart;
    //     let tableEndLine = lineIdx + 1; // At minimum includes header and delimiter
    //     let tableEndPos = pos + line.length + 1 + nextLine.length;
    //
    //     // Collect all table rows
    //     const tableRows: {line: string; lineStart: number; lineEnd: number; lineIdx: number}[] = [];
    //
    //     // Add header row
    //     tableRows.push({line, lineStart, lineEnd, lineIdx});
    //
    //     // Add delimiter row position info
    //     const delimiterLineStart = lineEnd + 1;
    //     const delimiterLineEnd = delimiterLineStart + nextLine.length;
    //
    //     // Find body rows
    //     let scanIdx = lineIdx + 2;
    //     let scanPos = delimiterLineEnd + 1;
    //     while (scanIdx < lines.length) {
    //       const bodyLine = lines[scanIdx]!;
    //       if (!isTableRow(bodyLine)) {
    //         break;
    //       }
    //       const bodyLineEnd = scanPos + bodyLine.length;
    //       tableRows.push({
    //         line: bodyLine,
    //         lineStart: scanPos,
    //         lineEnd: bodyLineEnd,
    //         lineIdx: scanIdx,
    //       });
    //       tableEndLine = scanIdx;
    //       tableEndPos = bodyLineEnd;
    //       scanIdx++;
    //       scanPos = bodyLineEnd + 1;
    //     }
    //
    //     // Calculate table length including final newline if not last line
    //     const includeTrailingNewline = tableEndLine < lines.length - 1;
    //     const tableLength = includeTrailingNewline ? tableEndPos - tableStartPos + 1 : tableEndPos - tableStartPos;
    //
    //     // Emit table range (entire block)
    //     ranges.push({
    //       type: 'table',
    //       start: tableStartPos,
    //       length: tableLength,
    //       tableColumnCount: alignments.length,
    //     });
    //
    //     // Emit ranges for header row
    //     const headerParsed = parseTableRow(line, lineStart);
    //     const headerRowLength = lineIdx < lines.length - 1 ? line.length + 1 : line.length;
    //     ranges.push({
    //       type: 'table-row',
    //       start: lineStart,
    //       length: headerRowLength,
    //       depth: 0, // 0 = header row
    //     });
    //
    //     // Emit pipe ranges for header
    //     for (const pipePos of headerParsed.pipePositions) {
    //       ranges.push({type: 'table-pipe', start: pipePos, length: 1});
    //     }
    //
    //     // Emit cell ranges for header
    //     for (let colIdx = 0; colIdx < headerParsed.cells.length && colIdx < alignments.length; colIdx++) {
    //       const cell = headerParsed.cells[colIdx]!;
    //       if (cell.end > cell.start) {
    //         ranges.push({
    //           type: 'table-cell',
    //           start: cell.start,
    //           length: cell.end - cell.start,
    //           tableColumn: colIdx,
    //           tableAlignment: alignments[colIdx],
    //         });
    //       }
    //     }
    //
    //     // Emit delimiter row range
    //     const delimiterRowLength = lineIdx + 1 < lines.length - 1 ? nextLine.length + 1 : nextLine.length;
    //     ranges.push({
    //       type: 'table-delimiter',
    //       start: delimiterLineStart,
    //       length: delimiterRowLength,
    //     });
    //
    //     // Emit pipe ranges for delimiter
    //     const delimiterParsed = parseTableRow(nextLine, delimiterLineStart);
    //     for (const pipePos of delimiterParsed.pipePositions) {
    //       ranges.push({type: 'table-pipe', start: pipePos, length: 1});
    //     }
    //
    //     // Emit ranges for body rows
    //     for (let rowIdx = 0; rowIdx < tableRows.length; rowIdx++) {
    //       // Skip header row (already processed)
    //       if (rowIdx === 0) continue;
    //
    //       const row = tableRows[rowIdx]!;
    //       const rowParsed = parseTableRow(row.line, row.lineStart);
    //       const rowLength = row.lineIdx < lines.length - 1 ? row.line.length + 1 : row.line.length;
    //
    //       ranges.push({
    //         type: 'table-row',
    //         start: row.lineStart,
    //         length: rowLength,
    //         depth: rowIdx + 1, // 1+ = body rows (header is 0, delimiter is skipped in numbering)
    //       });
    //
    //       // Emit pipe ranges for body row
    //       for (const pipePos of rowParsed.pipePositions) {
    //         ranges.push({type: 'table-pipe', start: pipePos, length: 1});
    //       }
    //
    //       // Emit cell ranges for body row
    //       for (let colIdx = 0; colIdx < rowParsed.cells.length && colIdx < alignments.length; colIdx++) {
    //         const cell = rowParsed.cells[colIdx]!;
    //         if (cell.end > cell.start) {
    //           ranges.push({
    //             type: 'table-cell',
    //             start: cell.start,
    //             length: cell.end - cell.start,
    //             tableColumn: colIdx,
    //             tableAlignment: alignments[colIdx],
    //           });
    //         }
    //       }
    //     }
    //
    //     // Skip to end of table
    //     lineIdx = tableEndLine;
    //     pos = tableEndPos + 1;
    //     continue;
    //   }
    // }

    // Ordered task list: 1. [ ] or 1. [x] or 1) [ ]
    const orderedTaskMatch = line.match(/^([ \t]*)(\d{1,9})([.)])[ \t]+\[([ xX])\][ \t]+/);
    if (orderedTaskMatch) {
      const indent = orderedTaskMatch[1]!;
      const num = orderedTaskMatch[2]!;
      const punct = orderedTaskMatch[3]!;
      const checkChar = orderedTaskMatch[4]!;
      const isChecked = checkChar.toLowerCase() === 'x';
      const fullMatchLen = orderedTaskMatch[0].length;
      const bracketOffset = orderedTaskMatch[0].indexOf('[');
      const markerStart = lineStart + indent.length;

      // Mark the number marker
      ranges.push({type: 'list-number', start: markerStart, length: num.length + punct.length});

      // Mark the checkbox portion for hiding/drawing
      if (bracketOffset !== -1) {
        const bracketStart = lineStart + bracketOffset;
        const markerLength = fullMatchLen - bracketOffset;
        ranges.push({
          type: isChecked ? 'task-checked' : 'task-unchecked',
          start: bracketStart,
          length: markerLength,
        });
      }

      // Mark the task content text (for graying out completed tasks)
      const contentStart = lineStart + fullMatchLen;
      const contentLength = lineEnd - contentStart;
      if (contentLength > 0 && isChecked) {
        ranges.push({
          type: 'task-content-checked',
          start: contentStart,
          length: contentLength,
        });
      }

      pos = lineEnd + 1;
      continue;
    }

    // Task list: - [ ] or - [x] or - [X]
    const taskMatch = line.match(/^([ \t]*)([-*+])[ \t]+\[([ xX])\][ \t]+/);
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
      // Mark the task content text (for graying out completed tasks)
      const contentStart = lineStart + fullMatchLen;
      const contentLength = lineEnd - contentStart;
      if (contentLength > 0 && isChecked) {
        ranges.push({
          type: 'task-content-checked',
          start: contentStart,
          length: contentLength,
        });
      }
      pos = lineEnd + 1;
      continue;
    }

    // Unordered list: -, *, +
    const ulMatch = line.match(/^([ \t]*)([-*+])[ \t]+/);
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
    const olMatch = line.match(/^([ \t]*)(\d{1,9})([.)])[ \t]+/);
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

  // Extract block ranges to skip during inline parsing (code blocks, HRs, tables, list markers)
  // This avoids O(n*m) complexity from checking all ranges per character
  const skipRanges: {start: number; end: number}[] = [];
  // MVP: Tables disabled - re-enable when ready
  // const tableCellRanges: {start: number; end: number}[] = [];
  for (let r = 0; r < ranges.length; r++) {
    const range = ranges[r]!;
    // MVP: 'hr' and 'table' disabled
    // Include list-bullet and list-number to prevent their markers (*, -, +) from being
    // treated as emphasis delimiters during inline parsing
    if (range.type === 'pre' || range.type === 'list-bullet' || range.type === 'list-number' /* || range.type === 'hr' || range.type === 'table' */) {
      skipRanges.push({start: range.start, end: range.start + range.length});
    }
    // MVP: Tables disabled - re-enable when ready
    // // Collect table cell ranges for second-pass inline formatting
    // if (range.type === 'table-cell') {
    //   tableCellRanges.push({start: range.start, end: range.start + range.length});
    // }
  }
  // Sort by start position (should already be roughly sorted from block parsing)
  skipRanges.sort((a, b) => a.start - b.start);

  let skipRangeIdx = 0;
  let i = 0;
  while (i < markdown.length) {
    const char = markdown[i]!;

    // Efficiently check if we're inside a skip range (code block, HR) using sorted ranges
    // Advance the pointer past any ranges we've passed
    while (skipRangeIdx < skipRanges.length && skipRanges[skipRangeIdx]!.end <= i) {
      skipRangeIdx++;
    }
    // Check if current position is inside a skip range
    if (skipRangeIdx < skipRanges.length &&
        i >= skipRanges[skipRangeIdx]!.start &&
        i < skipRanges[skipRangeIdx]!.end) {
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

    // Bold+Italic: ***text*** or ___text___
    if ((char === '*' || char === '_') && i + 2 < markdown.length && markdown[i + 1] === char && markdown[i + 2] === char) {
      const tripleDelim = char + char + char;
      const contentStart = i + 3;
      const closeIndex = markdown.indexOf(tripleDelim, contentStart);

      if (closeIndex !== -1 && closeIndex > contentStart) {
        ranges.push({type: 'syntax', start: i, length: 3});
        ranges.push({type: 'bold', start: contentStart, length: closeIndex - contentStart});
        ranges.push({type: 'italic', start: contentStart, length: closeIndex - contentStart});
        ranges.push({type: 'syntax', start: closeIndex, length: 3});
        i = closeIndex + 3;
        continue;
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

          // Look for nested italic within the bold content
          const boldContent = markdown.substring(contentStart, closeIndex);
          let j = 0;
          while (j < boldContent.length) {
            const c = boldContent[j]!;
            // Look for single * or _ that's not doubled
            if ((c === '*' || c === '_') && !(j + 1 < boldContent.length && boldContent[j + 1] === c)) {
              // Find closing single delimiter
              let closeItalic = -1;
              for (let k = j + 1; k < boldContent.length; k++) {
                if (boldContent[k] === c) {
                  // Make sure it's not doubled
                  if (k + 1 < boldContent.length && boldContent[k + 1] === c) {
                    k++;
                    continue;
                  }
                  closeItalic = k;
                  break;
                }
              }
              if (closeItalic !== -1 && closeItalic > j + 1) {
                ranges.push({type: 'syntax', start: contentStart + j, length: 1});
                ranges.push({type: 'italic', start: contentStart + j + 1, length: closeItalic - j - 1});
                ranges.push({type: 'syntax', start: contentStart + closeItalic, length: 1});
                j = closeItalic + 1;
                continue;
              }
            }
            j++;
          }

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

        // Look for nested bold/italic within the strikethrough content
        const strikeContent = markdown.substring(contentStart, closeIndex);
        let j = 0;
        while (j < strikeContent.length) {
          const c = strikeContent[j]!;
          // Look for bold: ** or __
          if ((c === '*' || c === '_') && j + 1 < strikeContent.length && strikeContent[j + 1] === c) {
            const boldDelim = c;
            const boldContentStart = j + 2;
            let closeBold = -1;
            for (let k = boldContentStart; k < strikeContent.length - 1; k++) {
              if (strikeContent[k] === boldDelim && strikeContent[k + 1] === boldDelim) {
                closeBold = k;
                break;
              }
            }
            if (closeBold !== -1 && closeBold > boldContentStart) {
              ranges.push({type: 'syntax', start: contentStart + j, length: 2});
              ranges.push({type: 'bold', start: contentStart + boldContentStart, length: closeBold - boldContentStart});
              ranges.push({type: 'syntax', start: contentStart + closeBold, length: 2});
              j = closeBold + 2;
              continue;
            }
          }
          // Look for italic: single * or _
          if ((c === '*' || c === '_') && !(j + 1 < strikeContent.length && strikeContent[j + 1] === c)) {
            let closeItalic = -1;
            for (let k = j + 1; k < strikeContent.length; k++) {
              if (strikeContent[k] === c) {
                if (k + 1 < strikeContent.length && strikeContent[k + 1] === c) {
                  k++;
                  continue;
                }
                closeItalic = k;
                break;
              }
            }
            if (closeItalic !== -1 && closeItalic > j + 1) {
              ranges.push({type: 'syntax', start: contentStart + j, length: 1});
              ranges.push({type: 'italic', start: contentStart + j + 1, length: closeItalic - j - 1});
              ranges.push({type: 'syntax', start: contentStart + closeItalic, length: 1});
              j = closeItalic + 1;
              continue;
            }
          }
          j++;
        }

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
        const labelStart = i + 1;
        const labelLength = labelEnd - labelStart;
        j++; // skip (

        let parenDepth = 1;
        while (j < markdown.length && parenDepth > 0) {
          if (markdown[j] === '(') parenDepth++;
          else if (markdown[j] === ')') parenDepth--;
          j++;
        }

        if (parenDepth === 0) {
          const urlEnd = j - 1;
          const closingStart = labelEnd;
          const closingLength = urlEnd - closingStart + 1;
          ranges.push({type: 'syntax', start: i, length: 1});           // [
          if (labelLength > 0) {
            ranges.push({type: 'link', start: labelStart, length: labelLength});
          }
          ranges.push({type: 'syntax', start: closingStart, length: closingLength}); // ](url)
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

    // MVP: Autolinks disabled - re-enable when ready
    // // Autolink: <https://example.com> or <user@example.com>
    // if (char === '<') {
    //   const closeIndex = markdown.indexOf('>', i + 1);
    //   if (closeIndex !== -1 && closeIndex > i + 1) {
    //     const content = markdown.substring(i + 1, closeIndex);
    //     // Check for URL autolink (must have scheme)
    //     if (/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^\s<>]*$/.test(content)) {
    //       ranges.push({type: 'syntax', start: i, length: 1});           // <
    //       ranges.push({type: 'link', start: i + 1, length: content.length});
    //       ranges.push({type: 'syntax', start: closeIndex, length: 1}); // >
    //       i = closeIndex + 1;
    //       continue;
    //     }
    //     // Check for email autolink
    //     if (/^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/.test(content)) {
    //       ranges.push({type: 'syntax', start: i, length: 1});           // <
    //       ranges.push({type: 'link', start: i + 1, length: content.length});
    //       ranges.push({type: 'syntax', start: closeIndex, length: 1}); // >
    //       i = closeIndex + 1;
    //       continue;
    //     }
    //   }
    // }
    //
    // // GFM Extended Autolinks: bare URLs and emails
    // // URL with scheme: http:// or https://
    // if ((char === 'h' || char === 'H') && i + 7 < markdown.length) {
    //   const potentialScheme = markdown.substring(i, i + 8).toLowerCase();
    //   if (potentialScheme === 'https://' || potentialScheme.substring(0, 7) === 'http://') {
    //     const schemeLen = potentialScheme === 'https://' ? 8 : 7;
    //     // Check that we're at word boundary (start of string or preceded by whitespace/punctuation)
    //     if (i === 0 || /[\s<(\[{]/.test(markdown[i - 1]!)) {
    //       // Find end of URL
    //       let j = i + schemeLen;
    //       while (j < markdown.length && !/[\s<>)\]}]/.test(markdown[j]!)) {
    //         j++;
    //       }
    //       // Remove trailing punctuation that's likely not part of URL
    //       while (j > i + schemeLen && /[.,;:!?'")\]}]/.test(markdown[j - 1]!)) {
    //         // But keep ) if there's a matching ( in the URL
    //         if (markdown[j - 1] === ')') {
    //           const urlPart = markdown.substring(i, j - 1);
    //           const openCount = (urlPart.match(/\(/g) || []).length;
    //           const closeCount = (urlPart.match(/\)/g) || []).length;
    //           if (openCount > closeCount) break;
    //         }
    //         j--;
    //       }
    //       if (j > i + schemeLen) {
    //         ranges.push({type: 'link', start: i, length: j - i});
    //         i = j;
    //         continue;
    //       }
    //     }
    //   }
    // }
    //
    // // URL starting with www.
    // if ((char === 'w' || char === 'W') && i + 4 < markdown.length) {
    //   const potentialWww = markdown.substring(i, i + 4).toLowerCase();
    //   if (potentialWww === 'www.') {
    //     // Check that we're at word boundary
    //     if (i === 0 || /[\s<(\[{]/.test(markdown[i - 1]!)) {
    //       // Find end of URL
    //       let j = i + 4;
    //       while (j < markdown.length && !/[\s<>)\]}]/.test(markdown[j]!)) {
    //         j++;
    //       }
    //       // Remove trailing punctuation
    //       while (j > i + 4 && /[.,;:!?'")\]}]/.test(markdown[j - 1]!)) {
    //         if (markdown[j - 1] === ')') {
    //           const urlPart = markdown.substring(i, j - 1);
    //           const openCount = (urlPart.match(/\(/g) || []).length;
    //           const closeCount = (urlPart.match(/\)/g) || []).length;
    //           if (openCount > closeCount) break;
    //         }
    //         j--;
    //       }
    //       // Validate there's at least one more dot after www.
    //       const urlContent = markdown.substring(i + 4, j);
    //       if (urlContent.includes('.') && j > i + 4) {
    //         ranges.push({type: 'link', start: i, length: j - i});
    //         i = j;
    //         continue;
    //       }
    //     }
    //   }
    // }
    //
    // // Email autolink (GFM extended): user@example.com
    // // Must have alphanumeric before @, and valid domain after
    // if (char === '@' && i > 0) {
    //   // Check if there's a valid local part before @
    //   let localStart = i - 1;
    //   while (localStart > 0 && /[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]/.test(markdown[localStart - 1]!)) {
    //     localStart--;
    //   }
    //   // Local part must start with alphanumeric
    //   if (localStart < i && /[a-zA-Z0-9]/.test(markdown[localStart]!)) {
    //     // Check we're at word boundary before the local part
    //     if (localStart === 0 || /[\s<(\[{:;,]/.test(markdown[localStart - 1]!)) {
    //       // Find the domain part after @
    //       let j = i + 1;
    //       // Domain must start with alphanumeric
    //       if (j < markdown.length && /[a-zA-Z0-9]/.test(markdown[j]!)) {
    //         while (j < markdown.length && /[a-zA-Z0-9.-]/.test(markdown[j]!)) {
    //           j++;
    //         }
    //         // Remove trailing dots/hyphens
    //         while (j > i + 1 && /[.-]/.test(markdown[j - 1]!)) {
    //           j--;
    //         }
    //         // Validate domain has at least one dot
    //         const domain = markdown.substring(i + 1, j);
    //         if (domain.includes('.') && /[a-zA-Z]$/.test(domain)) {
    //           ranges.push({type: 'link', start: localStart, length: j - localStart});
    //           i = j;
    //           continue;
    //         }
    //       }
    //     }
    //   }
    // }

    i++;
  }

  // MVP: Tables disabled - re-enable when ready
  // // =========================================================================
  // // SECOND PASS: Inline formatting within table cells
  // // =========================================================================
  // for (const cellRange of tableCellRanges) {
  //   let ci = cellRange.start;
  //   while (ci < cellRange.end) {
  //     const char = markdown[ci]!;
  //
  //     // Code span: `code`
  //     if (char === '`') {
  //       let openCount = 0;
  //       let cj = ci;
  //       while (cj < cellRange.end && markdown[cj] === '`') {
  //         openCount++;
  //         cj++;
  //       }
  //       if (openCount > 0) {
  //         const closePattern = '`'.repeat(openCount);
  //         let searchPos = cj;
  //         while (searchPos < cellRange.end) {
  //           const closeIndex = markdown.indexOf(closePattern, searchPos);
  //           if (closeIndex === -1 || closeIndex + openCount > cellRange.end) break;
  //           let closeEnd = closeIndex + openCount;
  //           while (closeEnd < cellRange.end && markdown[closeEnd] === '`') {
  //             closeEnd++;
  //           }
  //           if (closeEnd - closeIndex === openCount) {
  //             ranges.push({type: 'syntax', start: ci, length: openCount});
  //             ranges.push({type: 'code', start: cj, length: closeIndex - cj});
  //             ranges.push({type: 'syntax', start: closeIndex, length: openCount});
  //             ci = closeEnd;
  //             break;
  //           }
  //           searchPos = closeEnd;
  //         }
  //         if (ci >= cj) continue;
  //       }
  //     }
  //
  //     // Bold: **text** or __text__
  //     if ((char === '*' || char === '_') && ci + 1 < cellRange.end && markdown[ci + 1] === char) {
  //       const contentStart = ci + 2;
  //       let closeIndex = -1;
  //       for (let ck = contentStart; ck < cellRange.end - 1; ck++) {
  //         if (markdown[ck] === char && markdown[ck + 1] === char) {
  //           if (ck > 0 && markdown[ck - 1] === char) continue;
  //           closeIndex = ck;
  //           break;
  //         }
  //       }
  //       if (closeIndex !== -1 && closeIndex > contentStart) {
  //         ranges.push({type: 'syntax', start: ci, length: 2});
  //         ranges.push({type: 'bold', start: contentStart, length: closeIndex - contentStart});
  //         ranges.push({type: 'syntax', start: closeIndex, length: 2});
  //         ci = closeIndex + 2;
  //         continue;
  //       }
  //     }
  //
  //     // Italic: *text* or _text_
  //     if (char === '*' || char === '_') {
  //       const contentStart = ci + 1;
  //       let closeIndex = -1;
  //       for (let ck = contentStart; ck < cellRange.end; ck++) {
  //         if (markdown[ck] === char) {
  //           if (ck + 1 < cellRange.end && markdown[ck + 1] === char) {
  //             ck++;
  //             continue;
  //           }
  //           closeIndex = ck;
  //           break;
  //         }
  //       }
  //       if (closeIndex !== -1 && closeIndex > contentStart) {
  //         ranges.push({type: 'syntax', start: ci, length: 1});
  //         ranges.push({type: 'italic', start: contentStart, length: closeIndex - contentStart});
  //         ranges.push({type: 'syntax', start: closeIndex, length: 1});
  //         ci = closeIndex + 1;
  //         continue;
  //       }
  //     }
  //
  //     // Strikethrough: ~~text~~
  //     if (char === '~' && ci + 1 < cellRange.end && markdown[ci + 1] === '~') {
  //       const contentStart = ci + 2;
  //       let closeIndex = -1;
  //       for (let ck = contentStart; ck < cellRange.end - 1; ck++) {
  //         if (markdown[ck] === '~' && markdown[ck + 1] === '~') {
  //           closeIndex = ck;
  //           break;
  //         }
  //       }
  //       if (closeIndex !== -1 && closeIndex > contentStart) {
  //         ranges.push({type: 'syntax', start: ci, length: 2});
  //         ranges.push({type: 'strikethrough', start: contentStart, length: closeIndex - contentStart});
  //         ranges.push({type: 'syntax', start: closeIndex, length: 2});
  //         ci = closeIndex + 2;
  //         continue;
  //       }
  //     }
  //
  //     // Link: [text](url)
  //     if (char === '[') {
  //       let bracketDepth = 1;
  //       let cj = ci + 1;
  //       while (cj < cellRange.end && bracketDepth > 0) {
  //         if (markdown[cj] === '[') bracketDepth++;
  //         else if (markdown[cj] === ']') bracketDepth--;
  //         cj++;
  //       }
  //       if (bracketDepth === 0 && cj < cellRange.end && markdown[cj] === '(') {
  //         const labelEnd = cj - 1;
  //         const labelStart = ci + 1;
  //         const labelLength = labelEnd - labelStart;
  //         cj++;
  //         let parenDepth = 1;
  //         while (cj < cellRange.end && parenDepth > 0) {
  //           if (markdown[cj] === '(') parenDepth++;
  //           else if (markdown[cj] === ')') parenDepth--;
  //           cj++;
  //         }
  //         if (parenDepth === 0) {
  //           const urlEnd = cj - 1;
  //           const closingStart = labelEnd;
  //           const closingLength = urlEnd - closingStart + 1;
  //           ranges.push({type: 'syntax', start: ci, length: 1});
  //           if (labelLength > 0) {
  //             ranges.push({type: 'link', start: labelStart, length: labelLength});
  //           }
  //           ranges.push({type: 'syntax', start: closingStart, length: closingLength});
  //           ci = cj;
  //           continue;
  //         }
  //       }
  //     }
  //
  //     ci++;
  //   }
  // }

  // Sort and group ranges
  const sorted = sortRanges(ranges);
  const grouped = groupRanges(sorted);

  return grouped;
}

export default parseMarkdown;
