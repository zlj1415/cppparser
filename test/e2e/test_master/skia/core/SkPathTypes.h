/*
 * Copyright 2019 Google LLC.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef SkPathTypes_DEFINED
#  define SkPathTypes_DEFINED
#  include "include/core/SkTypes.h"
enum class SkPathFillType
{
    /** Specifies that "inside" is computed by a non-zero sum of signed edge crossings */
  kWinding,
    /** Specifies that "inside" is computed by an odd number of edge crossings */
  kEvenOdd,
    /** Same as Winding, but draws outside of the path, rather than inside */
  kInverseWinding,
    /** Same as EvenOdd, but draws outside of the path, rather than inside */
  kInverseEvenOdd
};
enum class SkPathConvexityType
{
  kUnknown,
  kConvex,
  kConcave
};
enum class SkPathDirection
{
    /** clockwise direction for adding closed contours */
  kCW,
    /** counter-clockwise direction for adding closed contours */
  kCCW
};
enum SkPathSegmentMask
{
  kLine_SkPathSegmentMask = 1 << 0,
  kQuad_SkPathSegmentMask = 1 << 1,
  kConic_SkPathSegmentMask = 1 << 2,
  kCubic_SkPathSegmentMask = 1 << 3
};
enum class SkPathVerb
{
  kMove,
  kLine,
  kQuad,
  kConic,
  kCubic,
  kClose,
  kDone
};
#endif