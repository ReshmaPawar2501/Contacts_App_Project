import 'package:flutter/material.dart';

class DS {
  static const Color blue    = Color(0xFF007AFF);
  static const Color green   = Color(0xFF34C759);
  static const Color red     = Color(0xFFFF3B30);
  static const Color orange  = Color(0xFFFF9500);
  static const Color purple  = Color(0xFFAF52DE);
  static const Color pink    = Color(0xFFFF2D55);
  static const Color teal    = Color(0xFF5AC8FA);
  static const Color indigo  = Color(0xFF5856D6);

  static const Color label       = Color(0xFF000000);
  static const Color label2      = Color(0xFF3C3C43);
  static const Color secondary   = Color(0xFF8E8E93);
  static const Color tertiary    = Color(0xFFAEAEB2);
  static const Color separator   = Color(0xFFE5E5EA);
  static const Color groupedBg   = Color(0xFFF2F2F7);
  static const Color cardBg      = Color(0xFFFFFFFF);

  static const LinearGradient gBlue = LinearGradient(
    colors: [Color(0xFF0A84FF), Color(0xFF0055D4)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient gGreen = LinearGradient(
    colors: [Color(0xFF30D158), Color(0xFF25A244)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient gRed = LinearGradient(
    colors: [Color(0xFFFF453A), Color(0xFFD70015)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient gPurple = LinearGradient(
    colors: [Color(0xFFBF5AF2), Color(0xFF8944AB)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient gOrange = LinearGradient(
    colors: [Color(0xFFFF9F0A), Color(0xFFE07000)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient gPink = LinearGradient(
    colors: [Color(0xFFFF375F), Color(0xFFBF0032)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient gTeal = LinearGradient(
    colors: [Color(0xFF5AC8FA), Color(0xFF0071A4)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient gIndigo = LinearGradient(
    colors: [Color(0xFF6E6CF7), Color(0xFF3634A3)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient gYellow = LinearGradient(
    colors: [Color(0xFFFFD60A), Color(0xFFFF9500)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient gGray = LinearGradient(
    colors: [Color(0xFF8E8E93), Color(0xFF636366)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static const LinearGradient bgFavourites = LinearGradient(
    colors: [Color(0xFFF8F9FE), Color(0xFFECEEF9)],
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
  );
  static const LinearGradient bgRecents = LinearGradient(
    colors: [Color(0xFFF9F8FE), Color(0xFFECEEFA)],
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
  );
  static const LinearGradient bgContacts = LinearGradient(
    colors: [Color(0xFFF8F9FE), Color(0xFFEDF0FF)],
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
  );
  static const LinearGradient bgKeypad = LinearGradient(
    colors: [Color(0xFF141420), Color(0xFF1C1830), Color(0xFF221A38)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient bgDetail = LinearGradient(
    colors: [Color(0xFF0D0D1A), Color(0xFF1A1040), Color(0xFF1F0D35)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static final List<LinearGradient> avatarGrads = [
    gBlue, gGreen, gPurple, gOrange, gPink, gTeal, gIndigo, gRed,
    const LinearGradient(colors: [Color(0xFF64D2FF), Color(0xFF0071A4)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    const LinearGradient(colors: [Color(0xFFFFD60A), Color(0xFFFF8C00)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
  ];

  static LinearGradient avatarGrad(String name) {
    if (name.isEmpty) return gBlue;
    return avatarGrads[name.codeUnitAt(0) % avatarGrads.length];
  }

  static const double r8  = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;

  static List<BoxShadow> shadow(Color c, {double blur = 12, double y = 4, double opacity = 0.18}) =>
      [BoxShadow(color: c.withOpacity(opacity), blurRadius: blur, offset: Offset(0, y))];

  static List<BoxShadow> cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3)),
  ];
}
 