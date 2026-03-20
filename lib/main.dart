import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/document_provider.dart';
import 'services/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage before anything else
  final storageService = LocalStorageService();
  await storageService.init();

  // Pre-seed demo accounts so users can log in without registering
  await storageService.seedDemoAccounts();

  runApp(
    ProviderScope(
      overrides: [
        // Supply the already-initialized storage to all providers
        localStorageServiceProvider.overrideWithValue(storageService),
      ],
      child: const GhanaDocumentVerificationApp(),
    ),
  );
}

class GhanaDocumentVerificationApp extends StatelessWidget {
  const GhanaDocumentVerificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blockchain Document Verification-NIVSS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppNavigator(),
    );
  }
}

class AppNavigator extends ConsumerWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    if (user == null) {
      return const LoginScreen();
    }

    return HomeScreen(user: user);
  }
}
