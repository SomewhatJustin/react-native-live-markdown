package com.expensify.livemarkdown.spans;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.text.style.ReplacementSpan;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * A span that hides text by making it take zero width and drawing nothing.
 * Used for syntax hiding - when the cursor is not on a line, the markdown
 * syntax characters (**, ##, etc.) are hidden from view.
 */
public class MarkdownHiddenSpan extends ReplacementSpan implements MarkdownSpan {

  @Override
  public int getSize(@NonNull Paint paint, CharSequence text, int start, int end,
                     @Nullable Paint.FontMetricsInt fm) {
    // Return 0 width - the text takes no horizontal space
    return 0;
  }

  @Override
  public void draw(@NonNull Canvas canvas, CharSequence text, int start, int end,
                   float x, int top, int y, int bottom, @NonNull Paint paint) {
    // Draw nothing - the text is invisible
  }
}
