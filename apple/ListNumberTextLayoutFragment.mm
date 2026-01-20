#import <RNLiveMarkdown/ListNumberTextLayoutFragment.h>
#import <CoreText/CoreText.h>

@implementation ListNumberTextLayoutFragment

- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)ctx {
  // Draw the list number
  CGRect renderBounds = [super renderingSurfaceBounds];

  // Get the font from the text storage to match the text size
  UIFont *font = [UIFont systemFontOfSize:17.0]; // Default size, will be overridden if we can get actual font

  // Try to get the actual font from the text content
  if (self.textLineFragments.count > 0) {
    NSTextLineFragment *lineFragment = self.textLineFragments.firstObject;
    if (lineFragment.attributedString.length > 0) {
      UIFont *actualFont = [lineFragment.attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:nil];
      if (actualFont) {
        font = actualFont;
      }
    }
  }

  // Use the syntax color for the number
  UIColor *numberColor = _markdownUtils.markdownStyle.syntaxColor;

  // Create attributed string with the number followed by period
  NSString *numberString = [NSString stringWithFormat:@"%ld.", (long)self.listNumber];
  NSDictionary *attrs = @{
    NSFontAttributeName: font,
    NSForegroundColorAttributeName: numberColor
  };
  NSAttributedString *numberAttrString = [[NSAttributedString alloc] initWithString:numberString attributes:attrs];

  // Calculate position - align with where the marker would have been
  // Use lineStartLocation (passed from layout manager) to calculate offset within the line
  CGFloat x = 0;
  CGFloat y = renderBounds.origin.y;
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
      // Just use the whitespace width as the x offset (indentation)
      x = trailingWhitespaceWidth;
    }
    y = lineFragment.typographicBounds.origin.y;
  }

  // Draw the number
  UIGraphicsPushContext(ctx);
  [numberAttrString drawAtPoint:CGPointMake(x, y)];
  UIGraphicsPopContext();

  // Call super to draw any remaining text content (the list item text)
  [super drawAtPoint:point inContext:ctx];
}

@end
