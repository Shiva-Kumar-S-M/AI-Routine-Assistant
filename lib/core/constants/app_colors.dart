import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Premium Monochrome Palette (Minimal, Calm, Expensive) ─────────────────
  static const Color background = Color(0xFF0B0B0C);       // Deep black/charcoal
  static const Color surface = Color(0xFF131314);          // Card surface
  static const Color surfaceRaised = Color(0xFF1A1A1C);    // Elevated container
  static const Color surfaceElevated = surfaceRaised;
  static const Color surfaceVariant = Color(0xFF1E1E20);   // Input / Chip Surface
  static const Color border = Color(0xFF262628);           // 1px subtle crisp border
  static const Color cardBorder = border;

  // Single Accent = Pure White
  static const Color primary = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFF000000);        // Black text on white
  static const Color primaryLight = Color(0xFFE5E5EA);
  static const Color primaryContainer = Color(0xFF1A1A1C);
  static const Color primaryGlow = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFF5F5F5);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFFF5F5F5);      // Primary crisp white
  static const Color textSecondary = Color(0xFF8E8E93);    // Secondary neutral gray
  static const Color textDisabled = Color(0xFF48484A);     // Disabled muted gray
  static const Color disabled = textDisabled;
  static const Color textHint = Color(0xFF636366);

  // Grayscale State Indicators (Convey state via typography/contrast, NOT color)
  static const Color productive = Color(0xFFFFFFFF);
  static const Color productiveContainer = Color(0xFF1A1A1C);
  static const Color distracting = Color(0xFF8E8E93);
  static const Color distractingContainer = Color(0xFF1A1A1C);
  static const Color neutral = Color(0xFF636366);
  static const Color neutralContainer = Color(0xFF131314);
  static const Color warning = Color(0xFFD1D1D6);
  static const Color warningContainer = Color(0xFF1A1A1C);
  static const Color fire = Color(0xFFFFFFFF);
  static const Color cyan = Color(0xFFE5E5EA);
  static const Color gold = Color(0xFFFFFFFF);

  // Flat Subtle Monochrome Gradients (No bright colors)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFE5E5EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fireGradient = LinearGradient(
    colors: [Color(0xFFE5E5EA), Color(0xFFD1D1D6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mintGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFE5E5EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF131314), Color(0xFF131314)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Grayscale Score Mapping
  static Color scoreColor(int score) {
    if (score >= 80) return textPrimary;
    if (score >= 60) return const Color(0xFFD1D1D6);
    if (score >= 40) return textSecondary;
    return textDisabled;
  }

  static Color scoreContainerColor(int score) {
    return surfaceRaised;
  }
}
