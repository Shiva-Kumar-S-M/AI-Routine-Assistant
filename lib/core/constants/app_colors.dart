import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Obsidian & Warm Titanium Primary Palette ──────────────────────────────
  static const Color primary = Color(0xFFF4F4F6);          // Crisp Titanium White
  static const Color primaryLight = Color(0xFFE2E8F0);     // Soft Platinum
  static const Color primaryContainer = Color(0xFF1E1E26); // Dark Slate Container
  static const Color primaryGlow = Color(0xFF6366F1);      // Refined Indigo Glow
  static const Color onPrimary = Color(0xFF0A0A0C);        // Deep Obsidian on Primary
  static const Color onPrimaryContainer = Color(0xFFF4F4F6);

  // ── Surfaces (Obsidian Canvas & Titanium Cards) ───────────────────────────
  static const Color background = Color(0xFF0A0A0C);       // True Obsidian Canvas
  static const Color surface = Color(0xFF131317);          // Warm Titanium Card Surface
  static const Color surfaceElevated = Color(0xFF1A1A22);  // Raised Container / Chip
  static const Color surfaceRaised = surfaceElevated;      // Alias
  static const Color surfaceVariant = Color(0xFF22222C);   // Input / Interactive Surface
  static const Color border = Color(0xFF24242C);           // 1px Hairline Border
  static const Color borderLight = Color(0xFF32323D);      // Active / Focused Hairline Border
  static const Color cardBorder = border;

  // ── Precision Accent Palette (Restrained, Production-Grade) ───────────────
  static const Color productive = Color(0xFF10B981);       // Understated Emerald Green
  static const Color productiveContainer = Color(0xFF064E3B);
  static const Color distracting = Color(0xFFF43F5E);      // Refined Rose Coral
  static const Color distractingContainer = Color(0xFF4C0519);
  static const Color neutral = Color(0xFF71717A);          // Muted Zinc / Slate
  static const Color neutralContainer = Color(0xFF18181B);
  static const Color warning = Color(0xFFF59E0B);          // Warm Amber
  static const Color warningContainer = Color(0xFF451A03);
  static const Color fire = Color(0xFFF97316);             // Titanium Flame
  static const Color cyan = Color(0xFF06B6D4);             // Precision Cyan
  static const Color gold = Color(0xFFEAB308);             // Champagne Gold

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fireGradient = LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mintGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF16161B), Color(0xFF111114)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Text Hierarchy ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF4F4F6);      // Pure Crisp White
  static const Color textSecondary = Color(0xFF8E8E9A);    // Muted Titanium Gray
  static const Color textHint = Color(0xFF52525E);         // Subdued Metadata
  static const Color textDisabled = Color(0xFF52525E);     // Subdued Disabled
  static const Color disabled = textDisabled;              // Alias

  // ── Score band colours ────────────────────────────────────────────────────
  static Color scoreColor(int score) {
    if (score >= 80) return productive;
    if (score >= 60) return cyan;
    if (score >= 40) return warning;
    return distracting;
  }

  static Color scoreContainerColor(int score) {
    if (score >= 80) return productiveContainer;
    if (score >= 60) return const Color(0xFF083344);
    if (score >= 40) return warningContainer;
    return distractingContainer;
  }
}
