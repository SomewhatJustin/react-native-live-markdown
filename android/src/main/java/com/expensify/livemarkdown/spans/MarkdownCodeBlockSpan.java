package com.expensify.livemarkdown.spans;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.text.style.LineBackgroundSpan;

import androidx.annotation.ColorInt;

public class MarkdownCodeBlockSpan implements MarkdownSpan, LineBackgroundSpan {
  @ColorInt
  private final int backgroundColor;

  public MarkdownCodeBlockSpan(@ColorInt int backgroundColor) {
    this.backgroundColor = backgroundColor;
  }

  @Override
  public void drawBackground(Canvas canvas, Paint paint, int left, int right, int top, int baseline, int bottom,
                             CharSequence text, int start, int end, int lineNumber) {
    int originalColor = paint.getColor();
    Paint.Style originalStyle = paint.getStyle();

    paint.setColor(backgroundColor);
    paint.setStyle(Paint.Style.FILL);

    // Draw full-width background
    canvas.drawRect(left, top, right, bottom, paint);

    paint.setColor(originalColor);
    paint.setStyle(originalStyle);
  }
}
