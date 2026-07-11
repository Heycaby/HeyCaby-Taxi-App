import 'package:flutter/material.dart';

/// Corner radius tokens.
abstract final class DriverRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double sheet = 28;
  static const double pill = 999;

  static BorderRadius get xsAll => BorderRadius.circular(xs);
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get sheetTop =>
      const BorderRadius.vertical(top: Radius.circular(sheet));
  static BorderRadius get sheetFloating => BorderRadius.circular(sheet);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}
