#import <UIKit/UIKit.h>
#import <RNLiveMarkdown/RCTMarkdownStyle.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * TableRenderContext manages table metadata and column width calculations
 * for visual table rendering.
 */
@interface TableRenderContext : NSObject

/// Range of the full table in the text storage
@property (nonatomic) NSRange tableRange;

/// Number of columns in the table
@property (nonatomic) NSInteger columnCount;

/// Number of rows in the table (including header and delimiter)
@property (nonatomic) NSInteger rowCount;

/// Calculated width for each column (indexed by column number)
@property (nonatomic, strong) NSMutableArray<NSNumber *> *columnWidths;

/// Alignment for each column: 0=left, 1=center, 2=right
@property (nonatomic, strong) NSMutableArray<NSNumber *> *columnAlignments;

/// Total calculated width of the table
@property (nonatomic) CGFloat totalWidth;

/// Whether the cursor is currently inside this table
@property (nonatomic) BOOL cursorInTable;

/// Cell content ranges (array of arrays: rows -> columns -> NSRange as NSValue)
@property (nonatomic, strong) NSMutableArray<NSMutableArray<NSValue *> *> *cellRanges;

/// Cell padding (horizontal)
@property (nonatomic, readonly) CGFloat cellPaddingH;

/// Cell padding (vertical)
@property (nonatomic, readonly) CGFloat cellPaddingV;

/// Minimum column width
@property (nonatomic, readonly) CGFloat minColumnWidth;

/// Initialize with table range
- (instancetype)initWithTableRange:(NSRange)tableRange;

/// Calculate column widths based on cell content
- (void)calculateColumnWidthsWithTextStorage:(NSTextStorage *)textStorage
                               markdownStyle:(RCTMarkdownStyle *)markdownStyle;

/// Parse table structure from text and populate cell ranges
- (void)parseTableStructureFromTextStorage:(NSTextStorage *)textStorage;

/// Get x position for a given column
- (CGFloat)xPositionForColumn:(NSInteger)column;

@end

NS_ASSUME_NONNULL_END
