package com.expensify.livemarkdown;

import android.content.res.AssetManager;
import android.text.SpannableStringBuilder;
import android.text.Spanned;

import androidx.annotation.NonNull;

import com.expensify.livemarkdown.spans.*;
import com.facebook.react.views.text.internal.span.CustomLineHeightSpan;
import com.facebook.systrace.Systrace;

import java.util.List;
import java.util.Objects;

public class MarkdownFormatter {
  private final @NonNull AssetManager mAssetManager;

  public MarkdownFormatter(@NonNull AssetManager assetManager) {
    mAssetManager = assetManager;
  }

  // Inline formatting types that should hide based on cursor adjacency, not line
  private static final java.util.Set<String> INLINE_TYPES = java.util.Set.of(
    "bold", "italic", "strikethrough", "link"
  );

  public void format(@NonNull SpannableStringBuilder ssb, @NonNull List<MarkdownRange> markdownRanges, @NonNull MarkdownStyle markdownStyle, int cursorPosition) {
    try {
      Systrace.beginSection(0, "format");
      Objects.requireNonNull(markdownStyle, "mMarkdownStyle is null");
      removeSpans(ssb);
      String text = ssb.toString();
      int cursorLine = cursorPosition >= 0 ? getLineNumber(text, cursorPosition) : -1;
      applyRanges(ssb, markdownRanges, markdownStyle, text, cursorLine, cursorPosition);
    } finally {
      Systrace.endSection(0);
    }
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

  private void removeSpans(@NonNull SpannableStringBuilder ssb) {
    try {
      Systrace.beginSection(0, "removeSpans");
      // We shouldn't use `removeSpans()` because it also removes SpellcheckSpan, SuggestionSpan etc.
      MarkdownSpan[] spans = ssb.getSpans(0, ssb.length(), MarkdownSpan.class);
      for (MarkdownSpan span : spans) {
        ssb.removeSpan(span);
      }
    } finally {
      Systrace.endSection(0);
    }
  }

  private void applyRanges(@NonNull SpannableStringBuilder ssb, @NonNull List<MarkdownRange> markdownRanges, @NonNull MarkdownStyle markdownStyle, String text, int cursorLine, int cursorPosition) {
    try {
      Systrace.beginSection(0, "applyRanges");
      for (MarkdownRange markdownRange : markdownRanges) {
        applyRange(ssb, markdownRange, markdownRanges, markdownStyle, text, cursorLine, cursorPosition);
      }
    } finally {
      Systrace.endSection(0);
    }
  }

  /**
   * Check if a syntax range is adjacent to an inline content type (bold/italic/strikethrough).
   */
  private boolean isAdjacentToInlineType(MarkdownRange syntaxRange, List<MarkdownRange> allRanges) {
    int syntaxStart = syntaxRange.getStart();
    int syntaxEnd = syntaxRange.getEnd();

    for (MarkdownRange range : allRanges) {
      if (INLINE_TYPES.contains(range.getType())) {
        int contentStart = range.getStart();
        int contentEnd = range.getEnd();
        // Adjacent if: syntax ends where content starts, or content ends where syntax starts
        if (syntaxEnd == contentStart || contentEnd == syntaxStart) {
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Check if this syntax range is adjacent to an inline formatted region (bold/italic/strikethrough)
   * and whether the cursor is within or immediately after that region.
   *
   * @param syntaxRange The syntax range being checked
   * @param allRanges All markdown ranges (to find adjacent inline content)
   * @param cursorPos The current cursor position
   * @return true if syntax should be shown, false if it should be hidden
   */
  private boolean shouldShowInlineSyntax(MarkdownRange syntaxRange, List<MarkdownRange> allRanges, int cursorPos) {
    int syntaxStart = syntaxRange.getStart();
    int syntaxEnd = syntaxRange.getEnd();

    // Find the adjacent inline content range
    MarkdownRange contentRange = null;
    for (MarkdownRange range : allRanges) {
      if (INLINE_TYPES.contains(range.getType())) {
        int contentStart = range.getStart();
        int contentEnd = range.getEnd();
        if (syntaxEnd == contentStart || contentEnd == syntaxStart) {
          contentRange = range;
          break;
        }
      }
    }

    if (contentRange == null) {
      return true; // No adjacent content found, show syntax
    }

    // Find the full zone: opening syntax + content + closing syntax
    // We need to find both syntax ranges that surround this content
    int zoneStart = contentRange.getStart();
    int zoneEnd = contentRange.getEnd();

    for (MarkdownRange range : allRanges) {
      if ("syntax".equals(range.getType())) {
        // Opening syntax: ends where content starts
        if (range.getEnd() == contentRange.getStart()) {
          zoneStart = range.getStart();
        }
        // Closing syntax: starts where content ends
        if (range.getStart() == contentRange.getEnd()) {
          zoneEnd = range.getEnd();
        }
      }
    }

    // Cursor is "in the zone" if it's anywhere within the formatted region
    // This includes the syntax characters and content, but NOT the position after
    return cursorPos >= zoneStart && cursorPos <= zoneEnd;
  }

  private void applyRange(@NonNull SpannableStringBuilder ssb, @NonNull MarkdownRange markdownRange, @NonNull List<MarkdownRange> allRanges, @NonNull MarkdownStyle markdownStyle, String text, int cursorLine, int cursorPosition) {
    String type = markdownRange.getType();
    int start = markdownRange.getStart();
    int end = markdownRange.getEnd();
    switch (type) {
      case "bold":
        setSpan(ssb, new MarkdownBoldSpan(), start, end);
        break;
      case "italic":
        setSpan(ssb, new MarkdownItalicSpan(), start, end);
        break;
      case "strikethrough":
        setSpan(ssb, new MarkdownStrikethroughSpan(), start, end);
        break;
      case "emoji":
        setSpan(ssb, new MarkdownFontFamilySpan(markdownStyle.getEmojiFontFamily(), mAssetManager), start, end);
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getEmojiFontSize()), start, end);
        break;
      case "mention-here":
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getMentionHereColor()), start, end);
        setSpan(ssb, new MarkdownBackgroundSpan(markdownStyle.getMentionHereBackgroundColor(), markdownStyle.getMentionHereBorderRadius(), start, end), start, end);
        break;
      case "mention-user":
        // TODO: change mention color when it mentions current user
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getMentionUserColor()), start, end);
        setSpan(ssb, new MarkdownBackgroundSpan(markdownStyle.getMentionUserBackgroundColor(), markdownStyle.getMentionUserBorderRadius(), start, end), start, end);
        break;
      case "mention-report":
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getMentionReportColor()), start, end);
        setSpan(ssb, new MarkdownBackgroundSpan(markdownStyle.getMentionReportBackgroundColor(), markdownStyle.getMentionReportBorderRadius(), start, end), start, end);
        break;
      case "syntax":
        // Check if this syntax is for inline formatting (bold/italic/strikethrough)
        // Those should hide based on cursor adjacency, not line
        boolean isInlineSyntax = isAdjacentToInlineType(markdownRange, allRanges);

        if (isInlineSyntax) {
          // Inline syntax: hide when cursor leaves the word zone
          if (cursorPosition >= 0 && !shouldShowInlineSyntax(markdownRange, allRanges, cursorPosition)) {
            setSpan(ssb, new MarkdownHiddenSpan(), start, end);
          } else {
            setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getSyntaxColor()), start, end);
          }
        } else {
          // Block/line syntax (headings, lists, etc.): hide when cursor leaves the line
          int syntaxLine = getLineNumber(text, start);
          if (cursorLine >= 0 && syntaxLine != cursorLine) {
            setSpan(ssb, new MarkdownHiddenSpan(), start, end);
          } else {
            setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getSyntaxColor()), start, end);
          }
        }
        break;
      case "link":
        setSpan(ssb, new MarkdownUnderlineSpan(), start, end);
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getLinkColor()), start, end);
        break;
      case "code":
        setSpan(ssb, new MarkdownFontFamilySpan(markdownStyle.getCodeFontFamily(), mAssetManager), start, end);
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getCodeFontSize()), start, end);
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getCodeColor()), start, end);
        setSpan(ssb, new MarkdownBackgroundColorSpan(markdownStyle.getCodeBackgroundColor()), start, end);
        break;
      case "pre":
        setSpan(ssb, new MarkdownFontFamilySpan(markdownStyle.getPreFontFamily(), mAssetManager), start, end);
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getPreFontSize()), start, end);
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getPreColor()), start, end);
        setSpan(ssb, new MarkdownCodeBlockSpan(markdownStyle.getPreBackgroundColor()), start, end);
        break;
      case "h1":
        setSpan(ssb, new MarkdownBoldSpan(), start, end);
        CustomLineHeightSpan[] spans = ssb.getSpans(0, ssb.length(), CustomLineHeightSpan.class);
        if (spans.length >= 1) {
          int lineHeight = spans[0].getLineHeight();
          setSpan(ssb, new MarkdownLineHeightSpan(lineHeight * 1.5f), start, end);
        }
        // NOTE: size span must be set after line height span to avoid height jumps
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getH1FontSize()), start, end);
        break;
      case "h2":
        setSpan(ssb, new MarkdownBoldSpan(), start, end);
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getH2FontSize()), start, end);
        break;
      case "h3":
        setSpan(ssb, new MarkdownBoldSpan(), start, end);
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getH3FontSize()), start, end);
        break;
      case "h4":
        setSpan(ssb, new MarkdownBoldSpan(), start, end);
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getH4FontSize()), start, end);
        break;
      case "h5":
        setSpan(ssb, new MarkdownBoldSpan(), start, end);
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getH5FontSize()), start, end);
        break;
      case "h6":
        setSpan(ssb, new MarkdownItalicSpan(), start, end);
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getH6FontSize()), start, end);
        break;
      case "blockquote":
        MarkdownBlockquoteSpan blockquoteSpan = new MarkdownBlockquoteSpan(
          markdownStyle.getBlockquoteBorderColor(),
          markdownStyle.getBlockquoteBorderWidth(),
          markdownStyle.getBlockquoteMarginLeft(),
          markdownStyle.getBlockquotePaddingLeft(),
          markdownRange.getDepth());
        setSpan(ssb, blockquoteSpan, start, end);
        break;
      case "blockquote-marker":
        // Hide the "> " marker
        setSpan(ssb, new MarkdownHiddenSpan(), start, end);
        break;
      case "task-unchecked":
        // Show unchecked box character
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getSyntaxColor()), start, end);
        break;
      case "task-checked":
        // Show checked box character with strikethrough on content
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getSyntaxColor()), start, end);
        break;
      case "list-bullet":
        // Style bullet marker
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getSyntaxColor()), start, end);
        break;
      case "list-number":
        // Style number marker
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getSyntaxColor()), start, end);
        break;
      case "hr":
        // Style horizontal rule - use strikethrough to create a line effect
        setSpan(ssb, new MarkdownStrikethroughSpan(), start, end);
        setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getBlockquoteBorderColor()), start, end);
        break;
      case "table":
        // Table block - apply monospace font
        setSpan(ssb, new MarkdownFontFamilySpan(markdownStyle.getCodeFontFamily(), mAssetManager), start, end);
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getCodeFontSize()), start, end);
        break;
      case "table-row":
        // Table row - no special styling needed, handled by table type
        break;
      case "table-delimiter":
        // Delimiter row - find containing table and check cursor position
        {
          int delimLine = getLineNumber(text, start);
          int tableStartLine = -1;
          int tableEndLine = -1;
          for (MarkdownRange tableRange : allRanges) {
            if ("table".equals(tableRange.getType())) {
              int tStart = getLineNumber(text, tableRange.getStart());
              int tEnd = getLineNumber(text, tableRange.getEnd() - 1);
              if (delimLine >= tStart && delimLine <= tEnd) {
                tableStartLine = tStart;
                tableEndLine = tEnd;
                break;
              }
            }
          }
          if (cursorLine >= tableStartLine && cursorLine <= tableEndLine) {
            // Cursor in table - show as syntax
            setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getSyntaxColor()), start, end);
          } else {
            // Hide delimiter row when not editing
            setSpan(ssb, new MarkdownHiddenSpan(), start, end);
          }
        }
        break;
      case "table-cell":
        // Table cell content - apply monospace font
        setSpan(ssb, new MarkdownFontFamilySpan(markdownStyle.getCodeFontFamily(), mAssetManager), start, end);
        setSpan(ssb, new MarkdownFontSizeSpan(markdownStyle.getCodeFontSize()), start, end);
        break;
      case "table-pipe":
        // Pipe characters - style as syntax or hide based on cursor position
        {
          int pipeLine = getLineNumber(text, start);
          int tableStartLine = -1;
          int tableEndLine = -1;
          for (MarkdownRange tableRange : allRanges) {
            if ("table".equals(tableRange.getType())) {
              int tStart = getLineNumber(text, tableRange.getStart());
              int tEnd = getLineNumber(text, tableRange.getEnd() - 1);
              if (pipeLine >= tStart && pipeLine <= tEnd) {
                tableStartLine = tStart;
                tableEndLine = tEnd;
                break;
              }
            }
          }
          if (cursorLine >= tableStartLine && cursorLine <= tableEndLine) {
            // Cursor in table - show pipes as syntax
            setSpan(ssb, new MarkdownForegroundColorSpan(markdownStyle.getSyntaxColor()), start, end);
          } else {
            // Hide pipes when not editing - for cleaner rendered appearance
            setSpan(ssb, new MarkdownHiddenSpan(), start, end);
          }
        }
        break;
    }
  }

  private void setSpan(@NonNull SpannableStringBuilder ssb, @NonNull MarkdownSpan span, int start, int end) {
    ssb.setSpan(span, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
  }
}
