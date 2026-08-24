import 'package:flutter/material.dart';

abstract final class AppColors {
  static const orange = Color(0xFFFF7900);
  static const orangeDark = Color(0xFFD96500);
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF6B7280);
  static const background = Color(0xFFF6F6F4);
  static const surface = Colors.white;
  static const border = Color(0xFFE6E6E2);
  static const success = Color(0xFF198754);
  static const warning = Color(0xFFE29A00);
  static const error = Color(0xFFD92D20);
  static const info = Color(0xFF2563EB);
  static const purple = Color(0xFF7C3AED);
}

abstract final class AppSpacing {
  static const xxs = 4.0, xs = 8.0, sm = 12.0, md = 16.0, lg = 24.0, xl = 32.0;
}

abstract final class AppRadius {
  static const small = 8.0, control = 12.0, card = 16.0, sheet = 24.0;
}

abstract final class AppTypography {
  static const display = TextStyle(
    fontSize: 30,
    height: 1.12,
    fontWeight: FontWeight.w800,
    letterSpacing: -.8,
  );
  static const title = TextStyle(
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -.3,
  );
  static const section = TextStyle(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );
  static const label = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const meta = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );
}
