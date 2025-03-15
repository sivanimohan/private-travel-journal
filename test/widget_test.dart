import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traveljournal/login.dart';
import 'package:appwrite/appwrite.dart';

void main() {
  late Client client;

  setUp(() {
    client = Client()
        .setEndpoint(
            'https://YOUR_APPWRITE_ENDPOINT/v1') // Replace with your endpoint
        .setProject('YOUR_PROJECT_ID'); // Replace with your project ID
  });

  testWidgets('Login screen loads properly', (WidgetTester tester) async {
    // Build the app with LoginPage as the starting screen
    await tester.pumpWidget(MaterialApp(home: LoginPage(client: client)));

    // Check if "Login" text is present
    expect(find.text("Login"), findsOneWidget);

    // Check if the email and password fields are present
    expect(find.byType(TextField), findsNWidgets(2)); // Email & Password fields

    // Check if the login button is present
    expect(find.widgetWithText(ElevatedButton, "Login"), findsOneWidget);
  });

  testWidgets('Navigate to Home Page on valid login',
      (WidgetTester tester) async {
    // Build the app with LoginPage
    await tester.pumpWidget(MaterialApp(home: LoginPage(client: client)));

    // Enter email and password
    await tester.enterText(find.byType(TextField).at(0), "test@example.com");
    await tester.enterText(find.byType(TextField).at(1), "password123");

    // Tap the login button
    await tester.tap(find.widgetWithText(ElevatedButton, "Login"));
    await tester.pumpAndSettle();

    // Verify that Home Page is loaded
    expect(find.text("Travel Journal"), findsOneWidget);
  });

  testWidgets('Navigate to SignUp Page', (WidgetTester tester) async {
    // Build the app with LoginPage
    await tester.pumpWidget(MaterialApp(home: LoginPage(client: client)));

    // Tap "Don't have an account? Sign up"
    await tester
        .tap(find.widgetWithText(TextButton, "Don't have an account? Sign up"));
    await tester.pumpAndSettle();

    // Verify that Signup Page is loaded
    expect(find.text("Sign Up"), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, "Sign Up"), findsOneWidget);
  });
}
