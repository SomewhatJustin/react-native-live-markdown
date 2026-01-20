#import "TableRenderContext.h"
#import <React/RCTFont.h>

@implementation TableRenderContext

- (instancetype)initWithTableRange:(NSRange)tableRange {
  if (self = [super init]) {
    _tableRange = tableRange;
    _columnWidths = [NSMutableArray array];
    _columnAlignments = [NSMutableArray array];
    _cellRanges = [NSMutableArray array];
    _columnCount = 0;
    _rowCount = 0;
    _totalWidth = 0;
    _cursorInTable = NO;
    _cellPaddingH = 12.0;
    _cellPaddingV = 8.0;
    _minColumnWidth = 40.0;
  }
  return self;
}

- (void)parseTableStructureFromTextStorage:(NSTextStorage *)textStorage {
  if (_tableRange.location == NSNotFound || _tableRange.length == 0) {
    return;
  }

  NSString *text = textStorage.string;
  if (_tableRange.location + _tableRange.length > text.length) {
    return;
  }

  NSString *tableText = [text substringWithRange:_tableRange];
  NSArray<NSString *> *lines = [tableText componentsSeparatedByString:@"\n"];

  _rowCount = 0;
  _columnCount = 0;
  [_cellRanges removeAllObjects];
  [_columnAlignments removeAllObjects];

  NSUInteger currentOffset = _tableRange.location;

  for (NSUInteger lineIdx = 0; lineIdx < lines.count; lineIdx++) {
    NSString *line = lines[lineIdx];
    if (line.length == 0) {
      currentOffset += 1; // newline
      continue;
    }

    // Parse cells from this line
    NSMutableArray<NSValue *> *rowCells = [NSMutableArray array];

    // Check if this is a delimiter row (contains only |, -, :, and spaces)
    BOOL isDelimiter = [self isDelimiterRow:line];

    if (isDelimiter && lineIdx == 1) {
      // Parse alignment from delimiter row
      [self parseAlignmentsFromDelimiterRow:line];
    }

    // Parse cell content ranges
    NSUInteger cellStart = NSNotFound;
    NSUInteger charIdx = 0;
    BOOL inCell = NO;

    for (NSUInteger i = 0; i < line.length; i++) {
      unichar c = [line characterAtIndex:i];

      if (c == '|') {
        if (inCell && cellStart != NSNotFound) {
          // End of cell - trim whitespace
          NSUInteger cellEnd = i;
          // Trim leading whitespace from cell content
          NSUInteger contentStart = cellStart;
          while (contentStart < cellEnd && [line characterAtIndex:contentStart] == ' ') {
            contentStart++;
          }
          // Trim trailing whitespace
          NSUInteger contentEnd = cellEnd;
          while (contentEnd > contentStart && [line characterAtIndex:contentEnd - 1] == ' ') {
            contentEnd--;
          }

          NSRange cellRange = NSMakeRange(currentOffset + contentStart, contentEnd - contentStart);
          [rowCells addObject:[NSValue valueWithRange:cellRange]];
        }
        inCell = YES;
        cellStart = i + 1; // Start after the pipe
      }
      charIdx++;
    }

    // Handle last cell if line doesn't end with pipe
    if (inCell && cellStart != NSNotFound && cellStart < line.length) {
      unichar lastChar = [line characterAtIndex:line.length - 1];
      if (lastChar != '|') {
        NSUInteger contentStart = cellStart;
        NSUInteger contentEnd = line.length;
        while (contentStart < contentEnd && [line characterAtIndex:contentStart] == ' ') {
          contentStart++;
        }
        while (contentEnd > contentStart && [line characterAtIndex:contentEnd - 1] == ' ') {
          contentEnd--;
        }
        NSRange cellRange = NSMakeRange(currentOffset + contentStart, contentEnd - contentStart);
        [rowCells addObject:[NSValue valueWithRange:cellRange]];
      }
    }

    if (rowCells.count > 0) {
      [_cellRanges addObject:rowCells];
      _columnCount = MAX(_columnCount, (NSInteger)rowCells.count);
      _rowCount++;
    }

    currentOffset += line.length + 1; // +1 for newline
  }

  // Ensure columnAlignments has entries for all columns
  while ((NSInteger)_columnAlignments.count < _columnCount) {
    [_columnAlignments addObject:@(0)]; // Default to left alignment
  }
}

- (BOOL)isDelimiterRow:(NSString *)line {
  for (NSUInteger i = 0; i < line.length; i++) {
    unichar c = [line characterAtIndex:i];
    if (c != '|' && c != '-' && c != ':' && c != ' ') {
      return NO;
    }
  }
  // Must contain at least one dash
  return [line containsString:@"-"];
}

- (void)parseAlignmentsFromDelimiterRow:(NSString *)line {
  [_columnAlignments removeAllObjects];

  // Split by pipe and parse each cell
  NSArray<NSString *> *parts = [line componentsSeparatedByString:@"|"];

  for (NSString *part in parts) {
    NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length == 0) {
      continue;
    }

    BOOL leftColon = [trimmed hasPrefix:@":"];
    BOOL rightColon = [trimmed hasSuffix:@":"];

    NSInteger alignment = 0; // Left
    if (leftColon && rightColon) {
      alignment = 1; // Center
    } else if (rightColon) {
      alignment = 2; // Right
    }

    [_columnAlignments addObject:@(alignment)];
  }
}

- (void)calculateColumnWidthsWithTextStorage:(NSTextStorage *)textStorage
                               markdownStyle:(RCTMarkdownStyle *)markdownStyle {
  [_columnWidths removeAllObjects];

  // Initialize column widths with minimum
  for (NSInteger i = 0; i < _columnCount; i++) {
    [_columnWidths addObject:@(_minColumnWidth)];
  }

  // Get the font for measurement
  UIFont *font = [UIFont fontWithName:markdownStyle.codeFontFamily size:markdownStyle.codeFontSize];
  if (font == nil) {
    font = [UIFont monospacedSystemFontOfSize:markdownStyle.codeFontSize weight:UIFontWeightRegular];
  }
  NSDictionary *attributes = @{NSFontAttributeName: font};

  NSString *text = textStorage.string;

  // Measure each cell and track max width per column
  for (NSUInteger rowIdx = 0; rowIdx < _cellRanges.count; rowIdx++) {
    // Skip delimiter row (row index 1) for width calculation
    if (rowIdx == 1) {
      continue;
    }

    NSArray<NSValue *> *rowCells = _cellRanges[rowIdx];
    for (NSUInteger colIdx = 0; colIdx < rowCells.count && colIdx < (NSUInteger)_columnCount; colIdx++) {
      NSRange cellRange = [rowCells[colIdx] rangeValue];

      if (cellRange.location + cellRange.length <= text.length) {
        NSString *cellContent = [text substringWithRange:cellRange];
        CGSize textSize = [cellContent sizeWithAttributes:attributes];
        CGFloat cellWidth = textSize.width + (_cellPaddingH * 2);

        CGFloat currentWidth = [_columnWidths[colIdx] floatValue];
        if (cellWidth > currentWidth) {
          _columnWidths[colIdx] = @(cellWidth);
        }
      }
    }
  }

  // Calculate total width
  _totalWidth = 0;
  for (NSNumber *width in _columnWidths) {
    _totalWidth += [width floatValue];
  }

  // Add 1pt for each column border (n+1 borders for n columns)
  _totalWidth += (_columnCount + 1);
}

- (CGFloat)xPositionForColumn:(NSInteger)column {
  CGFloat x = 1.0; // Start after left border
  for (NSInteger i = 0; i < column && i < (NSInteger)_columnWidths.count; i++) {
    x += [_columnWidths[i] floatValue] + 1.0; // +1 for border
  }
  return x;
}

@end
