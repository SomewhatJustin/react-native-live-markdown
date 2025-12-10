'worklet';

import type {MarkdownRange, MarkdownType} from '../commonTypes';
import {sortRanges, groupRanges} from '../rangeUtils';

const MAX_PARSABLE_LENGTH = 4000;

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
        ranges.push({type: 'syntax', start: lineStart, length: line.length});
      } else if (fence[0] === codeBlockFence && fence.length >= codeBlockFence.length) {
        ranges.push({type: 'syntax', start: lineStart, length: line.length});
        ranges.push({type: 'pre', start: codeBlockStart, length: lineEnd - codeBlockStart});
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
      const contentLength = lineEnd - contentStart;
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
      ranges.push({type: 'syntax', start: lineStart, length: bqMatch[0].length});
      ranges.push({type: 'blockquote', start: lineStart, length: line.length});
      pos = lineEnd + 1;
      continue;
    }

    pos = lineEnd + 1;
  }

  // =========================================================================
  // INLINE PARSING
  // =========================================================================
  let i = 0;
  while (i < markdown.length) {
    const char = markdown[i]!;

    // Skip if we're inside a code block (check ranges)
    let inCode = false;
    for (let r = 0; r < ranges.length; r++) {
      const range = ranges[r]!;
      if (range.type === 'pre' && i >= range.start && i < range.start + range.length) {
        inCode = true;
        break;
      }
    }
    if (inCode) {
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

    // Strikethrough: ~text~
    if (char === '~') {
      const closeIndex = markdown.indexOf('~', i + 1);
      if (closeIndex !== -1 && closeIndex > i + 1) {
        ranges.push({type: 'syntax', start: i, length: 1});
        ranges.push({type: 'strikethrough', start: i + 1, length: closeIndex - i - 1});
        ranges.push({type: 'syntax', start: closeIndex, length: 1});
        i = closeIndex + 1;
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
