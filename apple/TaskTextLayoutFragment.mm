#import <RNLiveMarkdown/TaskTextLayoutFragment.h>
#import <CoreText/CoreText.h>

@implementation TaskTextLayoutFragment

- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)ctx {
  CGRect renderBounds = [super renderingSurfaceBounds];

  // Get the font from the text storage to match the text size
  UIFont *font = [UIFont systemFontOfSize:17.0];

  if (self.textLineFragments.count > 0) {
    NSTextLineFragment *lineFragment = self.textLineFragments.firstObject;
    if (lineFragment.attributedString.length > 0) {
      UIFont *actualFont = [lineFragment.attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:nil];
      if (actualFont) {
        font = actualFont;
      }
    }
  }

  CGFloat checkboxSize = font.pointSize * 0.9;
  CGFloat x = renderBounds.origin.x + 2.0;
  CGFloat y = renderBounds.origin.y + (font.lineHeight - checkboxSize) / 2 + 2.0;
  CGFloat cornerRadius = 3.0;

  // Use lineStartLocation (passed from layout manager) to calculate offset within the line
  if (self.markerLocation != NSNotFound && self.lineStartLocation != NSNotFound && self.textLineFragments.count > 0) {
    NSTextLineFragment *lineFragment = self.textLineFragments.firstObject;
    // Calculate offset from start of line to the marker
    NSUInteger offset = self.markerLocation - self.lineStartLocation;
    if (offset > lineFragment.attributedString.length) {
      offset = lineFragment.attributedString.length;
    }
    if (offset > 0) {
      NSAttributedString *prefix = [lineFragment.attributedString attributedSubstringFromRange:NSMakeRange(0, offset)];
      // Measure prefix width including trailing whitespace so indent-only prefixes still advance.
      CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)prefix);
      CGFloat trailingWhitespaceWidth = CTLineGetTrailingWhitespaceWidth(line);
      CFRelease(line);
      // Just use the whitespace width as the x offset (indentation) plus small padding
      x = trailingWhitespaceWidth + 2.0;
    } else {
      x = 2.0;
    }
    y = lineFragment.typographicBounds.origin.y + (font.lineHeight - checkboxSize) / 2 + 2.0;
  }

  UIGraphicsPushContext(ctx);

  if (_isChecked) {
    // Draw filled blue rounded rectangle
    UIColor *fillColor = [UIColor colorWithRed:0.35 green:0.47 blue:0.77 alpha:1.0]; // Obsidian blue #5A78C5
    [fillColor setFill];
    UIBezierPath *boxPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, y, checkboxSize, checkboxSize) cornerRadius:cornerRadius];
    [boxPath fill];

    // Draw white checkmark
    [[UIColor whiteColor] setStroke];
    UIBezierPath *checkPath = [UIBezierPath bezierPath];
    checkPath.lineWidth = 1.5;
    checkPath.lineCapStyle = kCGLineCapRound;
    checkPath.lineJoinStyle = kCGLineJoinRound;
    // Checkmark points
    CGFloat margin = checkboxSize * 0.25;
    [checkPath moveToPoint:CGPointMake(x + margin, y + checkboxSize * 0.5)];
    [checkPath addLineToPoint:CGPointMake(x + checkboxSize * 0.4, y + checkboxSize - margin)];
    [checkPath addLineToPoint:CGPointMake(x + checkboxSize - margin, y + margin)];
    [checkPath stroke];
  } else {
    // Draw empty rounded rectangle with gray border
    UIColor *borderColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.78 alpha:1.0]; // Light gray
    [borderColor setStroke];
    UIBezierPath *boxPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, y, checkboxSize, checkboxSize) cornerRadius:cornerRadius];
    boxPath.lineWidth = 1.5;
    [boxPath stroke];
  }

  UIGraphicsPopContext();

  [super drawAtPoint:point inContext:ctx];
}

@end
