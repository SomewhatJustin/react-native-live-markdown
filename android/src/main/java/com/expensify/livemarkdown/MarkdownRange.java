package com.expensify.livemarkdown;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public class MarkdownRange {
  private final @NonNull String mType;
  private final int mStart;
  private final int mEnd;
  private final int mLength;
  private final int mDepth;
  private final int mTableColumn;
  private final @Nullable String mTableAlignment;
  private final int mTableColumnCount;

  public MarkdownRange(@NonNull String type, int start, int length, int depth) {
    this(type, start, length, depth, -1, null, 0);
  }

  public MarkdownRange(@NonNull String type, int start, int length, int depth, int tableColumn, @Nullable String tableAlignment, int tableColumnCount) {
    mType = type;
    mStart = start;
    mEnd = start + length;
    mLength = length;
    mDepth = depth;
    mTableColumn = tableColumn;
    mTableAlignment = tableAlignment;
    mTableColumnCount = tableColumnCount;
  }

  public String getType() {
    return mType;
  }

  public int getStart() {
    return mStart;
  }

  public int getEnd() {
    return mEnd;
  }

  public int getLength() {
    return mLength;
  }

  public int getDepth() {
    return mDepth;
  }

  public int getTableColumn() {
    return mTableColumn;
  }

  @Nullable
  public String getTableAlignment() {
    return mTableAlignment;
  }

  public int getTableColumnCount() {
    return mTableColumnCount;
  }
}
