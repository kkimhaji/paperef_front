import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'shared/services/api_service.dart';
import 'shared/services/storage_service.dart';
import 'features/authentication/providers/auth_provider.dart';
import 'features/refs/providers/ref_provider.dart';
import 'features/groups/providers/group_provider.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/refs/presentation/refs_list_screen.dart';
import 'features/authentication/presentation/reset_password_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();
    final apiService = ApiService(storageService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiService, storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => RefProvider(apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => GroupProvider(apiService),
        ),
      ],
      child: MaterialApp(
        title: 'Paperef',
        theme: AppTheme.lightTheme,
        home: const AuthenticationWrapper(),
        debugShowCheckedModeBanner: false,
        onGenerateRoute: (settings) {
          // /reset-password?token=xxx 형식의 URL 처리
          if (settings.name != null &&
              settings.name!.startsWith('/reset-password')) {
            final uri = Uri.parse(settings.name!);
            final token = uri.queryParameters['token'];

            if (token != null && token.isNotEmpty) {
              return MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(token: token),
              );
            }
          }

          return null;
        },
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          return const RefsListScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
