import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFFF4F7F9);
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x0A000000);

  // Primary Accent
  static const Color primaryAccent = Color(0xFF4A7C82);
  static const Color primaryDark = Color(0xFF2E5058);

  // Text
  static const Color headingText = Color(0xFF1A202C);
  static const Color bodyText = Color(0xFF4A5568);
  static const Color mutedText = Color(0xFF718096);

  // Inputs & Chips
  static const Color inputBorder = Color(0xFFE2E8F0);
  static const Color chipBg = Color(0xFFEDF2F7);

  // Status
  static const Color onlineGreen = Color(0xFF48BB78);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryAccent, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
