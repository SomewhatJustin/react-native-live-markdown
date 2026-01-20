#import <RNLiveMarkdown/MarkdownTextLayoutManagerDelegate.h>
#import <RNLiveMarkdown/BlockquoteTextLayoutFragment.h>
#import <RNLiveMarkdown/CodeBlockTextLayoutFragment.h>
#import <RNLiveMarkdown/HorizontalRuleTextLayoutFragment.h>
#import <RNLiveMarkdown/InlineImageTextLayoutFragment.h>
#import <RNLiveMarkdown/ListBulletTextLayoutFragment.h>
#import <RNLiveMarkdown/ListNumberTextLayoutFragment.h>
#import <RNLiveMarkdown/TaskTextLayoutFragment.h>
#import <RNLiveMarkdown/TableTextLayoutFragment.h>
#import <RNLiveMarkdown/TableRenderContext.h>
#import <RNLiveMarkdown/MarkdownTextLayoutFragment.h>
#import <RNLiveMarkdown/MarkdownFormatter.h>
#import <RNLiveMarkdown/RCTMarkdownTextBackgroundWithRange.h>

@implementation MarkdownTextLayoutManagerDelegate

- (instancetype)init {
  if (self = [super init]) {
    _tableContextCache = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)invalidateTableContextCache {
  [_tableContextCache removeAllObjects];
}

- (TableRenderContext *)tableContextForRange:(NSRange)tableRange {
  NSValue *key = [NSValue valueWithRange:tableRange];
  TableRenderContext *context = _tableContextCache[key];

  if (context == nil) {
    context = [[TableRenderContext alloc] initWithTableRange:tableRange];
    [context parseTableStructureFromTextStorage:_textStorage];
    [context calculateColumnWidthsWithTextStorage:_textStorage markdownStyle:_markdownUtils.markdownStyle];
    _tableContextCache[key] = context;
  }

  return context;
}

- (NSTextLayoutFragment *)textLayoutManager:(NSTextLayoutManager *)textLayoutManager textLayoutFragmentForLocation:(id <NSTextLocation>)location inTextElement:(NSTextElement *)textElement {
  NSInteger index = [textLayoutManager offsetFromLocation:textLayoutManager.documentRange.location toLocation:location];
  if (index < self.textStorage.length) {
    NSString *text = self.textStorage.string;
    NSRange lineRange = NSMakeRange(NSNotFound, 0);
    if (index >= 0 && index <= (NSInteger)text.length) {
      lineRange = [text lineRangeForRange:NSMakeRange((NSUInteger)index, 0)];
    }

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

    // Check for list bullet (may be indented within the line)
    if (lineRange.location != NSNotFound && lineRange.length > 0) {
      __block NSRange bulletRange = NSMakeRange(NSNotFound, 0);
      [self.textStorage enumerateAttribute:RCTLiveMarkdownListBulletAttributeName
                                   inRange:lineRange
                                   options:0
                                usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value != nil && [value boolValue]) {
          bulletRange = range;
          *stop = YES;
        }
      }];
      if (bulletRange.location != NSNotFound) {
        ListBulletTextLayoutFragment *textLayoutFragment = [[ListBulletTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
        textLayoutFragment.markdownUtils = _markdownUtils;
        textLayoutFragment.markerLocation = bulletRange.location;
        textLayoutFragment.lineStartLocation = lineRange.location;
        return textLayoutFragment;
      }
    }

    // Check for ordered list number
    if (lineRange.location != NSNotFound && lineRange.length > 0) {
      __block NSRange numberRange = NSMakeRange(NSNotFound, 0);
      __block NSNumber *listNumberValue = nil;
      [self.textStorage enumerateAttribute:RCTLiveMarkdownListNumberAttributeName
                                   inRange:lineRange
                                   options:0
                                usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value != nil) {
          numberRange = range;
          listNumberValue = value;
          *stop = YES;
        }
      }];
      if (numberRange.location != NSNotFound && listNumberValue != nil) {
        ListNumberTextLayoutFragment *textLayoutFragment = [[ListNumberTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
        textLayoutFragment.markdownUtils = _markdownUtils;
        textLayoutFragment.markerLocation = numberRange.location;
        textLayoutFragment.lineStartLocation = lineRange.location;
        textLayoutFragment.listNumber = [listNumberValue integerValue];
        return textLayoutFragment;
      }
    }

    // Check for task checkbox
    if (lineRange.location != NSNotFound && lineRange.length > 0) {
      __block NSRange taskRange = NSMakeRange(NSNotFound, 0);
      __block NSNumber *taskCheckedValue = nil;
      [self.textStorage enumerateAttribute:RCTLiveMarkdownTaskCheckedAttributeName
                                   inRange:lineRange
                                   options:0
                                usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value != nil) {
          taskRange = range;
          taskCheckedValue = value;
          *stop = YES;
        }
      }];
      if (taskRange.location != NSNotFound && taskCheckedValue != nil) {
        TaskTextLayoutFragment *textLayoutFragment = [[TaskTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
        textLayoutFragment.markdownUtils = _markdownUtils;
        textLayoutFragment.isChecked = [taskCheckedValue boolValue];
        textLayoutFragment.markerLocation = taskRange.location;
        textLayoutFragment.lineStartLocation = lineRange.location;
        return textLayoutFragment;
      }
    }

    // Check for table
    NSNumber *isTable = [self.textStorage attribute:RCTLiveMarkdownTableAttributeName atIndex:index effectiveRange:nil];
    if (isTable != nil && [isTable boolValue]) {
      TableTextLayoutFragment *textLayoutFragment = [[TableTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
      textLayoutFragment.markdownUtils = _markdownUtils;
      textLayoutFragment.textStorage = _textStorage;

      // Get table metadata from attributes
      NSNumber *rowIndexAttr = [self.textStorage attribute:RCTLiveMarkdownTableRowIndexAttributeName atIndex:index effectiveRange:nil];
      textLayoutFragment.rowIndex = rowIndexAttr != nil ? [rowIndexAttr integerValue] : 0;

      NSValue *tableRangeValue = [self.textStorage attribute:RCTLiveMarkdownTableRangeAttributeName atIndex:index effectiveRange:nil];
      NSRange tableRange = tableRangeValue != nil ? [tableRangeValue rangeValue] : NSMakeRange(NSNotFound, 0);
      textLayoutFragment.tableRange = tableRange;

      NSNumber *columnCountAttr = [self.textStorage attribute:RCTLiveMarkdownTableColumnCountAttributeName atIndex:index effectiveRange:nil];
      textLayoutFragment.columnCount = columnCountAttr != nil ? [columnCountAttr integerValue] : 0;

      NSNumber *cursorInTableAttr = [self.textStorage attribute:RCTLiveMarkdownTableCursorInTableAttributeName atIndex:index effectiveRange:nil];
      BOOL cursorInTable = cursorInTableAttr != nil ? [cursorInTableAttr boolValue] : NO;
      textLayoutFragment.cursorInTable = cursorInTable;

      // Get or create table context for visual rendering
      if (tableRange.location != NSNotFound && !cursorInTable) {
        TableRenderContext *context = [self tableContextForRange:tableRange];
        context.cursorInTable = cursorInTable;
        textLayoutFragment.tableContext = context;
      }

      return textLayoutFragment;
    }

    // Check for inline image
    NSString *imageURL = [self.textStorage attribute:RCTLiveMarkdownInlineImageURLAttributeName atIndex:index effectiveRange:nil];
    if (imageURL != nil && imageURL.length > 0) {
      InlineImageTextLayoutFragment *textLayoutFragment = [[InlineImageTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
      textLayoutFragment.markdownUtils = _markdownUtils;
      textLayoutFragment.imageURL = imageURL;
      return textLayoutFragment;
    }

    // Check for blockquote
    NSNumber *depth = [self.textStorage attribute:RCTLiveMarkdownBlockquoteDepthAttributeName atIndex:index effectiveRange:nil];
    
    NSAttributedString *attributedString = [(NSTextParagraph *)textElement attributedString];
    NSMutableArray<RCTMarkdownTextBackgroundWithRange *> *mentions = [NSMutableArray array];
    [attributedString enumerateAttribute:RCTLiveMarkdownTextBackgroundAttributeName
                                 inRange:NSMakeRange(0, attributedString.length)
                                 options:0
                              usingBlock:^(id value, NSRange range, BOOL *stop) {
      if (value) {
        RCTMarkdownTextBackgroundWithRange *textBackgroundWithRange = [[RCTMarkdownTextBackgroundWithRange alloc] init];
        textBackgroundWithRange.textBackground = value;
        textBackgroundWithRange.range = range;
        
        [mentions addObject:textBackgroundWithRange];
      }
    }];
    
    if (depth != nil || mentions.count > 0) {
      MarkdownTextLayoutFragment *textLayoutFragment = [[MarkdownTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
      textLayoutFragment.markdownUtils = _markdownUtils;
      textLayoutFragment.depth = depth != nil ? [depth unsignedIntValue] : 0;
      textLayoutFragment.mentions = mentions;
      return textLayoutFragment;
    }
  }
  return [[NSTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
}

@end
