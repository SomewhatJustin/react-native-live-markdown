#import <RNLiveMarkdown/TableTextLayoutFragment.h>
#import <React/RCTFont.h>

@implementation TableTextLayoutFragment

- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)ctx {
  // Always let TextKit draw the content first (handles inline formatting)
  [super drawAtPoint:point inContext:ctx];

  // If cursor is in table, just show raw markdown (already drawn by super)
  if (_cursorInTable) {
    return;
  }

  // Skip drawing borders for delimiter row (row index 1)
  if (_rowIndex == 1) {
    return;
  }

  // Draw visual borders for this table row
  [self drawTableBordersAtPoint:point inContext:ctx];
}

- (void)drawTableBordersAtPoint:(CGPoint)point inContext:(CGContextRef)ctx {
  CGRect bounds = [super renderingSurfaceBounds];
  RCTMarkdownStyle *style = _markdownUtils.markdownStyle;

  // Get style values
  UIColor *borderColor = style.tableBorderColor;
  if (borderColor == nil) {
    borderColor = [UIColor colorWithRed:0.85 green:0.85 blue:0.87 alpha:1.0];
  }

  CGFloat borderWidth = style.tableBorderWidth;
  if (borderWidth <= 0) {
    borderWidth = 1.0;
  }

  CGFloat rowHeight = bounds.size.height;
  CGFloat rowWidth = bounds.size.width;

  [borderColor setFill];
  [borderColor setStroke];

  CGContextSetLineWidth(ctx, borderWidth);

  // Draw left border
  CGContextMoveToPoint(ctx, bounds.origin.x, bounds.origin.y);
  CGContextAddLineToPoint(ctx, bounds.origin.x, bounds.origin.y + rowHeight);
  CGContextStrokePath(ctx);

  // Draw right border
  CGContextMoveToPoint(ctx, bounds.origin.x + rowWidth, bounds.origin.y);
  CGContextAddLineToPoint(ctx, bounds.origin.x + rowWidth, bounds.origin.y + rowHeight);
  CGContextStrokePath(ctx);

  // Draw bottom border
  CGContextMoveToPoint(ctx, bounds.origin.x, bounds.origin.y + rowHeight - borderWidth/2);
  CGContextAddLineToPoint(ctx, bounds.origin.x + rowWidth, bounds.origin.y + rowHeight - borderWidth/2);
  CGContextStrokePath(ctx);

  // Draw top border for header row only
  if (_rowIndex == 0) {
    CGContextMoveToPoint(ctx, bounds.origin.x, bounds.origin.y + borderWidth/2);
    CGContextAddLineToPoint(ctx, bounds.origin.x + rowWidth, bounds.origin.y + borderWidth/2);
    CGContextStrokePath(ctx);
  }

  // Draw vertical lines at pipe positions (column separators)
  // The pipes are invisible but still take up space, so find their positions
  if (_textStorage != nil && _tableRange.location != NSNotFound) {
    NSString *text = _textStorage.string;

    // Get the range of this line fragment
    NSTextLayoutManager *layoutManager = self.textLayoutManager;
    if (layoutManager != nil) {
      NSInteger fragmentStart = [layoutManager offsetFromLocation:layoutManager.documentRange.location
                                                       toLocation:self.rangeInElement.location];
      NSInteger fragmentEnd = fragmentStart + [layoutManager offsetFromLocation:self.rangeInElement.location
                                                                     toLocation:self.rangeInElement.endLocation];

      // Find pipe positions in this line and draw vertical borders
      for (NSInteger i = fragmentStart; i < fragmentEnd && i < (NSInteger)text.length; i++) {
        if ([text characterAtIndex:i] == '|') {
          // Find the x position of this pipe character
          id<NSTextLocation> pipeLocation = [layoutManager locationFromLocation:layoutManager.documentRange.location
                                                                     withOffset:i];
          if (pipeLocation != nil) {
            __block CGFloat pipeX = -1;

            [layoutManager enumerateTextLayoutFragmentsFromLocation:pipeLocation
                                                            options:0
                                                         usingBlock:^BOOL(NSTextLayoutFragment *fragment) {
              if (fragment == self) {
                for (NSTextLineFragment *lineFragment in fragment.textLineFragments) {
                  NSRange lineRange = lineFragment.characterRange;
                  NSInteger localIndex = i - fragmentStart;
                  if (localIndex >= (NSInteger)lineRange.location &&
                      localIndex < (NSInteger)(lineRange.location + lineRange.length)) {
                    CGFloat xInLine = [lineFragment locationForCharacterAtIndex:localIndex - lineRange.location].x;
                    pipeX = bounds.origin.x + xInLine;
                  }
                }
              }
              return NO; // Stop after first fragment
            }];

            if (pipeX >= 0) {
              CGContextMoveToPoint(ctx, pipeX, bounds.origin.y);
              CGContextAddLineToPoint(ctx, pipeX, bounds.origin.y + rowHeight);
              CGContextStrokePath(ctx);
            }
          }
        }
      }
    }
  }
}

@end
