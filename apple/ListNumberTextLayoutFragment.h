#import <RNLiveMarkdown/RCTMarkdownUtils.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ListNumberTextLayoutFragment : NSTextLayoutFragment

@property (nonnull, atomic) RCTMarkdownUtils *markdownUtils;
@property (nonatomic, assign) NSUInteger markerLocation;
@property (nonatomic, assign) NSUInteger lineStartLocation;
@property (nonatomic, assign) NSInteger listNumber;

@end

NS_ASSUME_NONNULL_END
