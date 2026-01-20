#import <RNLiveMarkdown/RCTMarkdownUtils.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface InlineImageTextLayoutFragment : NSTextLayoutFragment

@property (nonnull, atomic) RCTMarkdownUtils *markdownUtils;
@property (nonatomic, copy) NSString *imageURL;

@end

NS_ASSUME_NONNULL_END
