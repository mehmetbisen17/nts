import 'dart:math';

import 'package:vector_math/vector_math_64.dart';

extension Matrix4Extensions on Matrix4 {
  /// A fast approximation of the matrix's scale factor.
  /// This makes the assumptions that the matrix has a uniform scale
  /// and no rotation or skewing.
  double get approxScale => entry(0, 0);

  /// The scale factor of a matrix that only translates, rotates
  /// and scales uniformly in 2D.
  double get uniformScale =>
      sqrt((storage[0] * storage[5] - storage[4] * storage[1]).abs());

  /// The rotation in radians of a matrix that only translates, rotates
  /// and scales uniformly in 2D.
  double get rotation => atan2(storage[1], storage[0]);
}
