#import <React/RCTBackedTextInputDelegate.h>
#import <React/RCTUITextView.h>
#import <RNLiveMarkdown/RCTMarkdownUtils.h>

NS_ASSUME_NONNULL_BEGIN

@interface MarkdownBackedTextInputDelegate : NSObject <RCTBackedTextInputDelegate>

- (instancetype)initWithTextView:(RCTUITextView *)textView markdownUtils:(RCTMarkdownUtils *)markdownUtils;

@end

NS_ASSUME_NONNULL_END
