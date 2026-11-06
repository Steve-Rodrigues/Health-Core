import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcore/main.dart';
import 'package:healthcore/screens/login_screen.dart';
import 'package:healthcore/screens/registration_screen.dart';
import 'package:healthcore/screens/welcome_screen.dart';

void main() {
  testWidgets('starts at the welcome screen when auth is not configured', (
    tester,
  ) async {
    await tester.pumpWidget(const HealthCoreApp());

    expect(find.byType(AuthGate), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Welcome to\nHealthCore'), findsOneWidget);
  });

  testWidgets('welcome screen opens the login screen', (tester) async {
    await tester.pumpWidget(const HealthCoreApp());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('welcome screen opens the registration screen', (tester) async {
    await tester.pumpWidget(const HealthCoreApp());

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Create a new Account'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RegistrationScreen), findsOneWidget);
    expect(find.text('Start your journey'), findsOneWidget);
  });
}
