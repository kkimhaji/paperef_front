import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'core/theme/app_theme.dart';
import 'shared/services/api_service.dart';
import 'shared/services/storage_service.dart';
import 'features/authentication/providers/auth_provider.dart';
import 'features/refs/providers/ref_provider.dart';
import 'features/groups/providers/group_provider.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/refs/presentation/refs_list_screen.dart';
import 'features/authentication/presentation/reset_password_screen.dart';

// 딥링크 전역 NavigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final StorageService _storageService = StorageService();
  late final ApiService _apiService;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(_storageService);
    if (!kIsWeb) {
      _initDeepLinks();
    }
  }

  void _initDeepLinks() async {
    final appLinks = AppLinks();

    // 앱이 종료된 상태에서 딥링크로 실행된 경우
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print('Initial deep link error: $e');
    }

    // 앱이 실행 중인 상태에서 딥링크가 들어온 경우
    _linkSubscription = appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (e) => print('Deep link stream error: $e'),
    );
  }

  void _handleDeepLink(Uri uri) {
    print('Deep link received: $uri');
    // paperef://app/reset-password?token=xxx
    // uri.host = "app", uri.path = "/reset-password"
    if (uri.path == '/reset-password' || uri.path == 'reset-password') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(token: token),
            ),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(_apiService, _storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => RefProvider(_apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => GroupProvider(_apiService),
        ),
      ],
      child: MaterialApp(
        title: 'Paperef',
        theme: AppTheme.lightTheme,
        navigatorKey: navigatorKey,
        home: const AuthenticationWrapper(),
        debugShowCheckedModeBanner: false,
        onGenerateRoute: (settings) {
          // 웹 URL 라우팅 처리 (웹 전용)
          if (settings.name != null && settings.name!.isNotEmpty) {
            final uri = Uri.parse(settings.name!);
            final path = uri.path;

            if (path == '/reset-password' || path == 'reset-password') {
              final token = uri.queryParameters['token'];
              if (token != null && token.isNotEmpty) {
                return MaterialPageRoute(
                  builder: (_) => ResetPasswordScreen(token: token),
                  settings: settings,
                );
              }
            }

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
        if (!authProvider.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
