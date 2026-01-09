package com.expensify.livemarkdown;

import android.content.Context;
import android.text.Editable;
import android.text.SpannableStringBuilder;
import android.text.TextWatcher;

import android.view.View;

import com.facebook.react.bridge.ReactContext;
import com.facebook.react.views.textinput.ReactEditText;
import com.facebook.react.views.view.ReactViewGroup;

public class MarkdownTextInputDecoratorView extends ReactViewGroup {

  public MarkdownTextInputDecoratorView(Context context) {
    super(context);
  }

  private MarkdownStyle mMarkdownStyle;

  private int mParserId;

  private MarkdownUtils mMarkdownUtils;

  private ReactEditText mReactEditText;

  private TextWatcher mTextWatcher;

  private int mLastCursorLine = -1;

  @Override
  protected void onAttachedToWindow() {
    super.onAttachedToWindow();

    View child = getChildAt(0);
    if (child instanceof ReactEditText) {
      mMarkdownUtils = new MarkdownUtils((ReactContext) getContext());
      mMarkdownUtils.setMarkdownStyle(mMarkdownStyle);
      mMarkdownUtils.setParserId(mParserId);
      mReactEditText = (ReactEditText) child;

      // Create a text watcher that also updates cursor position
      mTextWatcher = new TextWatcher() {
        @Override
        public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

        @Override
        public void onTextChanged(CharSequence s, int start, int before, int count) {}

        @Override
        public void afterTextChanged(Editable editable) {
          if (editable instanceof SpannableStringBuilder ssb) {
            updateCursorAndFormat(ssb);
          }
        }
      };
      mReactEditText.addTextChangedListener(mTextWatcher);

      // Also listen for selection changes (cursor movement without text change)
      mReactEditText.setAccessibilityDelegate(new View.AccessibilityDelegate() {
        @Override
        public void sendAccessibilityEvent(View host, int eventType) {
          super.sendAccessibilityEvent(host, eventType);
          // Selection change events trigger formatting update
          if (eventType == android.view.accessibility.AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED) {
            checkCursorLineChanged();
          }
        }
      });

      applyNewStyles();
    }
  }

  /**
   * Check if cursor moved to a different line, and re-format if so.
   */
  private void checkCursorLineChanged() {
    if (mReactEditText == null || mMarkdownUtils == null) return;

    int cursorPos = mReactEditText.getSelectionStart();
    String text = mReactEditText.getText().toString();
    int currentLine = getLineNumber(text, cursorPos);

    if (currentLine != mLastCursorLine) {
      mLastCursorLine = currentLine;
      Editable editable = mReactEditText.getText();
      if (editable instanceof SpannableStringBuilder ssb) {
        updateCursorAndFormat(ssb);
      }
    }
  }

  private void updateCursorAndFormat(SpannableStringBuilder ssb) {
    if (mReactEditText != null && mMarkdownUtils != null) {
      int cursorPos = mReactEditText.getSelectionStart();
      mMarkdownUtils.setCursorPosition(cursorPos);
      mMarkdownUtils.applyMarkdownFormatting(ssb);
    }
  }

  private int getLineNumber(String text, int position) {
    if (position < 0 || position > text.length()) return 0;
    int line = 0;
    for (int i = 0; i < position; i++) {
      if (text.charAt(i) == '\n') line++;
    }
    return line;
  }

  @Override
  protected void onDetachedFromWindow() {
    super.onDetachedFromWindow();
    if (mReactEditText != null) {
      mReactEditText.removeTextChangedListener(mTextWatcher);
      mReactEditText.setAccessibilityDelegate(null);
      mReactEditText = null;
      mTextWatcher = null;
      mMarkdownUtils = null;
    }
  }

  protected void setMarkdownStyle(MarkdownStyle markdownStyle) {
    mMarkdownStyle = markdownStyle;
    if (mMarkdownUtils != null) {
      mMarkdownUtils.setMarkdownStyle(mMarkdownStyle);
    }
    applyNewStyles();
  }

  protected void setParserId(int parserId) {
    mParserId = parserId;
    if (mMarkdownUtils != null) {
      mMarkdownUtils.setParserId(mParserId);
    }
    applyNewStyles();
  }

  protected void applyNewStyles() {
    if (mReactEditText != null && mMarkdownUtils != null) {
      Editable editable = mReactEditText.getText();
      if (editable instanceof SpannableStringBuilder ssb) {
        updateCursorAndFormat(ssb);
      }
    }
  }
}
