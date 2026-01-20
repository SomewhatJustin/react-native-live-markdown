#import <RNLiveMarkdown/RCTMarkdownStyle.h>

#import <React/RCTConversions.h>

@implementation RCTMarkdownStyle

- (instancetype)initWithStruct:(const facebook::react::MarkdownTextInputDecoratorViewMarkdownStyleStruct &)style
{
  if (self = [super init]) {
    _syntaxColor = RCTUIColorFromSharedColor(style.syntax.color);

    _linkColor = RCTUIColorFromSharedColor(style.link.color);

    // Obsidian-style pink for bold/italic emphasis
    _boldColor = [UIColor colorWithRed:0.85 green:0.54 blue:0.54 alpha:1.0]; // Pink #D98A8A
    _italicColor = [UIColor colorWithRed:0.85 green:0.54 blue:0.54 alpha:1.0]; // Pink #D98A8A

    _h1FontSize = style.h1.fontSize;
    // Compute h2-h6 as ratios of h1 if not explicitly provided
    _h2FontSize = _h1FontSize * 0.85f;
    _h3FontSize = _h1FontSize * 0.75f;
    _h4FontSize = _h1FontSize * 0.65f;
    _h5FontSize = _h1FontSize * 0.60f;
    _h6FontSize = _h1FontSize * 0.55f;

    // Heading colors - Obsidian-like defaults
    // H1/H2 inherit text color (nil), H3-H6 get distinct colors
    _h1Color = nil;
    _h2Color = nil;
    _h3Color = [UIColor colorWithRed:0.16 green:0.50 blue:0.73 alpha:1.0]; // Blue #2980B9
    _h4Color = [UIColor colorWithRed:0.83 green:0.65 blue:0.19 alpha:1.0]; // Gold #D4A62F
    _h5Color = [UIColor colorWithRed:0.83 green:0.33 blue:0.33 alpha:1.0]; // Red #D45454
    _h6Color = [UIColor colorWithRed:0.53 green:0.53 blue:0.53 alpha:1.0]; // Gray #888888

    _emojiFontSize = style.emoji.fontSize;
    _emojiFontFamily = RCTNSStringFromString(style.emoji.fontFamily);

    _blockquoteBorderColor = RCTUIColorFromSharedColor(style.blockquote.borderColor);
    _blockquoteBorderWidth = style.blockquote.borderWidth;
    _blockquoteMarginLeft = style.blockquote.marginLeft;
    _blockquotePaddingLeft = style.blockquote.paddingLeft;
    // Blockquote text color - teal/cyan like Obsidian
    _blockquoteTextColor = [UIColor colorWithRed:0.18 green:0.62 blue:0.62 alpha:1.0]; // Teal #2E9E9E

    _codeFontFamily = RCTNSStringFromString(style.code.fontFamily);
    _codeFontSize = style.code.fontSize;
    _codeColor = RCTUIColorFromSharedColor(style.code.color);
    _codeBackgroundColor = RCTUIColorFromSharedColor(style.code.backgroundColor);

    _preFontFamily = RCTNSStringFromString(style.pre.fontFamily);
    _preFontSize = style.pre.fontSize;
    _preColor = RCTUIColorFromSharedColor(style.pre.color);
    _preBackgroundColor = RCTUIColorFromSharedColor(style.pre.backgroundColor);

    _mentionHereColor = RCTUIColorFromSharedColor(style.mentionHere.color);
    _mentionHereBackgroundColor = RCTUIColorFromSharedColor(style.mentionHere.backgroundColor);

    _mentionUserColor = RCTUIColorFromSharedColor(style.mentionUser.color);
    _mentionUserBackgroundColor = RCTUIColorFromSharedColor(style.mentionUser.backgroundColor);

    _mentionReportColor = RCTUIColorFromSharedColor(style.mentionReport.color);
    _mentionReportBackgroundColor = RCTUIColorFromSharedColor(style.mentionReport.backgroundColor);

    // Table style - match Obsidian styling
    _tableBorderColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.77 alpha:1.0];
    _tableBorderWidth = 1.0;
    _tableBackgroundColor = [UIColor clearColor];
  }

  return self;
}

@end
