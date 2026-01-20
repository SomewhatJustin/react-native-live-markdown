#import "MarkdownFormatter.h"
#import <React/RCTFont.h>

@implementation MarkdownFormatter

- (BOOL)isInlineType:(NSString *)type {
  return [type isEqualToString:@"bold"] || [type isEqualToString:@"italic"] || [type isEqualToString:@"strikethrough"] || [type isEqualToString:@"link"];
}

/**
 * Get the line number (0-indexed) for a given character position.
 */
- (NSInteger)getLineNumber:(NSString *)text position:(NSInteger)position {
  if (position < 0 || position > (NSInteger)text.length) {
    return 0;
  }
  NSInteger line = 0;
  for (NSInteger i = 0; i < position; i++) {
    if ([text characterAtIndex:i] == '\n') {
      line++;
    }
  }
  return line;
}

/**
 * Check if a syntax range is adjacent to an inline content type (bold/italic/strikethrough).
 */
- (BOOL)isAdjacentToInlineType:(MarkdownRange *)syntaxRange allRanges:(NSArray<MarkdownRange *> *)allRanges {
  NSUInteger syntaxStart = syntaxRange.range.location;
  NSUInteger syntaxEnd = syntaxRange.range.location + syntaxRange.range.length;

  for (MarkdownRange *range in allRanges) {
    if ([self isInlineType:range.type]) {
      NSUInteger contentStart = range.range.location;
      NSUInteger contentEnd = range.range.location + range.range.length;
      // Adjacent if: syntax ends where content starts, or content ends where syntax starts
      if (syntaxEnd == contentStart || contentEnd == syntaxStart) {
        return YES;
      }
    }
  }
  return NO;
}

/**
 * Check if a syntax range overlaps an unordered list marker.
 */
- (BOOL)isListBulletSyntaxRange:(MarkdownRange *)syntaxRange allRanges:(NSArray<MarkdownRange *> *)allRanges {
  NSRange syntax = syntaxRange.range;
  for (MarkdownRange *range in allRanges) {
    if ([range.type isEqualToString:@"list-bullet"]) {
      if (NSIntersectionRange(syntax, range.range).length > 0) {
        return YES;
      }
    }
  }
  return NO;
}

/**
 * Check if a syntax range overlaps an ordered list marker.
 */
- (BOOL)isListNumberSyntaxRange:(MarkdownRange *)syntaxRange allRanges:(NSArray<MarkdownRange *> *)allRanges {
  NSRange syntax = syntaxRange.range;
  for (MarkdownRange *range in allRanges) {
    if ([range.type isEqualToString:@"list-number"]) {
      if (NSIntersectionRange(syntax, range.range).length > 0) {
        return YES;
      }
    }
  }
  return NO;
}

/**
 * Check if a syntax range looks like a list bullet marker even if we didn't get a list-bullet range.
 */
- (BOOL)isListBulletMarkerSyntaxRange:(NSRange)syntaxRange text:(NSString *)text {
  if (syntaxRange.location == NSNotFound || syntaxRange.location >= text.length) {
    return NO;
  }

  unichar marker = [text characterAtIndex:syntaxRange.location];
  if (marker != '-' && marker != '*' && marker != '+') {
    return NO;
  }

  NSUInteger nextIndex = syntaxRange.location + 1;
  if (nextIndex >= text.length) {
    return NO;
  }

  unichar nextChar = [text characterAtIndex:nextIndex];
  return nextChar == ' ' || nextChar == '\t';
}

/**
 * Check if a line contains a task marker.
 */
- (BOOL)isTaskMarkerOnLine:(NSInteger)line allRanges:(NSArray<MarkdownRange *> *)allRanges text:(NSString *)text {
  for (MarkdownRange *range in allRanges) {
    if ([range.type isEqualToString:@"task-unchecked"] || [range.type isEqualToString:@"task-checked"]) {
      NSInteger rangeLine = [self getLineNumber:text position:range.range.location];
      if (rangeLine == line) {
        return YES;
      }
    }
  }
  return NO;
}

/**
 * Check if this syntax range is adjacent to an inline formatted region (bold/italic/strikethrough)
 * and whether the cursor is within or immediately after that region.
 *
 * @param syntaxRange The syntax range being checked
 * @param allRanges All markdown ranges (to find adjacent inline content)
 * @param cursorPos The current cursor position
 * @return YES if syntax should be shown, NO if it should be hidden
 */
- (BOOL)shouldShowInlineSyntax:(MarkdownRange *)syntaxRange allRanges:(NSArray<MarkdownRange *> *)allRanges cursorPos:(NSInteger)cursorPos {
  // Find the adjacent inline content range
  MarkdownRange *contentRange = nil;
  NSUInteger syntaxStart = syntaxRange.range.location;
  NSUInteger syntaxEnd = syntaxRange.range.location + syntaxRange.range.length;

  for (MarkdownRange *range in allRanges) {
    if ([self isInlineType:range.type]) {
      NSUInteger contentStart = range.range.location;
      NSUInteger contentEnd = range.range.location + range.range.length;
      if (syntaxEnd == contentStart || contentEnd == syntaxStart) {
        contentRange = range;
        break;
      }
    }
  }

  if (contentRange == nil) {
    return YES; // No adjacent content found, show syntax
  }

  // Find the full zone: opening syntax + content + closing syntax
  // We need to find both syntax ranges that surround this content
  NSUInteger zoneStart = contentRange.range.location;
  NSUInteger zoneEnd = contentRange.range.location + contentRange.range.length;

  for (MarkdownRange *range in allRanges) {
    if ([range.type isEqualToString:@"syntax"]) {
      NSUInteger rangeEnd = range.range.location + range.range.length;
      // Opening syntax: ends where content starts
      if (rangeEnd == contentRange.range.location) {
        zoneStart = range.range.location;
      }
      // Closing syntax: starts where content ends
      if (range.range.location == contentRange.range.location + contentRange.range.length) {
        zoneEnd = range.range.location + range.range.length;
      }
    }
  }

  // Cursor is "in the zone" if it's anywhere within the formatted region
  // This includes the syntax characters and content, but NOT the position after
  return cursorPos >= (NSInteger)zoneStart && cursorPos <= (NSInteger)zoneEnd;
}

- (void)formatAttributedString:(nonnull NSMutableAttributedString *)attributedString
     withDefaultTextAttributes:(nonnull NSDictionary<NSAttributedStringKey, id> *)defaultTextAttributes
            withMarkdownRanges:(nonnull NSArray<MarkdownRange *> *)markdownRanges
             withMarkdownStyle:(nonnull RCTMarkdownStyle *)markdownStyle
            withCursorPosition:(NSInteger)cursorPosition
{
  NSRange fullRange = NSMakeRange(0, attributedString.length);

  [attributedString beginEditing];

  [attributedString setAttributes:defaultTextAttributes range:fullRange];

  // We add a custom attribute to force a different comparison mode in swizzled `_textOf` method.
  [attributedString addAttribute:RCTLiveMarkdownTextAttributeName value:@(YES) range:fullRange];

  NSString *text = attributedString.string;
  NSInteger cursorLine = cursorPosition >= 0 ? [self getLineNumber:text position:cursorPosition] : -1;

  for (MarkdownRange *markdownRange in markdownRanges) {
    [self applyRangeToAttributedString:attributedString
                                  type:std::string([markdownRange.type UTF8String])
                                 range:markdownRange.range
                                 depth:(int)markdownRange.depth
                         markdownStyle:markdownStyle
                 defaultTextAttributes:defaultTextAttributes
                         markdownRange:markdownRange
                             allRanges:markdownRanges
                                  text:text
                            cursorLine:cursorLine
                        cursorPosition:cursorPosition];
  }

  [attributedString.string enumerateSubstringsInRange:fullRange
                                              options:NSStringEnumerationByLines | NSStringEnumerationSubstringNotRequired
                                           usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
    RCTApplyBaselineOffset(attributedString, enclosingRange);
  }];

  [attributedString fixAttributesInRange:fullRange];

  [attributedString endEditing];
}

- (void)applyRangeToAttributedString:(NSMutableAttributedString *)attributedString
                                type:(const std::string)type
                               range:(const NSRange)range
                               depth:(const int)depth
                       markdownStyle:(nonnull RCTMarkdownStyle *)markdownStyle
               defaultTextAttributes:(nonnull NSDictionary<NSAttributedStringKey, id> *)defaultTextAttributes
                       markdownRange:(MarkdownRange *)markdownRange
                           allRanges:(NSArray<MarkdownRange *> *)allRanges
                                text:(NSString *)text
                          cursorLine:(NSInteger)cursorLine
                      cursorPosition:(NSInteger)cursorPosition
{
  if (type == "bold" || type == "italic" || type == "code" || type == "pre" || type == "h1" || type == "h2" || type == "h3" || type == "h4" || type == "h5" || type == "h6" || type == "emoji") {
    UIFont *font = [attributedString attribute:NSFontAttributeName atIndex:range.location effectiveRange:NULL];
    if (type == "bold") {
      // Check if already italic
      UIFontDescriptorSymbolicTraits currentTraits = font.fontDescriptor.symbolicTraits;
      BOOL wasItalic = (currentTraits & UIFontDescriptorTraitItalic) != 0;

      if (wasItalic) {
        // Need bold+italic - use bold font with oblique transform
        UIFont *boldFont = [UIFont boldSystemFontOfSize:font.pointSize];
        CGAffineTransform matrix = CGAffineTransformMake(1, 0, 0.25, 1, 0, 0); // Oblique transform
        UIFontDescriptor *desc = [boldFont.fontDescriptor fontDescriptorWithMatrix:matrix];
        font = [UIFont fontWithDescriptor:desc size:font.pointSize];
      } else {
        font = [UIFont boldSystemFontOfSize:font.pointSize];
      }
    } else if (type == "italic") {
      // Check if already bold
      UIFontDescriptorSymbolicTraits currentTraits = font.fontDescriptor.symbolicTraits;
      BOOL wasBold = (currentTraits & UIFontDescriptorTraitBold) != 0;

      if (wasBold) {
        // Need bold+italic - apply oblique transform to current bold font
        CGAffineTransform matrix = CGAffineTransformMake(1, 0, 0.25, 1, 0, 0); // Oblique transform
        UIFontDescriptor *desc = [font.fontDescriptor fontDescriptorWithMatrix:matrix];
        font = [UIFont fontWithDescriptor:desc size:font.pointSize];
      } else {
        font = [UIFont italicSystemFontOfSize:font.pointSize];
      }
    } else if (type == "code") {
      font = [RCTFont updateFont:font withFamily:markdownStyle.codeFontFamily
                                            size:[NSNumber numberWithFloat:markdownStyle.codeFontSize]
                                          weight:nil
                                            style:nil
                                          variant:nil
                                  scaleMultiplier:0];
    } else if (type == "pre") {
      font = [RCTFont updateFont:font withFamily:markdownStyle.preFontFamily
                                            size:[NSNumber numberWithFloat:markdownStyle.preFontSize]
                                          weight:nil
                                          style:nil
                                        variant:nil
                                scaleMultiplier:0];
    } else if (type == "h1") {
      font = [RCTFont updateFont:font withFamily:nil
                                            size:[NSNumber numberWithFloat:markdownStyle.h1FontSize]
                                          weight:@"bold"
                                            style:nil
                                          variant:nil
                                  scaleMultiplier:0];
    } else if (type == "h2") {
      font = [RCTFont updateFont:font withFamily:nil
                                            size:[NSNumber numberWithFloat:markdownStyle.h2FontSize]
                                          weight:@"bold"
                                            style:nil
                                          variant:nil
                                  scaleMultiplier:0];
    } else if (type == "h3") {
      font = [RCTFont updateFont:font withFamily:nil
                                            size:[NSNumber numberWithFloat:markdownStyle.h3FontSize]
                                          weight:@"bold"
                                            style:nil
                                          variant:nil
                                  scaleMultiplier:0];
    } else if (type == "h4") {
      font = [RCTFont updateFont:font withFamily:nil
                                            size:[NSNumber numberWithFloat:markdownStyle.h4FontSize]
                                          weight:@"bold"
                                            style:nil
                                          variant:nil
                                  scaleMultiplier:0];
    } else if (type == "h5") {
      font = [RCTFont updateFont:font withFamily:nil
                                            size:[NSNumber numberWithFloat:markdownStyle.h5FontSize]
                                          weight:@"bold"
                                            style:nil
                                          variant:nil
                                  scaleMultiplier:0];
    } else if (type == "h6") {
      font = [RCTFont updateFont:font withFamily:nil
                                            size:[NSNumber numberWithFloat:markdownStyle.h6FontSize]
                                          weight:nil
                                            style:@"italic"
                                          variant:nil
                                  scaleMultiplier:0];
    } else if (type == "emoji") {
      font = [RCTFont updateFont:font withFamily:markdownStyle.emojiFontFamily
                                            size:[NSNumber numberWithFloat:markdownStyle.emojiFontSize]
                                          weight:nil
                                            style:nil
                                          variant:nil
                                  scaleMultiplier:0];
    }
    [attributedString addAttribute:NSFontAttributeName value:font range:range];

    // Apply bold/italic colors (Obsidian-style pink)
    if (type == "bold" && markdownStyle.boldColor != nil) {
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.boldColor range:range];
    } else if (type == "italic" && markdownStyle.italicColor != nil) {
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.italicColor range:range];
    }

    // Apply heading colors if specified
    if (type == "h1" && markdownStyle.h1Color != nil) {
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.h1Color range:range];
    } else if (type == "h2" && markdownStyle.h2Color != nil) {
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.h2Color range:range];
    } else if (type == "h3" && markdownStyle.h3Color != nil) {
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.h3Color range:range];
    } else if (type == "h4" && markdownStyle.h4Color != nil) {
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.h4Color range:range];
    } else if (type == "h5" && markdownStyle.h5Color != nil) {
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.h5Color range:range];
    } else if (type == "h6" && markdownStyle.h6Color != nil) {
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.h6Color range:range];
    }
  }

  if (type == "syntax") {
    // Check if this is inline syntax (adjacent to bold/italic/strikethrough)
    BOOL isInlineSyntax = [self isAdjacentToInlineType:markdownRange allRanges:allRanges];
    BOOL isListBulletSyntax = [self isListBulletSyntaxRange:markdownRange allRanges:allRanges];
    BOOL isListNumberSyntax = [self isListNumberSyntaxRange:markdownRange allRanges:allRanges];
    BOOL isListBulletMarker = isListBulletSyntax || [self isListBulletMarkerSyntaxRange:range text:text];

    if (isInlineSyntax) {
      // For inline syntax, show/hide based on cursor position within the formatted zone
      BOOL shouldShow = [self shouldShowInlineSyntax:markdownRange allRanges:allRanges cursorPos:cursorPosition];
      if (shouldShow) {
        [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
      } else {
        // Hide by making transparent and using tiny font to collapse space
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];
        UIFont *tinyFont = [UIFont systemFontOfSize:0.01];
        [attributedString addAttribute:NSFontAttributeName value:tinyFont range:range];
      }
    } else {
      // Block-level syntax (headings, lists, etc.) - show/hide based on cursor line
      NSInteger syntaxLine = [self getLineNumber:text position:range.location];
      if (cursorLine == syntaxLine) {
        [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
      } else {
        // Hide by making transparent and using tiny font to collapse space
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];
        if (isListBulletMarker) {
          [attributedString addAttribute:RCTLiveMarkdownListBulletAttributeName value:@(YES) range:NSMakeRange(range.location, 1)];
        } else if (!isListBulletSyntax && !isListNumberSyntax) {
          UIFont *tinyFont = [UIFont systemFontOfSize:0.01];
          [attributedString addAttribute:NSFontAttributeName value:tinyFont range:range];
        }
      }
    }
  } else if (type == "strikethrough") {
    [attributedString addAttribute:NSStrikethroughStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:range];
  } else if (type == "code") {
    [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.codeColor range:range];
    [attributedString addAttribute:NSBackgroundColorAttributeName value:markdownStyle.codeBackgroundColor range:range];
  } else if (type == "mention-here") {
    [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.mentionHereColor range:range];
    [attributedString addAttribute:NSBackgroundColorAttributeName value:markdownStyle.mentionHereBackgroundColor range:range];
  } else if (type == "mention-user") {
    // TODO: change mention color when it mentions current user
    [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.mentionUserColor range:range];
    [attributedString addAttribute:NSBackgroundColorAttributeName value:markdownStyle.mentionUserBackgroundColor range:range];
  } else if (type == "mention-report") {
    [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.mentionReportColor range:range];
    [attributedString addAttribute:NSBackgroundColorAttributeName value:markdownStyle.mentionReportBackgroundColor range:range];
  } else if (type == "link") {
    [attributedString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:range];
    [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.linkColor range:range];
  } else if (type == "blockquote") {
    CGFloat indent = (markdownStyle.blockquoteMarginLeft + markdownStyle.blockquoteBorderWidth + markdownStyle.blockquotePaddingLeft) * depth;
    NSParagraphStyle *defaultParagraphStyle = defaultTextAttributes[NSParagraphStyleAttributeName];
    NSMutableParagraphStyle *paragraphStyle = defaultParagraphStyle != nil ? [defaultParagraphStyle mutableCopy] : [NSMutableParagraphStyle new];
    paragraphStyle.firstLineHeadIndent = indent;
    paragraphStyle.headIndent = indent;
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
    [attributedString addAttribute:RCTLiveMarkdownBlockquoteDepthAttributeName value:@(depth) range:range];
    // Apply teal text color and italic style like Obsidian - only for outermost level
    // Nested blockquotes use black text (default)
    if (depth == 1 && markdownStyle.blockquoteTextColor != nil) {
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.blockquoteTextColor range:range];
      // Apply italic font only for outermost level
      UIFont *font = [attributedString attribute:NSFontAttributeName atIndex:range.location effectiveRange:NULL];
      font = [UIFont italicSystemFontOfSize:font.pointSize];
      [attributedString addAttribute:NSFontAttributeName value:font range:range];
    }
  } else if (type == "pre") {
    [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.preColor range:range];
    // Apply background color to text (highlight style)
    NSRange rangeForBackground = [[attributedString string] characterAtIndex:range.location] == '\n' ? NSMakeRange(range.location + 1, range.length - 1) : range;
    [attributedString addAttribute:NSBackgroundColorAttributeName value:markdownStyle.preBackgroundColor range:rangeForBackground];
    // Also mark for full-width code block background drawing in layout manager
    [attributedString addAttribute:RCTLiveMarkdownCodeBlockAttributeName value:@(YES) range:range];
  } else if (type == "task-unchecked" || type == "task-checked") {
    // Task checkbox - toggle between checkbox and editable characters
    NSInteger taskLine = [self getLineNumber:text position:range.location];

    // Add paragraph spacing for all task items to improve tap targets
    NSParagraphStyle *defaultParagraphStyle = defaultTextAttributes[NSParagraphStyleAttributeName];
    NSMutableParagraphStyle *paragraphStyle = defaultParagraphStyle != nil ? [defaultParagraphStyle mutableCopy] : [NSMutableParagraphStyle new];
    paragraphStyle.paragraphSpacingBefore = 4.0;
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];

    if (cursorLine == taskLine) {
      // Cursor on line: show raw characters (- [ ] or - [x]) for editing
      UIFont *font = defaultTextAttributes[NSFontAttributeName];
      [attributedString addAttribute:NSFontAttributeName value:font range:range];
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
    } else {
      // Cursor not on line: hide raw characters and mark for custom checkbox drawing
      UIFont *font = defaultTextAttributes[NSFontAttributeName];
      [attributedString addAttribute:NSFontAttributeName value:font range:range];
      [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];
      // Mark this range for checkbox drawing in the layout manager
      BOOL isChecked = (type == "task-checked");
      [attributedString addAttribute:RCTLiveMarkdownTaskCheckedAttributeName value:@(isChecked) range:range];
    }
  } else if (type == "task-content-checked") {
    // Gray out completed task text (like Obsidian)
    UIColor *grayColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    [attributedString addAttribute:NSForegroundColorAttributeName value:grayColor range:range];
  } else if (type == "list-bullet") {
    // List bullet - toggle between bullet point and editable characters
    NSInteger bulletLine = [self getLineNumber:text position:range.location];
    if (cursorLine == bulletLine) {
      // Cursor on line: show raw characters (-, *, +) for editing
      // Restore font (syntax handler sets tiny font to hide markers)
      UIFont *font = defaultTextAttributes[NSFontAttributeName];
      [attributedString addAttribute:NSFontAttributeName value:font range:range];
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
    } else {
      // Cursor not on line: hide raw characters and mark for custom bullet drawing
      // Keep normal font size so line fragment maintains height for drawing
      UIFont *font = defaultTextAttributes[NSFontAttributeName];
      [attributedString addAttribute:NSFontAttributeName value:font range:range];
      [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];
      // Mark this range for bullet drawing in the layout manager
      [attributedString addAttribute:RCTLiveMarkdownListBulletAttributeName value:@(YES) range:range];
    }
  } else if (type == "list-number") {
    // Ordered list numbers - toggle between number display and editable characters
    NSInteger numberLine = [self getLineNumber:text position:range.location];
    BOOL isTaskLine = [self isTaskMarkerOnLine:numberLine allRanges:allRanges text:text];
    UIFont *font = defaultTextAttributes[NSFontAttributeName];
    [attributedString addAttribute:NSFontAttributeName value:font range:range];
    if (cursorLine == numberLine || isTaskLine) {
      // Cursor on line: show raw characters (1., 2.) for editing
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
    } else {
      // Cursor not on line: hide raw characters and mark for custom number drawing
      [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];
      // Extract the number from the text (e.g., "1." -> 1, "42)" -> 42)
      NSString *numberText = [text substringWithRange:range];
      NSInteger number = [[numberText stringByTrimmingCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] integerValue];
      [attributedString addAttribute:RCTLiveMarkdownListNumberAttributeName value:@(number) range:range];
    }
  } else if (type == "hr") {
    // Thematic break / horizontal rule - toggle between line and editable characters
    NSInteger hrLine = [self getLineNumber:text position:range.location];
    if (cursorLine == hrLine) {
      // Cursor on line: show raw characters (---, ***, ___) for editing
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
    } else {
      // Cursor not on line: hide characters and mark for custom line drawing
      // Keep normal font size so line fragment maintains height for drawing
      [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];
      // Mark this range for horizontal rule drawing in the layout manager
      [attributedString addAttribute:RCTLiveMarkdownHorizontalRuleAttributeName value:@(YES) range:range];
    }
  } else if (type == "blockquote-marker") {
    // Hide blockquote markers based on cursor line
    NSInteger markerLine = [self getLineNumber:text position:range.location];
    if (cursorLine == markerLine) {
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
    } else {
      // Check if this is an "empty" blockquote line (just marker + whitespace)
      // If so, keep normal font to preserve line height for vertical bar rendering
      NSUInteger markerEnd = range.location + range.length;
      NSUInteger lineEnd = markerEnd;
      while (lineEnd < text.length && [text characterAtIndex:lineEnd] != '\n') {
        lineEnd++;
      }

      BOOL isEmptyLine = YES;
      for (NSUInteger i = markerEnd; i < lineEnd; i++) {
        unichar c = [text characterAtIndex:i];
        if (c != ' ' && c != '\t') {
          isEmptyLine = NO;
          break;
        }
      }

      [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];
      if (!isEmptyLine) {
        // Only use tiny font when there's other content to provide line height
        UIFont *tinyFont = [UIFont systemFontOfSize:0.01];
        [attributedString addAttribute:NSFontAttributeName value:tinyFont range:range];
      }
    }
  } else if (type == "table") {
    // Table block - mark for custom rendering and apply monospace font
    [attributedString addAttribute:RCTLiveMarkdownTableAttributeName value:@(YES) range:range];

    // Store the full table range for fragment rendering
    [attributedString addAttribute:RCTLiveMarkdownTableRangeAttributeName value:[NSValue valueWithRange:range] range:range];

    // Count columns by finding the header row (first line) and counting pipes
    NSInteger columnCount = 0;
    NSUInteger lineEnd = range.location;
    while (lineEnd < range.location + range.length && lineEnd < text.length && [text characterAtIndex:lineEnd] != '\n') {
      if ([text characterAtIndex:lineEnd] == '|') {
        columnCount++;
      }
      lineEnd++;
    }
    // Number of columns is typically pipes - 1 (for |col1|col2|col3|)
    columnCount = MAX(1, columnCount - 1);
    [attributedString addAttribute:RCTLiveMarkdownTableColumnCountAttributeName value:@(columnCount) range:range];

    // Check if cursor is in this table
    NSInteger tableStartLine = [self getLineNumber:text position:range.location];
    NSInteger tableEndLine = [self getLineNumber:text position:range.location + range.length - 1];
    BOOL isCursorInTable = (cursorLine >= tableStartLine && cursorLine <= tableEndLine);
    [attributedString addAttribute:RCTLiveMarkdownTableCursorInTableAttributeName value:@(isCursorInTable) range:range];

    UIFont *font = [RCTFont updateFont:defaultTextAttributes[NSFontAttributeName] withFamily:markdownStyle.codeFontFamily
                                          size:[NSNumber numberWithFloat:markdownStyle.codeFontSize]
                                        weight:nil
                                          style:nil
                                        variant:nil
                                scaleMultiplier:0];
    [attributedString addAttribute:NSFontAttributeName value:font range:range];
  } else if (type == "table-row") {
    // Table row - cursor-line based visibility toggle
    NSInteger rowLine = [self getLineNumber:text position:range.location];

    // Find the table this row belongs to and calculate row index
    NSRange containingTableRange = NSMakeRange(NSNotFound, 0);
    NSInteger tableStartLine = -1;
    NSInteger tableEndLine = -1;
    for (MarkdownRange *tableRange in allRanges) {
      if ([tableRange.type isEqualToString:@"table"]) {
        NSInteger tStart = [self getLineNumber:text position:tableRange.range.location];
        NSInteger tEnd = [self getLineNumber:text position:tableRange.range.location + tableRange.range.length - 1];
        if (rowLine >= tStart && rowLine <= tEnd) {
          tableStartLine = tStart;
          tableEndLine = tEnd;
          containingTableRange = tableRange.range;
          break;
        }
      }
    }

    // Calculate row index (0=header, 1=delimiter, 2+=body)
    NSInteger rowIndex = rowLine - tableStartLine;
    [attributedString addAttribute:RCTLiveMarkdownTableRowIndexAttributeName value:@(rowIndex) range:range];
    [attributedString addAttribute:RCTLiveMarkdownTableRangeAttributeName value:[NSValue valueWithRange:containingTableRange] range:range];

    // Check if cursor is in table
    BOOL isCursorInTable = (cursorLine >= tableStartLine && cursorLine <= tableEndLine);
    [attributedString addAttribute:RCTLiveMarkdownTableCursorInTableAttributeName value:@(isCursorInTable) range:range];

    // If cursor is anywhere in this table, show raw markdown
    // Otherwise, table would be formatted (handled by table type)
    if (isCursorInTable) {
      // Show raw markdown - just style the pipes as syntax
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
    } else if (rowIndex == 0) {
      // Header row - make text bold when not editing
      UIFont *currentFont = defaultTextAttributes[NSFontAttributeName];
      UIFont *boldFont = [RCTFont updateFont:currentFont withFamily:nil
                                                size:nil
                                              weight:@"bold"
                                                style:nil
                                              variant:nil
                                      scaleMultiplier:0];
      [attributedString addAttribute:NSFontAttributeName value:boldFont range:range];
    }
  } else if (type == "table-delimiter") {
    // Delimiter row - hide when cursor is not in table
    NSInteger delimLine = [self getLineNumber:text position:range.location];
    // Find containing table
    NSRange containingTableRange = NSMakeRange(NSNotFound, 0);
    NSInteger tableStartLine = -1;
    NSInteger tableEndLine = -1;
    for (MarkdownRange *tableRange in allRanges) {
      if ([tableRange.type isEqualToString:@"table"]) {
        NSInteger tStart = [self getLineNumber:text position:tableRange.range.location];
        NSInteger tEnd = [self getLineNumber:text position:tableRange.range.location + tableRange.range.length - 1];
        if (delimLine >= tStart && delimLine <= tEnd) {
          tableStartLine = tStart;
          tableEndLine = tEnd;
          containingTableRange = tableRange.range;
          break;
        }
      }
    }

    // Delimiter row is always row index 1
    [attributedString addAttribute:RCTLiveMarkdownTableRowIndexAttributeName value:@(1) range:range];
    [attributedString addAttribute:RCTLiveMarkdownTableRangeAttributeName value:[NSValue valueWithRange:containingTableRange] range:range];

    BOOL isCursorInTable = (cursorLine >= tableStartLine && cursorLine <= tableEndLine);
    [attributedString addAttribute:RCTLiveMarkdownTableCursorInTableAttributeName value:@(isCursorInTable) range:range];

    if (isCursorInTable) {
      // Cursor in table - show as syntax
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
    } else {
      // Hide delimiter row when not editing - keep normal font to preserve layout
      [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];
      // Don't use tiny font - it causes TextKit layout issues that collapse the table
    }
  } else if (type == "table-cell") {
    // Table cell content - determine if this is a header cell
    NSInteger cellLine = [self getLineNumber:text position:range.location];

    // Find containing table to calculate row index
    NSInteger tableStartLine = -1;
    NSInteger tableEndLine = -1;
    for (MarkdownRange *tableRange in allRanges) {
      if ([tableRange.type isEqualToString:@"table"]) {
        NSInteger tStart = [self getLineNumber:text position:tableRange.range.location];
        NSInteger tEnd = [self getLineNumber:text position:tableRange.range.location + tableRange.range.length - 1];
        if (cellLine >= tStart && cellLine <= tEnd) {
          tableStartLine = tStart;
          tableEndLine = tEnd;
          break;
        }
      }
    }

    NSInteger rowIndex = cellLine - tableStartLine;
    BOOL isCursorInTable = (cursorLine >= tableStartLine && cursorLine <= tableEndLine);
    BOOL isHeaderCell = (rowIndex == 0 && !isCursorInTable);

    UIFont *font;
    if (isHeaderCell) {
      // Header cells - use system font with bold weight for better appearance
      UIFont *baseFont = defaultTextAttributes[NSFontAttributeName];
      font = [UIFont boldSystemFontOfSize:baseFont.pointSize];
    } else {
      // Body cells - use monospace font
      font = [RCTFont updateFont:defaultTextAttributes[NSFontAttributeName] withFamily:markdownStyle.codeFontFamily
                                            size:[NSNumber numberWithFloat:markdownStyle.codeFontSize]
                                          weight:nil
                                            style:nil
                                          variant:nil
                                  scaleMultiplier:0];
    }
    [attributedString addAttribute:NSFontAttributeName value:font range:range];
  } else if (type == "table-pipe") {
    // Pipe characters - show when editing, hide when not in table
    NSInteger pipeLine = [self getLineNumber:text position:range.location];
    // Find containing table
    NSInteger tableStartLine = -1;
    NSInteger tableEndLine = -1;
    for (MarkdownRange *tableRange in allRanges) {
      if ([tableRange.type isEqualToString:@"table"]) {
        NSInteger tStart = [self getLineNumber:text position:tableRange.range.location];
        NSInteger tEnd = [self getLineNumber:text position:tableRange.range.location + tableRange.range.length - 1];
        if (pipeLine >= tStart && pipeLine <= tEnd) {
          tableStartLine = tStart;
          tableEndLine = tEnd;
          break;
        }
      }
    }

    BOOL isCursorInTable = (cursorLine >= tableStartLine && cursorLine <= tableEndLine);
    if (isCursorInTable) {
      // Cursor in table - show pipes as syntax for editing
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
    } else {
      // Hide pipes when not editing - keep spacing, visual borders drawn by TableTextLayoutFragment
      [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];
      // DON'T use tiny font - keep normal spacing so cell content doesn't collapse
    }
  } else if (type == "inline-image") {
    // Inline image - toggle between image display and raw markdown
    NSInteger imageLine = [self getLineNumber:text position:range.location];

    if (cursorLine == imageLine) {
      // Cursor on line: show raw markdown for editing
      [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
    } else {
      // Cursor not on line: hide raw markdown and mark for image rendering
      [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];

      // Find the URL from the nested 'link' range
      NSString *imageURL = nil;
      for (MarkdownRange *linkRange in allRanges) {
        if ([linkRange.type isEqualToString:@"link"]) {
          NSUInteger linkStart = linkRange.range.location;
          NSUInteger linkEnd = linkStart + linkRange.range.length;
          // Check if this link is within our inline-image range
          if (linkStart >= range.location && linkEnd <= range.location + range.length) {
            NSString *rawURL = [text substringWithRange:linkRange.range];
            // Strip optional title from markdown image syntax: url "title" or url 'title'
            // The URL ends at the first space (titles are separated by space)
            NSRange spaceRange = [rawURL rangeOfString:@" "];
            if (spaceRange.location != NSNotFound) {
              imageURL = [rawURL substringToIndex:spaceRange.location];
            } else {
              imageURL = rawURL;
            }
            break;
          }
        }
      }

      // Store URL for the layout fragment
      if (imageURL) {
        [attributedString addAttribute:RCTLiveMarkdownInlineImageURLAttributeName value:imageURL range:range];

        // Set paragraph style with large line height to reserve space for the image
        // This makes the image act as a block element, pushing content down
        // Use a large height since we don't know actual image dimensions until loaded
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        CGFloat imageHeight = 400.0 + 24.0; // Default image height + padding (will be refined when loaded)
        paragraphStyle.minimumLineHeight = imageHeight;
        paragraphStyle.maximumLineHeight = imageHeight;
        [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
      }
    }
  }
}

static void RCTApplyBaselineOffset(NSMutableAttributedString *attributedText, NSRange attributedTextRange)
{
  __block CGFloat maximumLineHeight = 0;

  [attributedText enumerateAttribute:NSParagraphStyleAttributeName
                             inRange:attributedTextRange
                             options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                          usingBlock:^(NSParagraphStyle *paragraphStyle, __unused NSRange range, __unused BOOL *stop) {
    if (!paragraphStyle) {
      return;
    }

    maximumLineHeight = MAX(paragraphStyle.maximumLineHeight, maximumLineHeight);
  }];

  if (maximumLineHeight == 0) {
    // `lineHeight` was not specified, nothing to do.
    return;
  }

  __block CGFloat maximumFontLineHeight = 0;

  [attributedText enumerateAttribute:NSFontAttributeName
                             inRange:attributedTextRange
                             options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                          usingBlock:^(UIFont *font, NSRange range, __unused BOOL *stop) {
    if (!font) {
      return;
    }

    maximumFontLineHeight = MAX(font.lineHeight, maximumFontLineHeight);
  }];

  if (maximumLineHeight < maximumFontLineHeight) {
    return;
  }

  CGFloat baseLineOffset = (maximumLineHeight - maximumFontLineHeight) / 2.0;
  [attributedText addAttribute:NSBaselineOffsetAttributeName
                         value:@(baseLineOffset)
                         range:attributedTextRange];
}

@end
