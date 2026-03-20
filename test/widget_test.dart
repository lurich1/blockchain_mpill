// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ghana_blockchain_document_verification/main.dart';
import 'package:ghana_blockchain_document_verification/providers/document_provider.dart';
import 'package:ghana_blockchain_document_verification/services/local_storage_service.dart';

void main() {
  testWidgets('App loads and shows login screen', (WidgetTester tester) async {
    // Set up mock SharedPreferences for the test environment
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService();
    await storage.init();

    // Build our app with the initialized storage provider override
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
        ],
        child: const GhanaDocumentVerificationApp(),
      ),
    );

    // Verify that the login screen is displayed
    expect(find.text('Work email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
