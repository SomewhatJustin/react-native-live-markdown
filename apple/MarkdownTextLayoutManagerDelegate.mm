#import <RNLiveMarkdown/MarkdownTextLayoutManagerDelegate.h>
#import <RNLiveMarkdown/BlockquoteTextLayoutFragment.h>
#import <RNLiveMarkdown/CodeBlockTextLayoutFragment.h>
#import <RNLiveMarkdown/HorizontalRuleTextLayoutFragment.h>
#import <RNLiveMarkdown/MarkdownFormatter.h>

@implementation MarkdownTextLayoutManagerDelegate

- (NSTextLayoutFragment *)textLayoutManager:(NSTextLayoutManager *)textLayoutManager textLayoutFragmentForLocation:(id <NSTextLocation>)location inTextElement:(NSTextElement *)textElement {
  NSInteger index = [textLayoutManager offsetFromLocation:textLayoutManager.documentRange.location toLocation:location];
  if (index < self.textStorage.length) {
    // Check for code block
    NSNumber *isCodeBlock = [self.textStorage attribute:RCTLiveMarkdownCodeBlockAttributeName atIndex:index effectiveRange:nil];
    if (isCodeBlock != nil && [isCodeBlock boolValue]) {
      CodeBlockTextLayoutFragment *textLayoutFragment = [[CodeBlockTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
      textLayoutFragment.markdownUtils = _markdownUtils;
      return textLayoutFragment;
    }

    // Check for horizontal rule
    NSNumber *isHR = [self.textStorage attribute:RCTLiveMarkdownHorizontalRuleAttributeName atIndex:index effectiveRange:nil];
    if (isHR != nil && [isHR boolValue]) {
      HorizontalRuleTextLayoutFragment *textLayoutFragment = [[HorizontalRuleTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
      textLayoutFragment.markdownUtils = _markdownUtils;
      return textLayoutFragment;
    }

    // Check for blockquote
    NSNumber *depth = [self.textStorage attribute:RCTLiveMarkdownBlockquoteDepthAttributeName atIndex:index effectiveRange:nil];
    if (depth != nil) {
      BlockquoteTextLayoutFragment *textLayoutFragment = [[BlockquoteTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
      textLayoutFragment.markdownUtils = _markdownUtils;
      textLayoutFragment.depth = [depth unsignedIntValue];
      return textLayoutFragment;
    }
  }
  return [[NSTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
}

@end
