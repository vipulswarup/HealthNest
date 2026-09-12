import 'package:flutter/cupertino.dart';
import 'package:sanovault/theme/sv_colors.dart';

CupertinoThemeData buildSvTheme() {
  return const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: SvColors.coral,
    barBackgroundColor: SvColors.surface,
    scaffoldBackgroundColor: SvColors.groupedBackground,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(
        color: SvColors.ink,
        fontSize: 17,
        letterSpacing: -0.41,
      ),
      navTitleTextStyle: TextStyle(
        color: SvColors.ink,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
      ),
      navLargeTitleTextStyle: TextStyle(
        color: SvColors.ink,
        fontSize: 34,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.37,
      ),
      navActionTextStyle: TextStyle(
        color: SvColors.coral,
        fontSize: 17,
      ),
      tabLabelTextStyle: TextStyle(
        fontSize: 10,
        letterSpacing: 0.1,
      ),
    ),
  );
}
