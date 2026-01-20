#import <RNLiveMarkdown/InlineImageTextLayoutFragment.h>

static NSCache<NSString *, UIImage *> *imageCache = nil;
static NSMutableSet<NSString *> *loadingURLs = nil;
static dispatch_queue_t imageCacheQueue = nil;

@implementation InlineImageTextLayoutFragment

+ (void)initialize {
  if (self == [InlineImageTextLayoutFragment class]) {
    imageCache = [[NSCache alloc] init];
    imageCache.countLimit = 50;
    loadingURLs = [NSMutableSet set];
    imageCacheQueue = dispatch_queue_create("com.rnlivemarkdown.imagecache", DISPATCH_QUEUE_SERIAL);
  }
}

- (CGFloat)containerWidth {
  CGFloat containerWidth = 0;
  NSTextLayoutManager *layoutManager = self.textLayoutManager;
  if (layoutManager != nil && layoutManager.textContainer != nil) {
    containerWidth = layoutManager.textContainer.size.width;
  }
  // Fallback to reasonable default
  if (containerWidth <= 0) {
    containerWidth = 350.0;
  }
  return containerWidth;
}

- (CGSize)imageSizeForImage:(UIImage *)image maxWidth:(CGFloat)maxWidth maxHeight:(CGFloat)maxHeight {
  if (image == nil) {
    // Return placeholder size
    return CGSizeMake(MIN(maxWidth, 200.0), 150.0);
  }

  CGFloat imageWidth = image.size.width;
  CGFloat imageHeight = image.size.height;

  if (imageWidth <= 0 || imageHeight <= 0) {
    return CGSizeMake(MIN(maxWidth, 200.0), 150.0);
  }

  CGFloat aspectRatio = imageWidth / imageHeight;
  CGFloat targetWidth = imageWidth;
  CGFloat targetHeight = imageHeight;

  // Scale down if wider than max
  if (targetWidth > maxWidth) {
    targetWidth = maxWidth;
    targetHeight = targetWidth / aspectRatio;
  }

  // Scale down if taller than max
  if (targetHeight > maxHeight) {
    targetHeight = maxHeight;
    targetWidth = targetHeight * aspectRatio;
  }

  return CGSizeMake(targetWidth, targetHeight);
}

- (void)loadImageIfNeeded {
  if (_imageURL == nil || _imageURL.length == 0) {
    return;
  }

  // Check cache first
  UIImage *cached = [imageCache objectForKey:_imageURL];
  if (cached != nil) {
    return;
  }

  // Check if already loading
  __block BOOL isLoading = NO;
  dispatch_sync(imageCacheQueue, ^{
    isLoading = [loadingURLs containsObject:self->_imageURL];
    if (!isLoading) {
      [loadingURLs addObject:self->_imageURL];
    }
  });

  if (isLoading) {
    return;
  }

  // Start async load
  NSString *urlString = [_imageURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  // URL encode if needed
  NSString *encodedURLString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
  NSURL *url = [NSURL URLWithString:encodedURLString];
  if (url == nil) {
    url = [NSURL URLWithString:urlString]; // Try without encoding
  }
  if (url == nil) {
    dispatch_sync(imageCacheQueue, ^{
      [loadingURLs removeObject:urlString];
    });
    return;
  }

  __weak NSTextLayoutManager *weakLayoutManager = self.textLayoutManager;

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSData *data = [NSData dataWithContentsOfURL:url];
    UIImage *image = nil;
    if (data != nil) {
      image = [UIImage imageWithData:data];
    }

    dispatch_sync(imageCacheQueue, ^{
      [loadingURLs removeObject:urlString];
    });

    if (image != nil) {
      [imageCache setObject:image forKey:urlString];

      // Trigger re-layout on main thread
      dispatch_async(dispatch_get_main_queue(), ^{
        NSTextLayoutManager *layoutManager = weakLayoutManager;
        if (layoutManager != nil) {
          [layoutManager invalidateLayoutForRange:layoutManager.documentRange];
        }
      });
    }
  });
}

- (CGRect)renderingSurfaceBounds {
  CGRect bounds = [super renderingSurfaceBounds];

  // Start loading if needed
  [self loadImageIfNeeded];

  // Check if we have a cached image
  UIImage *image = nil;
  if (_imageURL != nil && _imageURL.length > 0) {
    image = [imageCache objectForKey:_imageURL];
  }

  // Use container width minus some padding
  CGFloat containerWidth = [self containerWidth];
  CGFloat maxWidth = containerWidth - 32.0; // 16pt padding on each side
  CGFloat maxHeight = 600.0; // Allow tall images
  CGSize imageSize = [self imageSizeForImage:image maxWidth:maxWidth maxHeight:maxHeight];

  // Expand bounds to fit image
  if (imageSize.height > bounds.size.height) {
    bounds.size.height = imageSize.height + 16.0; // Add padding
  }

  // Expand width to cover full container for proper layout
  CGFloat fragmentX = self.layoutFragmentFrame.origin.x;
  bounds.origin.x = -fragmentX;
  bounds.size.width = containerWidth;

  return bounds;
}

- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)ctx {
  CGRect bounds = [super renderingSurfaceBounds];

  // Check cache for image
  UIImage *image = nil;
  if (_imageURL != nil && _imageURL.length > 0) {
    image = [imageCache objectForKey:_imageURL];
  }

  // Use container width minus padding
  CGFloat containerWidth = [self containerWidth];
  CGFloat maxWidth = containerWidth - 32.0;
  CGFloat maxHeight = 600.0;
  CGSize imageSize = [self imageSizeForImage:image maxWidth:maxWidth maxHeight:maxHeight];

  // Draw centered horizontally with padding from top
  CGFloat fragmentX = self.layoutFragmentFrame.origin.x;
  CGFloat x = -fragmentX + (containerWidth - imageSize.width) / 2.0;
  CGFloat y = bounds.origin.y + 8.0; // Top padding

  CGFloat cornerRadius = 4.0; // Subtle rounded corners like Obsidian

  if (image != nil) {
    // Draw the loaded image with rounded corners
    CGRect imageRect = CGRectMake(x, y, imageSize.width, imageSize.height);

    CGContextSaveGState(ctx);
    UIBezierPath *clipPath = [UIBezierPath bezierPathWithRoundedRect:imageRect cornerRadius:cornerRadius];
    CGContextAddPath(ctx, clipPath.CGPath);
    CGContextClip(ctx);
    UIGraphicsPushContext(ctx);
    [image drawInRect:imageRect];
    UIGraphicsPopContext();
    CGContextRestoreGState(ctx);
  } else {
    // Draw loading placeholder with rounded corners
    CGRect placeholderRect = CGRectMake(x, y, imageSize.width, imageSize.height);

    // Gray background with rounded corners
    UIColor *backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    UIBezierPath *bgPath = [UIBezierPath bezierPathWithRoundedRect:placeholderRect cornerRadius:cornerRadius];
    CGContextSetFillColorWithColor(ctx, backgroundColor.CGColor);
    CGContextAddPath(ctx, bgPath.CGPath);
    CGContextFillPath(ctx);

    // Border with rounded corners
    UIColor *borderColor = [UIColor colorWithRed:0.85 green:0.85 blue:0.85 alpha:1.0];
    CGContextSetStrokeColorWithColor(ctx, borderColor.CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextAddPath(ctx, bgPath.CGPath);
    CGContextStrokePath(ctx);

    // "Loading..." text
    UIGraphicsPushContext(ctx);
    NSString *loadingText = @"Loading...";
    UIFont *font = [UIFont systemFontOfSize:14.0];
    UIColor *textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
    NSDictionary *attrs = @{
      NSFontAttributeName: font,
      NSForegroundColorAttributeName: textColor
    };
    CGSize textSize = [loadingText sizeWithAttributes:attrs];
    CGPoint textPoint = CGPointMake(
      x + (imageSize.width - textSize.width) / 2.0,
      y + (imageSize.height - textSize.height) / 2.0
    );
    [loadingText drawAtPoint:textPoint withAttributes:attrs];
    UIGraphicsPopContext();
  }

  // Don't call super - we don't want to draw the invisible text
}

@end
