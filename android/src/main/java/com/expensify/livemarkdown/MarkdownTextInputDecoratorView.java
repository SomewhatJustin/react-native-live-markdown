package com.expensify.livemarkdown;

import android.content.Context;
import android.text.Editable;
import android.text.SpannableStringBuilder;
import android.text.TextWatcher;
import android.os.Handler;
import android.os.Looper;

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
  private int mLastCursorPos = -1;
  private Handler mHandler;
  private Runnable mCursorCheckRunnable;
  private static final int CURSOR_CHECK_INTERVAL_MS = 100;

  // Track last formatted text to detect changes from JS
  private String mLastFormattedText = "";
  private Runnable mTextCheckRunnable;
  private static final int TEXT_CHECK_INTERVAL_MS = 50;
  private static final int TEXT_CHECK_MAX_ATTEMPTS = 20; // Check for 1 second max
  private int mTextCheckAttempts = 0;

  @Override
  protected void onAttachedToWindow() {
    super.onAttachedToWindow();

    View child = getChildAt(0);
    if (child instanceof ReactEditText) {
      mMarkdownUtils = new MarkdownUtils((ReactContext) getContext());
      mMarkdownUtils.setMarkdownStyle(mMarkdownStyle);
      mMarkdownUtils.setParserId(mParserId);
      mReactEditText = (ReactEditText) child;
      mHandler = new Handler(Looper.getMainLooper());

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

      // Focus listener to start/stop cursor monitoring
      mReactEditText.setOnFocusChangeListener((v, hasFocus) -> {
        if (hasFocus) {
          startCursorMonitoring();
        } else {
          stopCursorMonitoring();
        }
      });

      // Periodic cursor position check while focused
      mCursorCheckRunnable = new Runnable() {
        @Override
        public void run() {
          checkCursorLineChanged();
          if (mReactEditText != null && mReactEditText.hasFocus()) {
            mHandler.postDelayed(this, CURSOR_CHECK_INTERVAL_MS);
          }
        }
      };

      // Text check runnable to detect changes from JS (bypasses TextWatcher)
      // React Native's ReactEditText skips TextWatcher callbacks when setting text from JS
      mTextCheckRunnable = new Runnable() {
        @Override
        public void run() {
          if (mReactEditText == null || mMarkdownUtils == null) return;

          String currentText = mReactEditText.getText().toString();
          if (!currentText.equals(mLastFormattedText) && !currentText.isEmpty()) {
            // Text changed from JS - apply formatting
            Editable editable = mReactEditText.getText();
            if (editable instanceof SpannableStringBuilder ssb) {
              updateCursorAndFormat(ssb);
              mLastFormattedText = currentText;
            }
            mTextCheckAttempts = 0; // Reset on success
          } else if (mTextCheckAttempts < TEXT_CHECK_MAX_ATTEMPTS) {
            // Keep checking for a bit in case text is set asynchronously
            mTextCheckAttempts++;
            mHandler.postDelayed(this, TEXT_CHECK_INTERVAL_MS);
          }
        }
      };

      applyNewStyles();

      // Start monitoring if already focused
      if (mReactEditText.hasFocus()) {
        startCursorMonitoring();
      }

      // Start text check to catch text set from JS (bypasses TextWatcher)
      mTextCheckAttempts = 0;
      mHandler.post(mTextCheckRunnable);
    }
  }

  private void startCursorMonitoring() {
    if (mHandler != null && mCursorCheckRunnable != null) {
      mHandler.removeCallbacks(mCursorCheckRunnable);
      mHandler.post(mCursorCheckRunnable);
    }
  }

  private void stopCursorMonitoring() {
    if (mHandler != null && mCursorCheckRunnable != null) {
      mHandler.removeCallbacks(mCursorCheckRunnable);
    }
  }

  /**
   * Check if cursor moved to a different line, and re-format if so.
   */
  private void checkCursorLineChanged() {
    if (mReactEditText == null || mMarkdownUtils == null) return;

    int cursorPos = mReactEditText.getSelectionStart();

    // Only reformat if cursor actually moved
    if (cursorPos == mLastCursorPos) return;
    mLastCursorPos = cursorPos;

    String text = mReactEditText.getText().toString();
    int currentLine = getLineNumber(text, cursorPos);

    if (currentLine != mLastCursorLine) {
      mLastCursorLine = currentLine;
      Editable editable = mReactEditText.getText();
      if (editable instanceof SpannableStringBuilder ssb) {
        mMarkdownUtils.setCursorPosition(cursorPos);
        mMarkdownUtils.applyMarkdownFormatting(ssb);
      }
    }
  }

  private void updateCursorAndFormat(SpannableStringBuilder ssb) {
    if (mReactEditText != null && mMarkdownUtils != null) {
      int cursorPos = mReactEditText.getSelectionStart();
      mLastCursorPos = cursorPos;
      mLastCursorLine = getLineNumber(ssb.toString(), cursorPos);
      mMarkdownUtils.setCursorPosition(cursorPos);
      mMarkdownUtils.applyMarkdownFormatting(ssb);
      // Track formatted text for JS change detection
      mLastFormattedText = ssb.toString();
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
    stopCursorMonitoring();
    // Stop text check runnable
    if (mHandler != null && mTextCheckRunnable != null) {
      mHandler.removeCallbacks(mTextCheckRunnable);
    }
    if (mReactEditText != null) {
      mReactEditText.removeTextChangedListener(mTextWatcher);
      mReactEditText.setOnFocusChangeListener(null);
      mReactEditText = null;
      mTextWatcher = null;
      mMarkdownUtils = null;
    }
    mHandler = null;
    mCursorCheckRunnable = null;
    mTextCheckRunnable = null;
    mLastFormattedText = "";
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
