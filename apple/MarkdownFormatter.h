#import <Foundation/Foundation.h>
#import <RNLiveMarkdown/MarkdownRange.h>
#import <RNLiveMarkdown/RCTMarkdownStyle.h>

NS_ASSUME_NONNULL_BEGIN

const NSAttributedStringKey RCTLiveMarkdownTextAttributeName = @"RCTLiveMarkdownText";

const NSAttributedStringKey RCTLiveMarkdownBlockquoteDepthAttributeName = @"RCTLiveMarkdownBlockquoteDepth";

const NSAttributedStringKey RCTLiveMarkdownHorizontalRuleAttributeName = @"RCTLiveMarkdownHorizontalRule";

const NSAttributedStringKey RCTLiveMarkdownCodeBlockAttributeName = @"RCTLiveMarkdownCodeBlock";

const NSAttributedStringKey RCTLiveMarkdownListBulletAttributeName = @"RCTLiveMarkdownListBullet";

const NSAttributedStringKey RCTLiveMarkdownListNumberAttributeName = @"RCTLiveMarkdownListNumber";

const NSAttributedStringKey RCTLiveMarkdownTaskCheckedAttributeName = @"RCTLiveMarkdownTaskChecked";

const NSAttributedStringKey RCTLiveMarkdownTableAttributeName = @"RCTLiveMarkdownTable";

const NSAttributedStringKey RCTLiveMarkdownTableRowIndexAttributeName = @"RCTLiveMarkdownTableRowIndex";

const NSAttributedStringKey RCTLiveMarkdownTableRangeAttributeName = @"RCTLiveMarkdownTableRange";

const NSAttributedStringKey RCTLiveMarkdownTableColumnCountAttributeName = @"RCTLiveMarkdownTableColumnCount";

const NSAttributedStringKey RCTLiveMarkdownTableCursorInTableAttributeName = @"RCTLiveMarkdownTableCursorInTable";

const NSAttributedStringKey RCTLiveMarkdownInlineImageURLAttributeName = @"RCTLiveMarkdownInlineImageURL";

@interface MarkdownFormatter : NSObject

- (void)formatAttributedString:(nonnull NSMutableAttributedString *)attributedString
     withDefaultTextAttributes:(nonnull NSDictionary<NSAttributedStringKey, id> *)defaultTextAttributes
            withMarkdownRanges:(nonnull NSArray<MarkdownRange *> *)markdownRanges
             withMarkdownStyle:(nonnull RCTMarkdownStyle *)markdownStyle
            withCursorPosition:(NSInteger)cursorPosition;

NS_ASSUME_NONNULL_END

@end
