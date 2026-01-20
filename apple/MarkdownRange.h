#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MarkdownRange : NSObject

@property (nonatomic, strong) NSString *type;
@property (nonatomic) NSRange range;
@property (nonatomic) NSUInteger depth;
@property (nonatomic) NSInteger tableColumn;
@property (nonatomic, strong, nullable) NSString *tableAlignment;
@property (nonatomic) NSInteger tableColumnCount;

- (instancetype)initWithType:(NSString *)type range:(NSRange)range depth:(NSUInteger)depth;
- (instancetype)initWithType:(NSString *)type range:(NSRange)range depth:(NSUInteger)depth tableColumn:(NSInteger)tableColumn tableAlignment:(nullable NSString *)tableAlignment tableColumnCount:(NSInteger)tableColumnCount;

NS_ASSUME_NONNULL_END

@end
