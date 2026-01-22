#import <RNLiveMarkdown/RCTMarkdownUtils.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TaskTextLayoutFragment : NSTextLayoutFragment

@property (nonnull, atomic) RCTMarkdownUtils *markdownUtils;
@property (nonatomic) BOOL isChecked;
@property (nonatomic, assign) NSUInteger markerLocation;
@property (nonatomic, assign) NSUInteger lineStartLocation;
// For ordered task lists: the list number (0 means no number / unordered)
@property (nonatomic, assign) NSInteger listNumber;
@property (nonatomic, assign) NSUInteger numberLocation;

@end

NS_ASSUME_NONNULL_END
