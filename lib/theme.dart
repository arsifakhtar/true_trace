// lib/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.blue,
  useMaterial3: true,
  textTheme: GoogleFonts.interTextTheme(),
  appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
  scaffoldBackgroundColor: Colors.white,
);

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  textTheme: GoogleFonts.interTextTheme(),
  appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
);
