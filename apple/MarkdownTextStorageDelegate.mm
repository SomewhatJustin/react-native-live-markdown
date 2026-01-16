#import <RNLiveMarkdown/MarkdownTextStorageDelegate.h>
#import "react_native_assert.h"

@implementation MarkdownTextStorageDelegate {
  __weak RCTUITextView *_textView;
  RCTMarkdownUtils *_markdownUtils;
  NSInteger _lastCursorPosition;
}

- (instancetype)initWithTextView:(nonnull RCTUITextView *)textView markdownUtils:(nonnull RCTMarkdownUtils *)markdownUtils
{
  if ((self = [super init])) {
    react_native_assert(textView != nil);
    react_native_assert(markdownUtils != nil);

    _textView = textView;
    _markdownUtils = markdownUtils;
    _lastCursorPosition = -1;

    // Observe selection changes using UITextViewTextDidChangeNotification
    // Note: There's no dedicated selection change notification, so we use text change
    // and check for selection changes there. Selection changes during editing are
    // handled by textStorage:didProcessEditing:
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textViewDidChange:)
                                                 name:UITextViewTextDidChangeNotification
                                               object:textView];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)textViewDidChange:(NSNotification *)notification {
  // This is called on text changes - cursor position updates are handled in textStorage:didProcessEditing:
  // This notification handler exists to catch any edge cases
}

- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta {
  react_native_assert(_textView.defaultTextAttributes != nil);

  // Get cursor position
  NSInteger cursorPosition = -1;
  UITextRange *selectedRange = _textView.selectedTextRange;
  if (selectedRange != nil) {
    cursorPosition = [_textView offsetFromPosition:_textView.beginningOfDocument toPosition:selectedRange.start];
  }
  _lastCursorPosition = cursorPosition;

  [_markdownUtils applyMarkdownFormatting:textStorage withDefaultTextAttributes:_textView.defaultTextAttributes withCursorPosition:cursorPosition];
}

@end
