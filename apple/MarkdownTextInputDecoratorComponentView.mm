#import <react/debug/react_native_assert.h>
#import <react/renderer/components/RNLiveMarkdownSpec/Props.h>
#import <React/RCTFabricComponentsPlugins.h>
#import <React/RCTUITextField.h>
#import <React/RCTUITextView.h>
#import <React/RCTTextInputComponentView.h>

#import <RNLiveMarkdown/MarkdownBackedTextInputDelegate.h>
#import <RNLiveMarkdown/MarkdownTextLayoutManagerDelegate.h>
#import <RNLiveMarkdown/MarkdownTextFieldObserver.h>
#import <RNLiveMarkdown/MarkdownTextViewObserver.h>
#import <RNLiveMarkdown/MarkdownTextInputDecoratorComponentView.h>
#import <RNLiveMarkdown/MarkdownTextInputDecoratorViewComponentDescriptor.h>
#import <RNLiveMarkdown/MarkdownTextStorageDelegate.h>
#import <RNLiveMarkdown/MarkdownFormatter.h>
#import <RNLiveMarkdown/RCTMarkdownStyle.h>
#import <RNLiveMarkdown/RCTTextInput+AdaptiveImageGlyph.h>
#import <RNLiveMarkdown/TaskTextLayoutFragment.h>

#import <objc/runtime.h>
#import <CoreText/CoreText.h>

using namespace facebook::react;

@implementation MarkdownTextInputDecoratorComponentView {
  RCTMarkdownUtils *_markdownUtils;
  RCTMarkdownStyle *_markdownStyle;
  NSNumber *_parserId;
  MarkdownTextLayoutManagerDelegate *_markdownTextLayoutManagerDelegate;
  MarkdownBackedTextInputDelegate *_markdownBackedTextInputDelegate;
  MarkdownTextStorageDelegate *_markdownTextStorageDelegate;
  MarkdownTextViewObserver *_markdownTextViewObserver;
  MarkdownTextFieldObserver *_markdownTextFieldObserver;
  __weak RCTUITextView *_textView;
  __weak RCTUITextField *_textField;
  bool _observersAdded;
  UITapGestureRecognizer *_taskTapGestureRecognizer;
  BOOL _lastTapWasCheckbox;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<MarkdownTextInputDecoratorViewComponentDescriptor>();
}

// Needed because of this: https://github.com/facebook/react-native/pull/37274
+ (void)load
{
  [super load];
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const MarkdownTextInputDecoratorViewProps>();
    _props = defaultProps;
    _observersAdded = false;
    _markdownUtils = [[RCTMarkdownUtils alloc] init];
  }

  return self;
}

- (void)didAddSubview:(UIView *)subview
{
  [super didAddSubview:subview];
  [self addTextInputObservers];
}

- (void)willRemoveSubview:(UIView *)subview
{
  [self removeTextInputObservers];
  [super willRemoveSubview:subview];
}

- (void)addTextInputObservers
{
  react_native_assert(!_observersAdded && "MarkdownTextInputDecoratorComponentView tried to add TextInput observers while they were attached");
  react_native_assert(self.subviews.count > 0 && "MarkdownTextInputDecoratorComponentView is mounted without any children");
  UIView* childView = self.subviews[0];
  react_native_assert([childView isKindOfClass:[RCTTextInputComponentView class]] && "Child component of MarkdownTextInputDecoratorComponentView is not an instance of RCTTextInputComponentView.");
  RCTTextInputComponentView *textInputComponentView = (RCTTextInputComponentView *)childView;
  UIView<RCTBackedTextInputViewProtocol> *backedTextInputView = [textInputComponentView valueForKey:@"_backedTextInputView"];

  _observersAdded = true;

  if ([backedTextInputView isKindOfClass:[RCTUITextField class]]) {
    _textField = (RCTUITextField *)backedTextInputView;

    // make sure `adjustsFontSizeToFitWidth` is disabled, otherwise formatting will be overwritten
    react_native_assert(_textField.adjustsFontSizeToFitWidth == NO);

    // Enable TextField AdaptiveImageGlyph support
    [self enableAdaptiveImageGlyphSupport:_textField];

    _markdownTextFieldObserver = [[MarkdownTextFieldObserver alloc] initWithTextField:_textField markdownUtils:_markdownUtils];

    // register observers for future edits
    [_textField addTarget:_markdownTextFieldObserver action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_textField addTarget:_markdownTextFieldObserver action:@selector(textFieldDidEndEditing:) forControlEvents:UIControlEventEditingDidEnd];
    [_textField addObserver:_markdownTextFieldObserver forKeyPath:@"text" options:NSKeyValueObservingOptionNew context:NULL];
    [_textField addObserver:_markdownTextFieldObserver forKeyPath:@"attributedText" options:NSKeyValueObservingOptionNew context:NULL];

    // format initial value
    [_markdownTextFieldObserver textFieldDidChange:_textField];

    if (@available(iOS 16.0, *)) {
      auto key = [](std::string s) {
        std::reverse(s.begin(), s.end());
        return @(s.c_str());
      };
      
      NSTextContainer *textContainer = [_textField valueForKey:key("reniatnoCtxet_")];
      NSTextLayoutManager *textLayoutManager = [textContainer valueForKey:key("reganaMtuoyaLtxet_")];
      
      _markdownTextLayoutManagerDelegate = [[MarkdownTextLayoutManagerDelegate alloc] init];
      _markdownTextLayoutManagerDelegate.textStorage = [_textField valueForKey:key("egarotStxet_")];
      _markdownTextLayoutManagerDelegate.markdownUtils = _markdownUtils;
      textLayoutManager.delegate = _markdownTextLayoutManagerDelegate;
    }

    // TODO: register blockquotes layout manager
    // https://github.com/Expensify/react-native-live-markdown/issues/87
  } else if ([backedTextInputView isKindOfClass:[RCTUITextView class]]) {
    _textView = (RCTUITextView *)backedTextInputView;

    // Enable TextView AdaptiveImageGlyph support
    [self enableAdaptiveImageGlyphSupport:_textView];

    // register delegate for future edits
    react_native_assert(_textView.textStorage.delegate == nil);
    _markdownTextStorageDelegate = [[MarkdownTextStorageDelegate alloc] initWithTextView:_textView markdownUtils:_markdownUtils];
    _textView.textStorage.delegate = _markdownTextStorageDelegate;

    // register observer for default text attributes
    _markdownTextViewObserver = [[MarkdownTextViewObserver alloc] initWithTextView:_textView markdownUtils:_markdownUtils];
    [_textView addObserver:_markdownTextViewObserver forKeyPath:@"defaultTextAttributes" options:NSKeyValueObservingOptionNew context:NULL];

    // format initial value
    [_textView.textStorage setAttributedString:_textView.attributedText];

    react_native_assert(_textView.textLayoutManager != nil && "TextKit 2 must be enabled");
    _markdownTextLayoutManagerDelegate = [[MarkdownTextLayoutManagerDelegate alloc] init];
    _markdownTextLayoutManagerDelegate.textStorage = _textView.textStorage;
    _markdownTextLayoutManagerDelegate.markdownUtils = _markdownUtils;
    _textView.textLayoutManager.delegate = _markdownTextLayoutManagerDelegate;

    // register delegate for fixing cursor position after blockquote and selection change handling
    _markdownBackedTextInputDelegate = [[MarkdownBackedTextInputDelegate alloc] initWithTextView:_textView markdownUtils:_markdownUtils];

    // Add tap gesture recognizer for task checkbox toggling
    _taskTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTaskTap:)];
    _taskTapGestureRecognizer.delegate = self;
    [_textView addGestureRecognizer:_taskTapGestureRecognizer];
  } else {
    react_native_assert(false && "Cannot enable Markdown for this type of TextInput.");
  }
}

- (void)enableAdaptiveImageGlyphSupport:(UIView *)textInputView {
  if ([textInputView respondsToSelector:@selector(setSupportsAdaptiveImageGlyph:)]) {
    [textInputView setValue:@YES forKey:@"supportsAdaptiveImageGlyph"];
  }
}

- (void)disableAdaptiveImageGlyphSupport:(UIView *)textInputView {
  if ([textInputView respondsToSelector:@selector(setSupportsAdaptiveImageGlyph:)]) {
    [textInputView setValue:@NO forKey:@"supportsAdaptiveImageGlyph"];
  }
}

- (void)removeTextInputObservers
{
  react_native_assert(_observersAdded && "MarkdownTextInputDecoratorComponentView tried to remove TextInput observers while they were detached");
  _observersAdded = false;

  if (_textView != nil) {
    _textView.textLayoutManager.delegate = nil;
    _markdownBackedTextInputDelegate = nil;
    [_textView removeObserver:_markdownTextViewObserver forKeyPath:@"defaultTextAttributes" context:NULL];
    [self disableAdaptiveImageGlyphSupport:_textView];
    if (_taskTapGestureRecognizer != nil) {
      [_textView removeGestureRecognizer:_taskTapGestureRecognizer];
      _taskTapGestureRecognizer = nil;
    }
    _markdownTextViewObserver = nil;
    _markdownTextStorageDelegate = nil;
    _textView.textStorage.delegate = nil;
    _textView = nil;
  }

  if (_textField != nil) {
    [_textField removeTarget:_markdownTextFieldObserver action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [_textField removeTarget:_markdownTextFieldObserver action:@selector(textFieldDidEndEditing:) forControlEvents:UIControlEventEditingDidEnd];
    [_textField removeObserver:_markdownTextFieldObserver forKeyPath:@"text" context:NULL];
    [_textField removeObserver:_markdownTextFieldObserver forKeyPath:@"attributedText" context:NULL];
    [self disableAdaptiveImageGlyphSupport:_textField];
    _markdownTextFieldObserver = nil;
    _textField = nil;
  }
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
    const auto &oldViewProps = *std::static_pointer_cast<MarkdownTextInputDecoratorViewProps const>(_props);
    const auto &newViewProps = *std::static_pointer_cast<MarkdownTextInputDecoratorViewProps const>(props);

    if (oldViewProps.parserId != newViewProps.parserId) {
      _parserId = @(newViewProps.parserId);
      [_markdownUtils setParserId:_parserId];
    }

    // TODO: if (oldViewProps.markdownStyle != newViewProps.markdownStyle)
    _markdownStyle = [[RCTMarkdownStyle alloc] initWithStruct:newViewProps.markdownStyle];
    [_markdownUtils setMarkdownStyle:_markdownStyle];

    // TODO: call applyNewStyles only if needed
    [self applyNewStyles];

    [super updateProps:props oldProps:oldProps];
}

- (void)applyNewStyles
{
  if (_textView != nil) {
    [_textView.textStorage setAttributedString:_textView.attributedText];
  }
  if (_textField != nil) {
    [_markdownTextFieldObserver textFieldDidChange:_textField];
  }
}

- (void)prepareForRecycle
{
  react_native_assert(!_observersAdded && "MarkdownTextInputDecoratorComponentView was being recycled with TextInput observers still attached");
  [super prepareForRecycle];

  static const auto defaultProps = std::make_shared<const MarkdownTextInputDecoratorViewProps>();
  _props = defaultProps;
  _markdownUtils = [[RCTMarkdownUtils alloc] init];
}

Class<RCTComponentViewProtocol> MarkdownTextInputDecoratorViewCls(void)
{
  return MarkdownTextInputDecoratorComponentView.class;
}

#pragma mark - Task Checkbox Tap Handling

- (void)handleTaskTap:(UITapGestureRecognizer *)gesture {
  if (_textView == nil || gesture.state != UIGestureRecognizerStateEnded) {
    return;
  }

  CGPoint tapPoint = [gesture locationInView:_textView];

  // Only process taps in the left portion of the view where checkboxes appear
  // This includes some padding for ordered lists with numbers like "1. [x]"
  CGFloat maxCheckboxX = 60.0;
  if (tapPoint.x > maxCheckboxX) {
    return;
  }

  // Use UITextView's built-in method to find the closest text position
  UITextPosition *closestPosition = [_textView closestPositionToPoint:tapPoint];
  if (closestPosition == nil) {
    return;
  }

  // Get the character offset
  NSInteger charOffset = [_textView offsetFromPosition:_textView.beginningOfDocument toPosition:closestPosition];
  if (charOffset < 0 || charOffset >= (NSInteger)_textView.textStorage.length) {
    return;
  }

  // Get the line containing this character
  NSString *text = _textView.textStorage.string;
  NSRange lineRange = [text lineRangeForRange:NSMakeRange(charOffset, 0)];

  // Find task attribute in this line
  __block NSRange taskAttributeRange = NSMakeRange(NSNotFound, 0);
  [_textView.textStorage enumerateAttribute:RCTLiveMarkdownTaskCheckedAttributeName
                                    inRange:lineRange
                                    options:0
                                 usingBlock:^(id value, NSRange range, BOOL *stop) {
    if (value != nil) {
      taskAttributeRange = range;
      *stop = YES;
    }
  }];

  if (taskAttributeRange.location == NSNotFound) {
    return;
  }

  // Find the [ ] or [x] within the task attribute range
  NSRange bracketRange = [text rangeOfString:@"[" options:0 range:taskAttributeRange];
  if (bracketRange.location == NSNotFound || bracketRange.location + 2 >= text.length) {
    return;
  }

  // The checkbox character is at bracketRange.location + 1
  NSUInteger checkboxCharIndex = bracketRange.location + 1;
  unichar currentChar = [text characterAtIndex:checkboxCharIndex];

  // Toggle the checkbox
  NSString *newChar;
  if (currentChar == ' ') {
    newChar = @"x";
  } else if (currentChar == 'x' || currentChar == 'X') {
    newChar = @" ";
  } else {
    return; // Not a valid checkbox character
  }

  // Replace the character
  NSRange replaceRange = NSMakeRange(checkboxCharIndex, 1);
  [_textView.textStorage replaceCharactersInRange:replaceRange withString:newChar];

  // Mark that we handled this tap to prevent cursor placement
  _lastTapWasCheckbox = YES;
}

- (BOOL)isPointOnCheckbox:(CGPoint)point {
  if (_textView == nil) {
    return NO;
  }

  // Only check left portion where checkboxes appear
  CGFloat maxCheckboxX = 60.0;
  if (point.x > maxCheckboxX) {
    return NO;
  }

  UITextPosition *closestPosition = [_textView closestPositionToPoint:point];
  if (closestPosition == nil) {
    return NO;
  }

  NSInteger charOffset = [_textView offsetFromPosition:_textView.beginningOfDocument toPosition:closestPosition];
  if (charOffset < 0 || charOffset >= (NSInteger)_textView.textStorage.length) {
    return NO;
  }

  NSString *text = _textView.textStorage.string;
  NSRange lineRange = [text lineRangeForRange:NSMakeRange(charOffset, 0)];

  __block BOOL hasTaskAttribute = NO;
  [_textView.textStorage enumerateAttribute:RCTLiveMarkdownTaskCheckedAttributeName
                                    inRange:lineRange
                                    options:0
                                 usingBlock:^(id value, NSRange range, BOOL *stop) {
    if (value != nil) {
      hasTaskAttribute = YES;
      *stop = YES;
    }
  }];

  return hasTaskAttribute;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
  // Don't allow simultaneous recognition if we're handling a checkbox tap
  if (gestureRecognizer == _taskTapGestureRecognizer) {
    CGPoint point = [gestureRecognizer locationInView:_textView];
    if ([self isPointOnCheckbox:point]) {
      return NO; // Our gesture takes priority for checkbox taps
    }
  }
  return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
  // Our checkbox gesture should take priority over text view's tap gestures
  if (gestureRecognizer == _taskTapGestureRecognizer && otherGestureRecognizer.view == _textView) {
    CGPoint point = [gestureRecognizer locationInView:_textView];
    if ([self isPointOnCheckbox:point]) {
      return YES;
    }
  }
  return NO;
}

@end
