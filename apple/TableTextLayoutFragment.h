#import <RNLiveMarkdown/RCTMarkdownUtils.h>
#import <RNLiveMarkdown/TableRenderContext.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TableTextLayoutFragment : NSTextLayoutFragment

@property (nonnull, atomic) RCTMarkdownUtils *markdownUtils;

/// Row index within the table: 0=header, 1=delimiter, 2+=body rows
@property (nonatomic) NSInteger rowIndex;

/// Full range of the containing table
@property (nonatomic) NSRange tableRange;

/// Whether the cursor is currently inside this table
@property (nonatomic) BOOL cursorInTable;

/// Number of columns in the table
@property (nonatomic) NSInteger columnCount;

/// Table render context for column width and cell data (weak to avoid retain cycle)
@property (nonatomic, weak, nullable) TableRenderContext *tableContext;

/// The text storage reference for accessing cell content
@property (nonatomic, weak, nullable) NSTextStorage *textStorage;

@end

NS_ASSUME_NONNULL_END
