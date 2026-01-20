#import <UIKit/UIKit.h>

#import <react/renderer/components/RNLiveMarkdownSpec/Props.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCTMarkdownStyle : NSObject

@property (nonatomic) UIColor *syntaxColor;
@property (nonatomic) UIColor *linkColor;
@property (nonatomic, nullable) UIColor *boldColor;
@property (nonatomic, nullable) UIColor *italicColor;
@property (nonatomic) CGFloat h1FontSize;
@property (nonatomic) CGFloat h2FontSize;
@property (nonatomic) CGFloat h3FontSize;
@property (nonatomic) CGFloat h4FontSize;
@property (nonatomic) CGFloat h5FontSize;
@property (nonatomic) CGFloat h6FontSize;
@property (nonatomic, nullable) UIColor *h1Color;
@property (nonatomic, nullable) UIColor *h2Color;
@property (nonatomic, nullable) UIColor *h3Color;
@property (nonatomic, nullable) UIColor *h4Color;
@property (nonatomic, nullable) UIColor *h5Color;
@property (nonatomic, nullable) UIColor *h6Color;
@property (nonatomic) CGFloat emojiFontSize;
@property (nonatomic) NSString *emojiFontFamily;
@property (nonatomic) UIColor *blockquoteBorderColor;
@property (nonatomic) CGFloat blockquoteBorderWidth;
@property (nonatomic) CGFloat blockquoteMarginLeft;
@property (nonatomic) CGFloat blockquotePaddingLeft;
@property (nonatomic, nullable) UIColor *blockquoteTextColor;
@property (nonatomic) NSString *codeFontFamily;
@property (nonatomic) CGFloat codeFontSize;
@property (nonatomic) UIColor *codeColor;
@property (nonatomic) UIColor *codeBackgroundColor;
@property (nonatomic) NSString *preFontFamily;
@property (nonatomic) CGFloat preFontSize;
@property (nonatomic) UIColor *preColor;
@property (nonatomic) UIColor *preBackgroundColor;
@property (nonatomic) UIColor *mentionHereColor;
@property (nonatomic) UIColor *mentionHereBackgroundColor;
@property (nonatomic) CGFloat mentionHereBorderRadius;
@property (nonatomic) UIColor *mentionUserColor;
@property (nonatomic) UIColor *mentionUserBackgroundColor;
@property (nonatomic) CGFloat mentionUserBorderRadius;
@property (nonatomic) UIColor *mentionReportColor;
@property (nonatomic) UIColor *mentionReportBackgroundColor;
@property (nonatomic) CGFloat mentionReportBorderRadius;
@property (nonatomic) UIColor *tableBorderColor;
@property (nonatomic) CGFloat tableBorderWidth;
@property (nonatomic) UIColor *tableBackgroundColor;

- (instancetype)initWithStruct:(const facebook::react::MarkdownTextInputDecoratorViewMarkdownStyleStruct &)style;

@end

NS_ASSUME_NONNULL_END
