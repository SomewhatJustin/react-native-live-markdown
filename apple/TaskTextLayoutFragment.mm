#import <RNLiveMarkdown/TaskTextLayoutFragment.h>
#import <CoreText/CoreText.h>

@implementation TaskTextLayoutFragment

- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)ctx {
  CGRect renderBounds = [super renderingSurfaceBounds];

  // Use a fixed font size for checkbox drawing (don't use the hidden syntax font)
  __block UIFont *font = [UIFont systemFontOfSize:17.0];

  // Try to get the actual text font (skip tiny fonts used for hidden syntax)
  if (self.textLineFragments.count > 0) {
    NSTextLineFragment *lineFragment = self.textLineFragments.firstObject;
    [lineFragment.attributedString enumerateAttribute:NSFontAttributeName
                                              inRange:NSMakeRange(0, lineFragment.attributedString.length)
                                              options:0
                                           usingBlock:^(id value, NSRange range, BOOL *stop) {
      UIFont *attrFont = (UIFont *)value;
      if (attrFont && attrFont.pointSize > 10.0) { // Skip tiny fonts
        font = attrFont;
        *stop = YES;
      }
    }];
  }

  CGFloat checkboxSize = font.pointSize * 1.05;
  CGFloat checkboxX = renderBounds.origin.x;
  CGFloat y = renderBounds.origin.y + (font.lineHeight - checkboxSize) / 2 + 2.0;
  CGFloat cornerRadius = 4.0;
  CGFloat textY = renderBounds.origin.y;

  // Use lineStartLocation (passed from layout manager) to calculate offset within the line
  if (self.markerLocation != NSNotFound && self.lineStartLocation != NSNotFound && self.textLineFragments.count > 0) {
    NSTextLineFragment *lineFragment = self.textLineFragments.firstObject;
    textY = lineFragment.typographicBounds.origin.y;

    // Calculate offset from start of line to the marker (checkbox position)
    NSUInteger offset = self.markerLocation - self.lineStartLocation;
    if (offset > lineFragment.attributedString.length) {
      offset = lineFragment.attributedString.length;
    }
    if (offset > 0) {
      NSAttributedString *prefix = [lineFragment.attributedString attributedSubstringFromRange:NSMakeRange(0, offset)];
      // Measure the full width of the prefix text (including trailing whitespace)
      CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)prefix);
      CGFloat ascent, descent, leading;
      CGFloat prefixWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
      // Add trailing whitespace width since CTLineGetTypographicBounds doesn't include it
      prefixWidth += CTLineGetTrailingWhitespaceWidth(line);
      CFRelease(line);
      // Position checkbox after the prefix (minimal gap)
      checkboxX = prefixWidth;
    } else {
      checkboxX = 0.0;
    }
    y = textY + (font.lineHeight - checkboxSize) / 2 + 2.0;
  }

  UIGraphicsPushContext(ctx);

  // For ordered task lists, the number is rendered by the text system
  // We just need to draw the checkbox at the calculated position (after the number)

  if (_isChecked) {
    // Draw filled blue rounded rectangle
    UIColor *fillColor = [UIColor colorWithRed:0.35 green:0.47 blue:0.77 alpha:1.0]; // Obsidian blue #5A78C5
    [fillColor setFill];
    UIBezierPath *boxPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(checkboxX, y, checkboxSize, checkboxSize) cornerRadius:cornerRadius];
    [boxPath fill];

    // Draw white checkmark
    [[UIColor whiteColor] setStroke];
    UIBezierPath *checkPath = [UIBezierPath bezierPath];
    checkPath.lineWidth = 1.5;
    checkPath.lineCapStyle = kCGLineCapRound;
    checkPath.lineJoinStyle = kCGLineJoinRound;
    // Checkmark points
    CGFloat margin = checkboxSize * 0.25;
    [checkPath moveToPoint:CGPointMake(checkboxX + margin, y + checkboxSize * 0.5)];
    [checkPath addLineToPoint:CGPointMake(checkboxX + checkboxSize * 0.4, y + checkboxSize - margin)];
    [checkPath addLineToPoint:CGPointMake(checkboxX + checkboxSize - margin, y + margin)];
    [checkPath stroke];
  } else {
    // Draw empty rounded rectangle with gray border
    UIColor *borderColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.78 alpha:1.0]; // Light gray
    [borderColor setStroke];
    UIBezierPath *boxPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(checkboxX, y, checkboxSize, checkboxSize) cornerRadius:cornerRadius];
    boxPath.lineWidth = 1.5;
    [boxPath stroke];
  }

  UIGraphicsPopContext();

  [super drawAtPoint:point inContext:ctx];
}

@end
