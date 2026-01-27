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
          print('onGenerateRoute called with: ${settings.name}');

          // URL 파싱: reset-password?token=xxx 처리
          if (settings.name != null && settings.name!.isNotEmpty) {
            final uri = Uri.parse(settings.name!);

            // 경로만 추출 (쿼리 파라미터 제외)
            final path = uri.path;

            // reset-password 경로 처리
            if (path == '/reset-password' || path == 'reset-password') {
              final token = uri.queryParameters['token'];
              if (token != null && token.isNotEmpty) {
                print('Navigating to ResetPasswordScreen with token: $token');
                return MaterialPageRoute(
                  builder: (_) => ResetPasswordScreen(token: token),
                  settings: settings,
                );
              }
            }

            // 루트 경로는 AuthenticationWrapper로 처리
            if (path == '/' || path.isEmpty) {
              return MaterialPageRoute(
                builder: (_) => const AuthenticationWrapper(),
                settings: settings,
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
        // 초기화 중
        if (!authProvider.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 인증됨 -> 메인 화면
        if (authProvider.isAuthenticated) {
          print('User authenticated, showing RefsListScreen');
          return const RefsListScreen();
        }

        // 인증 안됨 -> 로그인 화면
        print('User not authenticated, showing LoginScreen');
        return const LoginScreen();
      },
    );
  }
}
