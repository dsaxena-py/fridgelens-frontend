import 'package:flutter/material.dart';

/// MealLens brand tokens (Brand Identity Guidelines §4 and §7).
abstract final class MistEucalyptus {
  static const background = Color(0xFFF3F6F3);
  static const surface = Color(0xFFDCE4DE);
  static const accent = Color(0xFFA7B7AC);
  static const accentStrong = Color(0xFF607267);
  static const text = Color(0xFF26302A);
}

abstract final class GraphiteMint {
  static const background = Color(0xFF181B1A);
  static const surface = Color(0xFF222725);
  static const surfaceElevated = Color(0xFF303936);
  static const accent = Color(0xFFB6CEBF);
  static const textMuted = Color(0xFF919F98);
  static const text = Color(0xFFF4F7F5);
}

/// Functional colours. Always paired with a label or icon, never used alone.
abstract final class StatusColors {
  static const success = Color(0xFF6E8F76);
  static const attention = Color(0xFFC4924F);
  static const error = Color(0xFFB66F5D);
  static const info = Color(0xFF6F8FA1);
}

/// 4-point spacing scale.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const screen = 20.0;
}

abstract final class Radii {
  static const sheet = 24.0;
  static const card = 16.0;
  static const control = 12.0;
  static const thumbnail = 12.0;
  static const pill = 999.0;
}
