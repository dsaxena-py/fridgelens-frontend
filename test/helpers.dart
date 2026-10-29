import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meallens/app.dart';
import 'package:meallens/data/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuth extends AuthService {
  FakeAuth({this.password = 'correct-horse', this.requireConfirmation = false});

  final String password;
  final bool requireConfirmation;
  String? _email;
  final calls = <String>[];

  @override
  bool get signedIn => _email != null;

  @override
  String? get email => _email;

  @override
  Future<String?> accessToken() async => signedIn ? 'token' : null;

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn $email');
    if (password != this.password) throw AuthFailure("That email and password don't match. Try again.");
    _email = email;
    notifyListeners();
  }

  @override
  Future<bool> signUp(String email, String password, {String? displayName}) async {
    calls.add('signUp $email ${displayName ?? ''}'.trim());
    if (requireConfirmation) return true;
    _email = email;
    notifyListeners();
    return false;
  }

  @override
  Future<void> signOut() async {
    _email = null;
    notifyListeners();
  }
}

/// Pumps the whole app (splash included) with a fake sign-in service and in-memory preferences.
Future<({FakeAuth auth, SharedPreferences prefs})> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  FakeAuth? auth,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final fake = auth ?? FakeAuth();
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(MealLensRoot(
    startup: () async => Startup(prefs: sp, auth: fake),
    minimumSplash: Duration.zero,
  ));
  await tester.pumpAndSettle();
  return (auth: fake, prefs: sp);
}
