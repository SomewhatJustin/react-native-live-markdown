#import "MarkdownFormatter.h"
#import <React/RCTFont.h>

@implementation MarkdownFormatter

- (BOOL)isInlineType:(NSString *)type {
  return [type isEqualToString:@"bold"] || [type isEqualToString:@"italic"] || [type isEqualToString:@"strikethrough"];
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
                                 depth:markdownRange.depth
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
  }

  if (type == "syntax") {
    // Check if this is inline syntax (adjacent to bold/italic/strikethrough)
    BOOL isInlineSyntax = [self isAdjacentToInlineType:markdownRange allRanges:allRanges];

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
        UIFont *tinyFont = [UIFont systemFontOfSize:0.01];
        [attributedString addAttribute:NSFontAttributeName value:tinyFont range:range];
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
  } else if (type == "pre") {
    [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.preColor range:range];
    // Apply background color to text (highlight style)
    NSRange rangeForBackground = [[attributedString string] characterAtIndex:range.location] == '\n' ? NSMakeRange(range.location + 1, range.length - 1) : range;
    [attributedString addAttribute:NSBackgroundColorAttributeName value:markdownStyle.preBackgroundColor range:rangeForBackground];
    // Also mark for full-width code block background drawing in layout manager
    [attributedString addAttribute:RCTLiveMarkdownCodeBlockAttributeName value:@(YES) range:range];
  } else if (type == "task-unchecked" || type == "task-checked") {
    [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
  } else if (type == "list-bullet" || type == "list-number") {
    [attributedString addAttribute:NSForegroundColorAttributeName value:markdownStyle.syntaxColor range:range];
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
      // Hide by making transparent and using tiny font to collapse space
      [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor clearColor] range:range];
      UIFont *tinyFont = [UIFont systemFontOfSize:0.01];
      [attributedString addAttribute:NSFontAttributeName value:tinyFont range:range];
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
