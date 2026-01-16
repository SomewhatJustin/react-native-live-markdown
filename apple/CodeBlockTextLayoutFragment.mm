#import <RNLiveMarkdown/CodeBlockTextLayoutFragment.h>

@implementation CodeBlockTextLayoutFragment

- (CGRect)boundingRect {
  CGRect fragmentTextBounds = CGRectNull;
  for (NSTextLineFragment *lineFragment in self.textLineFragments) {
    if (lineFragment.characterRange.length == 0) {
      continue;
    }
    CGRect lineFragmentBounds = lineFragment.typographicBounds;
    if (CGRectIsNull(fragmentTextBounds)) {
      fragmentTextBounds = lineFragmentBounds;
    } else {
      fragmentTextBounds = CGRectUnion(fragmentTextBounds, lineFragmentBounds);
    }
  }

  // Extend to full width (large value, will be clipped by container)
  fragmentTextBounds.origin.x = -1000;
  fragmentTextBounds.size.width = 3000;

  return fragmentTextBounds;
}

- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)ctx {
  [_markdownUtils.markdownStyle.preBackgroundColor setFill];

  CGRect boundingRect = self.boundingRect;
  UIRectFill(boundingRect);

  [super drawAtPoint:point inContext:ctx];
}

- (CGRect)renderingSurfaceBounds {
  return CGRectUnion(self.boundingRect, [super renderingSurfaceBounds]);
}

@end
