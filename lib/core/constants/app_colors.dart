import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Google Blue (primary) ─────────────────────────────────────────────────
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryContainer = Color(0xFFD2E3FC);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF001D6C);

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F4);
  static const Color border = Color(0xFFE8EAED);
  static const Color cardBorder = border;

  // ── Category (semantic) ──────────────────────────────────────────────────
  static const Color productive = Color(0xFF1E8E3E);       // Google Green
  static const Color productiveContainer = Color(0xFFE6F4EA);
  static const Color distracting = Color(0xFFD93025);      // Google Red
  static const Color distractingContainer = Color(0xFFFCE8E6);
  static const Color neutral = Color(0xFF80868B);
  static const Color neutralContainer = Color(0xFFF1F3F4);
  static const Color warning = Color(0xFFF9AB00);          // Google Yellow
  static const Color warningContainer = Color(0xFFFEF7E0);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textHint = Color(0xFF80868B);

  // ── Score band colours ────────────────────────────────────────────────────
  static Color scoreColor(int score) {
    if (score >= 80) return productive;
    if (score >= 60) return primary;
    if (score >= 40) return warning;
    return distracting;
  }

  static Color scoreContainerColor(int score) {
    if (score >= 80) return productiveContainer;
    if (score >= 60) return primaryContainer;
    if (score >= 40) return warningContainer;
    return distractingContainer;
  }
}
