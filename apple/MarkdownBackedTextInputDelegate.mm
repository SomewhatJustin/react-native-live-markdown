#import "MarkdownBackedTextInputDelegate.h"

#import <objc/message.h>

@implementation MarkdownBackedTextInputDelegate {
  __weak RCTUITextView *_textView;
  RCTMarkdownUtils *_markdownUtils;
  id<RCTBackedTextInputDelegate> _originalTextInputDelegate;
  NSInteger _lastCursorPosition;
}

- (instancetype)initWithTextView:(RCTUITextView *)textView markdownUtils:(RCTMarkdownUtils *)markdownUtils
{
  if (self = [super init]) {
    _textView = textView;
    _markdownUtils = markdownUtils;
    _originalTextInputDelegate = _textView.textInputDelegate;
    _textView.textInputDelegate = self;
    _lastCursorPosition = -1;
  }
  return self;
}

- (void)dealloc
{
  // Restore original text input delegate
  _textView.textInputDelegate = _originalTextInputDelegate;
}

- (void)textInputDidChangeSelection
{
  // Delegate the call to the original text input delegate
  [_originalTextInputDelegate textInputDidChangeSelection];

  // After adding a newline at the end of the blockquote, the typing attributes in the next line still contain
  // NSParagraphStyle with non-zero firstLineHeadIndent and headIntent added by `_updateTypingAttributes` call.
  // This causes the cursor to be shifted to the right instead of being located at the beginning of the line.
  // The following code resets firstLineHeadIndent and headIndent in NSParagraphStyle in typing attributes
  // in order to fix the position of the cursor.
  NSDictionary<NSAttributedStringKey, id> *typingAttributes = _textView.typingAttributes;
  if (typingAttributes[NSParagraphStyleAttributeName] != nil) {
    NSMutableDictionary *mutableTypingAttributes = [typingAttributes mutableCopy];
    NSMutableParagraphStyle *mutableParagraphStyle = [typingAttributes[NSParagraphStyleAttributeName] mutableCopy];
    mutableParagraphStyle.firstLineHeadIndent = 0;
    mutableParagraphStyle.headIndent = 0;
    mutableTypingAttributes[NSParagraphStyleAttributeName] = mutableParagraphStyle;
    _textView.typingAttributes = mutableTypingAttributes;
  }

  // Re-apply markdown formatting when cursor position changes (for syntax hiding)
  if (_textView == nil || _markdownUtils == nil || _textView.defaultTextAttributes == nil) {
    return;
  }

  // Get cursor position
  NSInteger cursorPosition = -1;
  UITextRange *selectedRange = _textView.selectedTextRange;
  if (selectedRange != nil) {
    cursorPosition = [_textView offsetFromPosition:_textView.beginningOfDocument toPosition:selectedRange.start];
  }

  // Only reformat if cursor position actually changed
  if (cursorPosition == _lastCursorPosition) {
    return;
  }
  _lastCursorPosition = cursorPosition;

  // Re-apply formatting with new cursor position by triggering text storage update
  [_textView.textStorage setAttributedString:_textView.attributedText];
}

// Delegate all remaining calls to the original text input delegate

- (void)textInputDidChange
{
  [_originalTextInputDelegate textInputDidChange];
}

- (void)textInputDidBeginEditing
{
  [_originalTextInputDelegate textInputDidBeginEditing];
}

- (void)textInputDidEndEditing
{
  [_originalTextInputDelegate textInputDidEndEditing];
}

- (void)textInputDidReturn
{
  [_originalTextInputDelegate textInputDidReturn];
}

- (BOOL)textInputShouldBeginEditing
{
  return [_originalTextInputDelegate textInputShouldBeginEditing];
}

- (nonnull NSString *)textInputShouldChangeText:(nonnull NSString *)text inRange:(NSRange)range
{
  // Check for Enter key press to handle list continuation
  if ([text isEqualToString:@"\n"]) {
    NSString *continuation = [self listContinuationForRange:range];
    if (continuation != nil) {
      return [_originalTextInputDelegate textInputShouldChangeText:continuation inRange:range];
    }
  }
  return [_originalTextInputDelegate textInputShouldChangeText:text inRange:range];
}

// Returns the text to insert for list continuation, or nil if not on a list line
- (NSString *)listContinuationForRange:(NSRange)range
{
  NSString *fullText = _textView.attributedText.string;
  if (fullText == nil || range.location > fullText.length) {
    return nil;
  }

  // Find the start of the current line
  NSUInteger lineStart = range.location;
  while (lineStart > 0 && [fullText characterAtIndex:lineStart - 1] != '\n') {
    lineStart--;
  }

  // Extract the current line (up to cursor position)
  NSString *currentLine = [fullText substringWithRange:NSMakeRange(lineStart, range.location - lineStart)];

  // Check for unordered list: spaces/tabs followed by -, *, or + and a space
  NSRegularExpression *ulRegex = [NSRegularExpression regularExpressionWithPattern:@"^([ \\t]*)([-*+])[ \\t]+" options:0 error:nil];
  NSTextCheckingResult *ulMatch = [ulRegex firstMatchInString:currentLine options:0 range:NSMakeRange(0, currentLine.length)];
  if (ulMatch != nil) {
    NSString *indent = [currentLine substringWithRange:[ulMatch rangeAtIndex:1]];
    NSString *marker = [currentLine substringWithRange:[ulMatch rangeAtIndex:2]];
    // Check if line only contains the list marker (empty item) - don't continue, let user exit list
    NSUInteger markerEnd = [ulMatch rangeAtIndex:0].length;
    NSString *content = [currentLine substringFromIndex:markerEnd];
    if ([content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0) {
      return nil; // Empty list item - don't continue
    }
    return [NSString stringWithFormat:@"\n%@%@ ", indent, marker];
  }

  // Check for ordered list: spaces/tabs followed by number, . or ), and a space
  NSRegularExpression *olRegex = [NSRegularExpression regularExpressionWithPattern:@"^([ \\t]*)(\\d+)([.)])[ \\t]+" options:0 error:nil];
  NSTextCheckingResult *olMatch = [olRegex firstMatchInString:currentLine options:0 range:NSMakeRange(0, currentLine.length)];
  if (olMatch != nil) {
    NSString *indent = [currentLine substringWithRange:[olMatch rangeAtIndex:1]];
    NSString *numberStr = [currentLine substringWithRange:[olMatch rangeAtIndex:2]];
    NSString *punct = [currentLine substringWithRange:[olMatch rangeAtIndex:3]];
    // Check if line only contains the list marker (empty item) - don't continue
    NSUInteger markerEnd = [olMatch rangeAtIndex:0].length;
    NSString *content = [currentLine substringFromIndex:markerEnd];
    if ([content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0) {
      return nil; // Empty list item - don't continue
    }
    NSInteger nextNumber = [numberStr integerValue] + 1;
    return [NSString stringWithFormat:@"\n%@%ld%@ ", indent, (long)nextNumber, punct];
  }

  return nil; // Not a list line
}

- (BOOL)textInputShouldEndEditing
{
  return [_originalTextInputDelegate textInputShouldEndEditing];
}

- (BOOL)textInputShouldReturn
{
  return [_originalTextInputDelegate textInputShouldReturn];
}

- (BOOL)textInputShouldSubmitOnReturn
{
  return [_originalTextInputDelegate textInputShouldSubmitOnReturn];
}

// This method is added as a patch in the New Expensify app.
// See https://github.com/Expensify/App/blob/fd4b9adc22144cb99db1a5634f8828a13fa8c374/patches/react-native%2B0.77.1%2B011%2BAdd-onPaste-to-TextInput.patch#L239
- (void)textInputDidPaste:(NSString *)type withData:(NSString *)data
{
  void (*func)(id, SEL, NSString*, NSString*) = (void (*)(id, SEL, NSString*, NSString*))objc_msgSend;
  func(_originalTextInputDelegate, @selector(textInputDidPaste:withData:), type, data);
}

@end
