import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/job_provider.dart';
import 'providers/tracker_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InternPulseApp());
}

class InternPulseApp extends StatelessWidget {
  const InternPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..init()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => TrackerProvider()),
      ],
      child: MaterialApp(
        title: 'InternPulse',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

/// Menentukan layar awal: splash -> login atau halaman utama.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.initializing) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return auth.isAuthenticated ? const MainNavigation() : const LoginScreen();
  }
}
