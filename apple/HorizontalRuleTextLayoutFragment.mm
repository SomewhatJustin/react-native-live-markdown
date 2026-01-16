#import <RNLiveMarkdown/HorizontalRuleTextLayoutFragment.h>

@implementation HorizontalRuleTextLayoutFragment

- (CGFloat)containerWidth {
  CGFloat containerWidth = 0;
  NSTextLayoutManager *layoutManager = self.textLayoutManager;
  if (layoutManager != nil && layoutManager.textContainer != nil) {
    containerWidth = layoutManager.textContainer.size.width;
  }
  return containerWidth;
}

- (CGRect)renderingSurfaceBounds {
  CGRect bounds = [super renderingSurfaceBounds];
  CGFloat containerWidth = [self containerWidth];

  if (containerWidth > 0) {
    // Expand bounds to cover full container width
    CGFloat fragmentX = self.layoutFragmentFrame.origin.x;
    bounds.origin.x = -fragmentX;
    bounds.size.width = containerWidth;
  }

  return bounds;
}

- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)ctx {
  CGFloat containerWidth = [self containerWidth];
  CGRect renderBounds = [super renderingSurfaceBounds];

  if (containerWidth <= 0) {
    containerWidth = renderBounds.size.width;
  }

  // Draw horizontal line - 80% width, centered in container
  CGFloat lineThickness = 1.0;
  CGFloat lineWidthPercent = 0.80;
  CGFloat lineWidth = containerWidth * lineWidthPercent;

  CGFloat fragmentX = self.layoutFragmentFrame.origin.x;

  CGFloat lineXInContainer = (containerWidth - lineWidth) / 2.0;
  CGFloat x = lineXInContainer - fragmentX;
  CGFloat y = renderBounds.origin.y + (renderBounds.size.height / 2.0);

  if (lineWidth > 0) {
    [_markdownUtils.markdownStyle.blockquoteBorderColor setFill];
    CGRect lineRect = CGRectMake(x, y - (lineThickness / 2.0), lineWidth, lineThickness);
    UIRectFill(lineRect);
  }

  // Don't call super - we don't want to draw the invisible text
}

@end
