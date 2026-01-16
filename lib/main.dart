import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Core
import 'core/theme/app_theme.dart';

// Services
import 'shared/services/api_service.dart';
import 'shared/services/storage_service.dart';

// Providers
import 'features/authentication/providers/auth_provider.dart';
import 'features/papers/providers/paper_provider.dart';
import 'features/groups/providers/group_provider.dart';
// Screens
import 'features/authentication/presentation/login_screen.dart';
import 'features/papers/presentation/papers_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 서비스 초기화
    final storageService = StorageService();
    final apiService = ApiService(storageService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiService, storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => PaperProvider(apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => GroupProvider(apiService), // 추가
        ),
      ],
      child: MaterialApp(
        title: 'Paperef',
        theme: AppTheme.lightTheme,
        home: const AuthenticationWrapper(),
        debugShowCheckedModeBanner: false,
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
        // 초기화 중
        if (!authProvider.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 인증 완료
        if (authProvider.isAuthenticated) {
          return const PapersListScreen();
        }

        // 미인증
        return const LoginScreen();
      },
    );
  }
}
