import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTextStyles {
  // Titres : Poppins
  static TextStyle heading1 = GoogleFonts.poppins(
    fontSize: AppSizes().h1,
    fontWeight: FontWeight.bold,
    color: AppColors.text,
    letterSpacing: AppSizes().spacingTight,
    height: AppSizes().lineHeightLarge,
  );

  static TextStyle heading2 = GoogleFonts.poppins(
    fontSize: AppSizes().h2,
    fontWeight: FontWeight.bold,
    color: AppColors.text,
    letterSpacing: AppSizes().spacingTight,
    height: AppSizes().lineHeightLarge,
  );

  static TextStyle heading3 = GoogleFonts.poppins(
    fontSize: AppSizes().h3,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    letterSpacing: AppSizes().spacingMedium,
    height: AppSizes().lineHeightMedium,
  );

  // Corps du texte : Inter
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: AppSizes().bodyLarge,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
    height: AppSizes().lineHeightLarge,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: AppSizes().bodyMedium,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
    height: AppSizes().lineHeightMedium,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: AppSizes().bodySmall,
    fontWeight: FontWeight.w400,
    color: AppColors.textLight,
    height: AppSizes().lineHeightSmall,
  );

  // Boutons : Poppins
  static TextStyle buttonText = GoogleFonts.poppins(
    fontSize: AppSizes().bodyMedium,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    letterSpacing: AppSizes().spacingWide,
    height: AppSizes().lineHeightMedium,
  );

  // Labels : Inter
  static TextStyle label = GoogleFonts.inter(
    fontSize: AppSizes().bodyMedium,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
    letterSpacing: AppSizes().spacingMedium,
    height: AppSizes().lineHeightSmall,
  );

  // Légendes : Inter
  static TextStyle caption = GoogleFonts.inter(
    fontSize: AppSizes().bodySmall,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
    letterSpacing: AppSizes().spacingMedium,
    height: AppSizes().lineHeightSmall,
  );

  // Liens : Poppins
  static TextStyle link = GoogleFonts.poppins(
    fontSize: AppSizes().bodyMedium,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
    height: AppSizes().lineHeightMedium,
  );

  // Accentuation : Poppins
  static TextStyle emphasis = GoogleFonts.poppins(
    fontSize: AppSizes().bodyMedium,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    letterSpacing: AppSizes().spacingMedium,
    height: AppSizes().lineHeightMedium,
  );
}
