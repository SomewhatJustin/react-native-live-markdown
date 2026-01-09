package com.expensify.livemarkdown;

import android.text.SpannableStringBuilder;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.ReactContext;
import com.facebook.systrace.Systrace;

import java.util.List;

public class MarkdownUtils {
  public MarkdownUtils(@NonNull ReactContext reactContext) {
    mMarkdownParser = new MarkdownParser(reactContext);
    mMarkdownFormatter = new MarkdownFormatter(reactContext.getAssets());
  }

  private final @NonNull MarkdownParser mMarkdownParser;
  private final @NonNull MarkdownFormatter mMarkdownFormatter;

  private MarkdownStyle mMarkdownStyle;
  private int mParserId;
  private int mCursorPosition = -1;

  public void setMarkdownStyle(@NonNull MarkdownStyle markdownStyle) {
    mMarkdownStyle = markdownStyle;
  }

  public void setParserId(int parserId) {
    mParserId = parserId;
  }

  public void setCursorPosition(int cursorPosition) {
    mCursorPosition = cursorPosition;
  }

  public void applyMarkdownFormatting(SpannableStringBuilder ssb) {
    try {
      Systrace.beginSection(0, "applyMarkdownFormatting");
      List<MarkdownRange> markdownRanges = mMarkdownParser.parse(ssb.toString(), mParserId);
      // Pass cursor position to formatter for syntax hiding
      mMarkdownFormatter.format(ssb, markdownRanges, mMarkdownStyle, mCursorPosition);
    } finally {
      Systrace.endSection(0);
    }
  }
}
