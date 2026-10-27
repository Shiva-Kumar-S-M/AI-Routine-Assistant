import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Dark-First Primary Palette ─────────────────────────────────────────────
  static const Color primary = Color(0xFF7C4DFF);          // Deep Purple / Violet Accent
  static const Color primaryLight = Color(0xFFB388FF);     // Light Violet Accent
  static const Color primaryContainer = Color(0xFF261D4E);
  static const Color primaryGlow = Color(0xFFB388FF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFEDE7F6);

  // ── Surfaces (Dark Theme) ──────────────────────────────────────────────────
  static const Color background = Color(0xFF0E0E18);       // Deep Cosmic Navy/Black
  static const Color surface = Color(0xFF181827);          // Card Surface
  static const Color surfaceElevated = Color(0xFF202035);  // Raised Container
  static const Color surfaceVariant = Color(0xFF282840);   // Input / Chip Surface
  static const Color border = Color(0xFF2D2D46);           // Subtle Border
  static const Color cardBorder = border;

  // ── Energetic Accent Palette (Matiks-inspired) ─────────────────────────────
  static const Color productive = Color(0xFF00E676);       // Vibrant Mint Green
  static const Color productiveContainer = Color(0xFF0F3E2B);
  static const Color distracting = Color(0xFFFF2A55);      // Electric Coral Red
  static const Color distractingContainer = Color(0xFF451322);
  static const Color neutral = Color(0xFF90A4AE);          // Slate Gray
  static const Color neutralContainer = Color(0xFF222930);
  static const Color warning = Color(0xFFFFB300);          // Vivid Amber
  static const Color warningContainer = Color(0xFF3E310E);
  static const Color fire = Color(0xFFFF5722);             // Flame Orange
  static const Color cyan = Color(0xFF00E5FF);             // Electric Cyan
  static const Color gold = Color(0xFFFFD700);             // Trophy Gold

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fireGradient = LinearGradient(
    colors: [Color(0xFFFF9100), Color(0xFFFF3D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mintGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E1E32), Color(0xFF161625)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Text Hierarchy ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF6F6FC);
  static const Color textSecondary = Color(0xFF9A9AA6);
  static const Color textHint = Color(0xFF636376);

  // ── Score band colours ─────────────────────────────────────────────────────
  static Color scoreColor(int score) {
    if (score >= 80) return productive;
    if (score >= 60) return cyan;
    if (score >= 40) return warning;
    return distracting;
  }

  static Color scoreContainerColor(int score) {
    if (score >= 80) return productiveContainer;
    if (score >= 60) return const Color(0xFF0C343D);
    if (score >= 40) return warningContainer;
    return distractingContainer;
  }
}
