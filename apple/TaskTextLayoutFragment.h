#import <RNLiveMarkdown/RCTMarkdownUtils.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TaskTextLayoutFragment : NSTextLayoutFragment

@property (nonnull, atomic) RCTMarkdownUtils *markdownUtils;
@property (nonatomic) BOOL isChecked;
@property (nonatomic, assign) NSUInteger markerLocation;
@property (nonatomic, assign) NSUInteger lineStartLocation;

@end

NS_ASSUME_NONNULL_END
