#import <RNLiveMarkdown/RCTMarkdownUtils.h>
#import <RNLiveMarkdown/TableRenderContext.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MarkdownTextLayoutManagerDelegate : NSObject <NSTextLayoutManagerDelegate>

@property (nonnull, atomic) NSTextStorage *textStorage;

@property (nonnull, atomic) RCTMarkdownUtils *markdownUtils;

/// Cache of TableRenderContext instances keyed by table range (as NSValue)
@property (nonatomic, strong) NSMutableDictionary<NSValue *, TableRenderContext *> *tableContextCache;

/// Invalidate cached table contexts (call when text changes)
- (void)invalidateTableContextCache;

@end

NS_ASSUME_NONNULL_END
