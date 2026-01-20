#import "MarkdownRange.h"

@implementation MarkdownRange

- (instancetype)initWithType:(NSString *)type range:(NSRange)range depth:(NSUInteger)depth {
  return [self initWithType:type range:range depth:depth tableColumn:-1 tableAlignment:nil tableColumnCount:0];
}

- (instancetype)initWithType:(NSString *)type range:(NSRange)range depth:(NSUInteger)depth tableColumn:(NSInteger)tableColumn tableAlignment:(nullable NSString *)tableAlignment tableColumnCount:(NSInteger)tableColumnCount {
  self = [super init];
  if (self) {
    _type = type;
    _range = range;
    _depth = depth;
    _tableColumn = tableColumn;
    _tableAlignment = tableAlignment;
    _tableColumnCount = tableColumnCount;
  }
  return self;
}

@end
