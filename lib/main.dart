import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Nunito Sans is bundled in assets/google_fonts; never download fonts at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const MealLensRoot());
}
