import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/theme/app_theme.dart';
import 'features/authentication/providers/auth_provider.dart';
import 'features/papers/providers/paper_provider.dart';
import 'shared/services/api_service.dart';
import 'shared/services/storage_service.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/papers/presentation/papers_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = FlutterSecureStorage();
    final storageService = StorageService(storage);
    final apiService = ApiService(storageService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiService, storageService),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PaperProvider>(
          create: (_) => PaperProvider(apiService),
          update: (_, auth, previous) => previous ?? PaperProvider(apiService),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Paperef',
            theme: AppTheme.lightTheme,
            home: auth.isAuthenticated 
                ? const PapersListScreen() 
                : const LoginScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}