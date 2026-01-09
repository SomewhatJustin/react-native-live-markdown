package com.expensify.livemarkdown;

import android.text.SpannableStringBuilder;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.ReactContext;
import com.facebook.systrace.Systrace;

import java.util.ArrayList;
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
      String text = ssb.toString();
      List<MarkdownRange> markdownRanges = mMarkdownParser.parse(text, mParserId);

      // Filter syntax ranges based on cursor position (syntax hiding)
      List<MarkdownRange> filteredRanges = filterSyntaxRanges(markdownRanges, text, mCursorPosition);

      mMarkdownFormatter.format(ssb, filteredRanges, mMarkdownStyle);
    } finally {
      Systrace.endSection(0);
    }
  }

  /**
   * Filter out 'syntax' ranges that are not on the cursor's line.
   * This creates the "syntax hiding" effect where markdown syntax is only
   * visible when the cursor is on that line.
   */
  private List<MarkdownRange> filterSyntaxRanges(List<MarkdownRange> ranges, String text, int cursorPos) {
    if (cursorPos < 0) {
      // No cursor position set, show all syntax
      return ranges;
    }

    // Find which line the cursor is on
    int cursorLine = getLineNumber(text, cursorPos);

    List<MarkdownRange> filtered = new ArrayList<>();
    for (MarkdownRange range : ranges) {
      if ("syntax".equals(range.getType())) {
        // Only include syntax ranges that are on the cursor's line
        int rangeLine = getLineNumber(text, range.getStart());
        if (rangeLine == cursorLine) {
          filtered.add(range);
        }
        // Skip syntax ranges not on cursor line (they will be hidden)
      } else {
        // Always include non-syntax ranges
        filtered.add(range);
      }
    }
    return filtered;
  }

  /**
   * Get the line number (0-indexed) for a given character position.
   */
  private int getLineNumber(String text, int position) {
    if (position < 0 || position > text.length()) {
      return 0;
    }
    int line = 0;
    for (int i = 0; i < position; i++) {
      if (text.charAt(i) == '\n') {
        line++;
      }
    }
    return line;
  }
}
